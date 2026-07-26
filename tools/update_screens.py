#!/usr/bin/env python3
"""README 用スクリーンショット3枚を撮り直す (ROM 更新のたびに実行)。

  1. make で game.nes をビルドし、ld65 --dbgfile で ZP シンボルを取得
  2. tools/capture_screens.js (WASM コアのヘッドレス実行) で3画面を撮影
  3. 2倍拡大 + 下部に タイムスタンプ / game.nes を最後に更新したコミットの hash を焼き込み
     → docs/title_screen.png, docs/screenshot.png, docs/boss_fight.png

ROM を含むコミットの「後」に実行し、スクショは追いコミットする
(焼き込む hash がその ROM のコミットを指すように)。
"""
import re, subprocess, sys, tempfile, datetime, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)

SYMS = ['game_state', 'menu_sel', 'current_stage', 'world_x_lo', 'world_x_hi',
        'player_y', 'on_ground', 'vel_y_lo', 'vel_y_hi', 'star_timer', 'boss_state']

def sh(cmd):
    return subprocess.run(cmd, shell=True, check=True, capture_output=True, text=True).stdout.strip()

# 1. ビルド + シンボル
sh('make')
sh('ld65 -C nes.cfg -o game.nes build/main.o --dbgfile build/dbg.txt')
dbg = open('build/dbg.txt').read()
addrs = {}
for name in SYMS:
    m = re.search(rf'sym\t.*name="{name}".*val=0x([0-9A-Fa-f]+)', dbg)
    if not m:
        sys.exit(f'symbol not found: {name}')
    addrs[name] = int(m.group(1), 16)

# 2. 撮影
tmp = tempfile.mkdtemp()
import json
subprocess.run(['node', 'tools/capture_screens.js', json.dumps(addrs), tmp], check=True)

# 3. 合成 (2倍 + フッター)
try:
    githash = sh('git log -1 --format=%h -- game.nes') or sh('git rev-parse --short HEAD')
except subprocess.CalledProcessError:
    githash = 'unknown'
stamp = datetime.datetime.now().strftime('%Y-%m-%d %H:%M JST')
label = f'{stamp}   git {githash}'
try:
    font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 14)
except OSError:
    font = ImageFont.load_default()

BAR = 24
for src, dst in [('title', 'docs/title_screen.png'),
                 ('jump', 'docs/screenshot.png'),
                 ('boss', 'docs/boss_fight.png')]:
    im = Image.frombytes('RGBA', (256, 240), open(f'{tmp}/{src}.rgba', 'rb').read()).convert('RGB')
    im = im.resize((512, 480), Image.NEAREST)
    out = Image.new('RGB', (512, 480 + BAR), (17, 17, 17))
    out.paste(im, (0, 0))
    dr = ImageDraw.Draw(out)
    dr.text((8, 480 + 4), label, fill=(160, 160, 160), font=font)
    dr.text((512 - 8 - dr.textlength('CALUDE KODO', font=font), 480 + 4),
            'CALUDE KODO', fill=(110, 60, 60), font=font)
    out.save(dst)
    print('wrote', dst)
print('footer:', label)
