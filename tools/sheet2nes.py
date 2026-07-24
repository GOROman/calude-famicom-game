#!/usr/bin/env python3
"""スプライトシート画像 → NES 16x32 ポーズ (SP0: 透明 / $17茶 / $25ピンク / $36肌)"""
import numpy as np
from PIL import Image

SRC = '/Users/goroman/.claude/image-cache/babd7aaf-72cd-4770-a01d-8b47b5baf69e/1.png'
OUT = '/private/tmp/claude-501/-Users-goroman-work-github-com-GOROman-claude-famicom-game/babd7aaf-72cd-4770-a01d-8b47b5baf69e/scratchpad'

BROWN = (120, 60, 0)      # $17
PINK  = (236, 88, 180)    # $25
SKIN  = (236, 180, 176)   # $36
SHOW  = {0: (34, 34, 34), 1: BROWN, 2: PINK, 3: SKIN}

img = np.asarray(Image.open(SRC).convert('RGB')).astype(int)
H, W, _ = img.shape
r, g, b = img[..., 0], img[..., 1], img[..., 2]
mx = img.max(2); mn = img.min(2)
# 前景 = 黒背景でも白文字でもない画素 (輪郭の暗部も拾うため閾値低め)
fg = (mx > 30) & ~((mn > 170) & (mx - mn < 45))
# 有彩色 (キャラ判定用: 白ソックスだけの断片を弾く)
colored = (mx - mn > 50) & (mx > 60)

def segments(mask_cols, gap=25, minw=55):
    runs, start = [], None
    for x in range(len(mask_cols) + 1):
        v = mask_cols[x] if x < len(mask_cols) else 0
        if v and start is None:
            start = x
        elif not v and start is not None:
            if runs and start - runs[-1][1] <= gap:
                runs[-1] = (runs[-1][0], x)          # 近接ランは結合
            else:
                runs.append((start, x))
            start = None
    return [(a, b_) for a, b_ in runs if b_ - a >= minw]

BANDS = [(40, 345), (360, 690), (700, 1086)]
poses = []   # (band, x0, x1, y0, y1)
for bi, (by0, by1) in enumerate(BANDS):
    band_c = colored[by0:by1]
    band_col = band_c.any(0).astype(int)
    for x0, x1 in segments(band_col):
        ys = np.where(band_c[:, x0:x1].any(1))[0]
        y0, y1 = ys.min() + by0, ys.max() + by0
        ncol = colored[y0:y1, x0:x1].sum()
        if y1 - y0 < 90 or ncol < 4000:   # 矢アイコン/ラベル除外
            continue
        # 輪郭 (暗色) を含むよう少し広げる
        y0 = max(0, y0-5); y1 = min(H-1, y1+5); x0 = max(0, x0-5); x1 = min(W-1, x1+5)
        poses.append((bi, x0, x1, y0, y1))

for p in poses:
    bi, x0, x1, y0, y1 = p
    print(f'band{bi}: x{x0}-{x1} y{y0}-{y1}  w{x1-x0} h{y1-y0}')

# ---- 画素分類: 0=透明 1=茶($17) 2=ピンク($25) 3=肌($36) ----
def classify(px):
    R, G, B = int(px[0]), int(px[1]), int(px[2])
    hi, lo = max(R,G,B), min(R,G,B)
    if hi <= 30:
        return 0                       # 背景黒
    if B > R + 20 and B > 80:
        return 1                       # 青スカーフ/目 → 茶 (ゲーム内はスカーフ=茶)
    if lo > 170 and hi - lo < 45:
        return 3                       # 白ソックス/ハイライト → 肌
    if R > 190 and G > 140 and B > 110:
        return 3                       # 肌
    if R > 140 and G < 130 and B > 60:
        return 2                       # ピンク (服/リボン/レース)
    return 1                           # 髪/ブーツ/輪郭 → 茶

def rasterize(x0, x1, y0, y1, tw, th, crop_to=None, xoff=0.08):
    """bbox を tw x th に多数決縮小。crop_to=(w) なら等比で高さ th に合わせ幅中央クロップ"""
    if crop_to:
        # 高さを th に等比縮小 → 幅を crop_to に中央クロップ (右寄せ気味: キャラは右向き)
        scale = (y1 - y0) / th
        want_w = int(round(crop_to * scale))
        cx = (x0 + x1) // 2 + int(xoff * (x1 - x0))   # 少し右 (体側) へ
        x0c, x1c = cx - want_w // 2, cx + want_w // 2
    else:
        x0c, x1c = x0, x1
    grid = np.zeros((th, tw), dtype=int)
    for ty in range(th):
        sy0 = y0 + (y1 - y0) * ty // th
        sy1 = max(sy0 + 1, y0 + (y1 - y0) * (ty + 1) // th)
        for tx in range(tw):
            sx0 = x0c + (x1c - x0c) * tx // tw
            sx1 = max(sx0 + 1, x0c + (x1c - x0c) * (tx + 1) // tw)
            cnt = [0, 0, 0, 0]
            for sy in range(sy0, sy1):
                for sx in range(sx0, sx1):
                    if 0 <= sx < W and 0 <= sy < H:
                        cnt[classify(img[sy, sx])] += 1
            total = sum(cnt)
            solid = total - cnt[0]
            if total == 0 or solid < total * 0.32:
                grid[ty, tx] = 0
            else:
                w = [0, cnt[1], cnt[2] * 1.15, cnt[3] * 1.15]  # 中身の色をやや優遇
                grid[ty, tx] = max(range(1, 4), key=lambda i: w[i])
    # デスペックル: 孤立ピクセルは4近傍の多数派に合わせる
    for _ in range(2):
        out = grid.copy()
        for ty in range(th):
            for tx in range(tw):
                nb = []
                if ty > 0: nb.append(grid[ty-1, tx])
                if ty < th-1: nb.append(grid[ty+1, tx])
                if tx > 0: nb.append(grid[ty, tx-1])
                if tx < tw-1: nb.append(grid[ty, tx+1])
                if grid[ty, tx] not in nb:
                    out[ty, tx] = max(set(nb), key=nb.count)
        grid = out
    return grid

def frame32(grid):
    """th x 16 のグリッドを 16x32 フレームに下寄せ配置"""
    f = np.zeros((32, 16), dtype=int)
    th = grid.shape[0]
    f[32 - th:32, :] = grid
    return f

# ---- 全ポーズ x 2バリアント でプレビュー ----
NAMES = ['run1','run2','run3','run4','jump1','jump2','jump3','bow1','bow2','bow3','bow4']
frames = {}
for (bi, x0, x1, y0, y1), name in zip(poses, NAMES):
    xoff = 0.16 if name in ('bow2', 'bow3') else 0.08
    a = frame32(rasterize(x0, x1, y0, y1, 16, 24))                          # 押し込み
    bshape = frame32(rasterize(x0, x1, y0, y1, 16, 24, crop_to=16, xoff=xoff))  # 等比+クロップ
    frames[name] = (a, bshape)

S = 8
sheet = Image.new('RGB', (len(NAMES) * (16 * S + 8) + 8, 2 * (32 * S + 8) + 24), (10, 10, 10))
from PIL import ImageDraw
dr = ImageDraw.Draw(sheet)
for col, name in enumerate(NAMES):
    for row in range(2):
        f = frames[name][row]
        ox, oy = 8 + col * (16 * S + 8), 12 + row * (32 * S + 8)
        for y in range(32):
            for x in range(16):
                c = SHOW[f[y, x]]
                dr.rectangle([ox + x * S, oy + y * S, ox + x * S + S - 1, oy + y * S + S - 1], fill=c)
sheet.save(f'{OUT}/preview.png')
np.save(f'{OUT}/frames.npy', np.array([[frames[n][v] for v in range(2)] for n in NAMES]))
print('preview saved:', f'{OUT}/preview.png')

# ---- 目を1ドット入れる (顔=肌ブロブの右寄り中央) ----
def add_eye(f):
    ys, xs = np.where(f[4:16] == 3)   # フレーム上半分の肌
    if len(ys) < 6:
        return f
    ys = ys + 4
    top, bot = ys.min(), ys.max()
    band = (ys <= top + (bot - top) // 2 + 1)   # 顔の上半分帯
    if not band.any():
        return f
    ey = int(np.median(ys[band]))
    ex = xs[band].max() - 1                     # 右向き: 右端の1つ内側
    if ex >= 1 and f[ey, ex] == 3:
        f[ey, ex] = 1
    return f

FINAL = {}
for name in NAMES:
    FINAL[name] = add_eye(frames[name][1].copy())

# 最終プレビュー
S = 10
fin = Image.new('RGB', (len(NAMES) * (16 * S + 8) + 8, 32 * S + 16), (10, 10, 10))
dr = ImageDraw.Draw(fin)
for col, name in enumerate(NAMES):
    f = FINAL[name]
    ox, oy = 8 + col * (16 * S + 8), 8
    for y in range(32):
        for x in range(16):
            dr.rectangle([ox+x*S, oy+y*S, ox+x*S+S-1, oy+y*S+S-1], fill=SHOW[f[y, x]])
fin.save(f'{OUT}/final.png')

# ---- sprites.s へパッチ ----
ASSIGN = {0x00:'bow1', 0x02:'run1', 0x04:'run2', 0x06:'run3', 0x08:'run4',
          0x0A:'jump1', 0x0C:'jump2', 0x0E:'jump3',
          0x40:'bow2', 0x42:'bow3', 0x44:'bow4'}
def tile_bytes(f, row, col):
    p0, p1 = [], []
    for y in range(8):
        b0 = b1 = 0
        for x in range(8):
            v = int(f[row*8 + y, col*8 + x])
            b0 = (b0 << 1) | (v & 1)
            b1 = (b1 << 1) | (v >> 1)
        p0.append(b0); p1.append(b1)
    return p0 + p1

import re
path = '/Users/goroman/work/github.com/GOROman/claude-famicom-game/assets/sprites.s'
lines = open(path).read().splitlines()
# タイル番号 → (コメント行番号) を作る: "; xxx ($NN)" の直後2行が .byte
tilepos = {}
for i, l in enumerate(lines):
    m = re.search(r'\(\$([0-9A-Fa-f]{2})\)', l)
    if m and l.strip().startswith(';'):
        tilepos[int(m.group(1), 16)] = i
hexs = lambda vs: ','.join(f'${v:02X}' for v in vs)
npatch = 0
for base, name in ASSIGN.items():
    f = FINAL[name]
    for row in range(4):
        for col in range(2):
            t = base + row*16 + col
            i = tilepos[t]
            assert lines[i+1].strip().startswith('.byte') and lines[i+2].strip().startswith('.byte'), t
            tb = tile_bytes(f, row, col)
            lines[i] = f'; {name} r{row}c{col} (${t:02X}) — シート取込'
            lines[i+1] = '    .byte ' + hexs(tb[:8])
            lines[i+2] = '    .byte ' + hexs(tb[8:])
            npatch += 1
open(path, 'w').write('\n'.join(lines) + '\n')
print('patched tiles:', npatch)
