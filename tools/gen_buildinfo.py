#!/usr/bin/env python3
# ビルド情報 (Git リビジョン + 日付) を assets/buildinfo.s へ生成する
# タイトル画面のミニフォント ("0123456789ABCDEF-" + 空白) のインデックス列を出力
import subprocess, datetime, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
try:
    rev = subprocess.check_output(['git','rev-parse','--short','HEAD'], cwd=root).decode().strip().upper()
except Exception:
    rev = '0000000'
date = datetime.datetime.now().strftime('%y-%m-%d')
text = f'{rev} {date}'
CHARS = '0123456789ABCDEF-'
idx = []
for c in text:
    if c == ' ': idx.append(17)          # 17 = 黒ベタ (空白)
    elif c in CHARS: idx.append(CHARS.index(c))
    else: idx.append(17)
body = ('; 自動生成: ビルド情報 (tools/gen_buildinfo.py — 編集しないこと)\n'
        '.segment "RODATA"\n'
        f'; "{text}"\n'
        'build_info_txt:\n'
        '    .byte ' + ','.join(f'${v:02X}' for v in idx) + ',$FF\n')
path = os.path.join(root,'assets','buildinfo.s')
old = open(path).read() if os.path.exists(path) else ''
if old != body:
    open(path,'w').write(body)
    print(f'buildinfo: "{text}"')
