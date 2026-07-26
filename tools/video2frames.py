#!/usr/bin/env python3
"""動画 → 透過PNG連番 (docs/tools/animplay/frames/ 用)

  python3 tools/video2frames.py input.mp4 出力ディレクトリ

処理:
  1. ffmpeg で全フレームを PNG 展開
  2. 市松模様 (透明の意味) をキーイング:
     - 明るい無彩色 (min>198, max-min<28) を市松候補に
     - 画面外周に 4連結でつながる候補成分だけを背景と確定
       (キャラの白い衣装やファーは輪郭線で囲まれ外周と切れているので残る)
     - 条件付き膨張 2回で圧縮ハローを除去 (暗い輪郭線は食わない)
  3. 128色量子化 PNG で保存 (約45KB/枚)
市松がないフレーム (四隅が暗い) は不透過のまま保存する。
"""
import sys, os, glob, subprocess, tempfile
import numpy as np
from PIL import Image
from scipy import ndimage as ni

src, outdir = sys.argv[1], sys.argv[2]
os.makedirs(outdir, exist_ok=True)
tmp = tempfile.mkdtemp()
subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', src, f'{tmp}/f%04d.png'], check=True)

four = ni.generate_binary_structure(2, 1)
files = sorted(glob.glob(f'{tmp}/f*.png'))
for i, fn in enumerate(files):
    f = np.asarray(Image.open(fn).convert('RGB')).astype(int)
    H, W, _ = f.shape
    rgba = np.dstack([f.astype(np.uint8), np.full((H, W), 255, np.uint8)])
    corners = [f[3:15, 3:15].mean(), f[3:15, -15:-3].mean(),
               f[-15:-3, 3:15].mean(), f[-15:-3, -15:-3].mean()]
    if min(corners) > 170:
        mx = f.max(axis=2); mn = f.min(axis=2)
        cand = (mn > 198) & ((mx - mn) < 28)
        lab, n = ni.label(cand, structure=four)
        border = set(lab[0, :]).union(lab[-1, :], lab[:, 0], lab[:, -1])
        border.discard(0)
        bg = np.isin(lab, list(border))
        for _ in range(2):
            bg = ni.binary_dilation(bg, structure=four) & (mn > 160)
        rgba[..., 3] = np.where(bg, 0, 255).astype(np.uint8)
    im = Image.fromarray(rgba).quantize(colors=128, method=Image.FASTOCTREE)
    im.save(f'{outdir}/f{i:03d}.png', optimize=True)
print(f'{len(files)} frames -> {outdir}')
