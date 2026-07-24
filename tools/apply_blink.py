#!/usr/bin/env python3
# 目パチエディタ (docs/tools/blinkedit) の JSON をアセットへ反映する
#   python3 tools/apply_blink.py blink.json
# タイル: タイトル CHR PT0 の空きスロット (マージで確保済みの16枚) を書き換え
# テーブル: assets/title_screen.s の TITLE_EYE_* を再生成
import re, sys, json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/'
FREED = [206,100,232,224,251,172,179,181,21,203,242,204,177,215,194,229,254]  # 254=旧ソリッド (sprite0 はカーソル流用)
CHARV = {'.':0,'S':1,'B':2,'W':3,'K':3}   # W/K はどちらも色3 (パレットで白/黒に分かれる)

data = json.load(open(sys.argv[1]))
RX,RY = data['region']['x'], data['region']['y']
RW,RH = data['region']['w'], data['region']['h']
layers = {k:[list(r) for r in v] for k,v in data['layers'].items()}

# ---- 前処理1: 2px 以下の孤立ドット (誤クリック) を除去 ----
def cleanup(g):
    seen=[[False]*RW for _ in range(RH)]
    removed=0
    for y in range(RH):
        for x in range(RW):
            if g[y][x]!='.' and not seen[y][x]:
                comp=[(x,y)]; seen[y][x]=True; k=0
                while k<len(comp):
                    cx,cy=comp[k]; k+=1
                    for dx in (-1,0,1):
                        for dy in (-1,0,1):
                            nx,ny=cx+dx,cy+dy
                            if 0<=nx<RW and 0<=ny<RH and g[ny][nx]!='.' and not seen[ny][nx]:
                                seen[ny][nx]=True; comp.append((nx,ny))
                if len(comp)<=2:
                    for (cx,cy) in comp: g[cy][cx]='.'
                    removed+=len(comp)
    return removed
# ---- 前処理2: 3状態で共通のピクセルは BG タイルへ焼き込み (スプライト不要化) ----
# 併せて「元のBGと同色」のピクセルもスプライトから除外する
import shutil
PRIS = ROOT+'assets/title_chr.pristine'
if not os.path.exists(PRIS):
    shutil.copy(ROOT+'assets/title_chr.s', PRIS)      # 初回に原本を保存 (焼き込みの累積を防ぐ)
def parse_bytes(text):
    out=[]
    for line in text.splitlines():
        line=line.strip()
        m=re.match(r'\.res (\d+), \$00', line)
        if m: out += [0]*int(m.group(1)); continue
        if line.startswith('.byte'):
            out += [int(v,16) for v in re.findall(r'\$([0-9A-Fa-f]{2})', line)]
    return out
chrb=parse_bytes(open(PRIS).read())
scr0=open(ROOT+'assets/title_screen.s').read()
ntattr=parse_bytes(scr0[scr0.index('title_nt:'):])
nt=ntattr[:960]; attr=ntattr[960:1024]
palb=parse_bytes(scr0[scr0.index('title_img_palette:'):scr0.index('title_nt:')])[:16]
from collections import Counter as _C
usage=_C(nt[:17*32])
def blockpal(X,Y):
    a=attr[(Y//32)*8+(X//32)]
    q=(1 if (X//16)%2 else 0)+(2 if (Y//16)%2 else 0)
    return (a>>(q*2))&3
def bg_px(X,Y):
    tid=nt[(Y//8)*32+X//8]
    return tid, ((chrb[tid*16+Y%8]>>(7-X%8))&1)|(((chrb[tid*16+8+Y%8]>>(7-X%8))&1)<<1)
CH2NES={'S':0x37,'B':0x17,'K':-1,'W':0x30}
baked=0; bgeq=0
for y in range(RH):
    for x in range(RW):
        X,Y=RX+x,RY+y
        vals={k:layers[k][y][x] for k in ('closed','half','white')}
        c=vals['closed']
        tid,bv=bg_px(X,Y)
        bn = (palb[blockpal(X,Y)*4+bv]&63) if bv else -1
        if c!='.' and all(v==c for v in vals.values()):
            # 全状態共通 → BG へ焼き込み (単独使用タイル & パレットに色がある場合のみ)
            bp=blockpal(X,Y)
            tgt=None
            if c=='K': tgt=0
            else:
                cols=[palb[bp*4+i]&63 for i in (1,2,3)]
                if CH2NES[c] in cols: tgt=cols.index(CH2NES[c])+1
            if tgt is not None and usage[tid]==1:
                b=7-X%8; r=Y%8
                chrb[tid*16+r]   = (chrb[tid*16+r]   & ~(1<<b)) | ((tgt&1)<<b)
                chrb[tid*16+8+r] = (chrb[tid*16+8+r] & ~(1<<b)) | (((tgt>>1)&1)<<b)
                for k in layers: layers[k][y][x]='.'
                baked+=1
                continue
        for k in layers:                              # BG と同色ならスプライト不要
            v=layers[k][y][x]
            if v!='.' and CH2NES[v]==bn:
                layers[k][y][x]='.'; bgeq+=1
print(f'BG焼き込み {baked}px / BG同色除外 {bgeq}px')
for k in layers:
    n=cleanup(layers[k])
    if n: print(f'{k}: 孤立ドット {n}px を除去')

# ---- パック: 最初の未カバー画素に対し、最も多く覆えるボックス位置を選ぶ貪欲法 ----
SPR_MAX = 16
# 3レイヤー合併からボックスグリッドを決定 (レイヤー間で位置が揃い、共通ドットのタイルが共有される)
union=[[any(layers[k][y][x]!='.' for k in layers) for x in range(RW)] for y in range(RH)]
rows=[y for y in range(RH) if any(union[y])]
bands=[]
_i=0
while _i<len(rows):
    y0=rows[_i]; bands.append(y0); _i+=1
    while _i<len(rows) and rows[_i]<y0+8: _i+=1
GRID=[]
for y0 in bands:
    x=0
    while x<RW:
        if any(union[yy][x] for yy in range(y0,min(RH,y0+8))):
            GRID.append((x,y0)); x+=8
        else:
            x+=1
def pack(name, g):
    "共通グリッドのうち、このレイヤーに中身のあるボックスだけ使う"
    out=[]
    for (bx,by) in GRID:
        if any(g[yy][xx]!='.' for yy in range(by,min(RH,by+8)) for xx in range(bx,min(RW,bx+8))):
            out.append((bx,by))
    return out
tiles=[]; tables={}
for name in ('closed','half','white'):
    g=layers[name]
    sprs=[]
    for (bx,by) in pack(name, g):
        cells=[]
        for yy in range(8):
            for xx in range(8):
                c=g[by+yy][bx+xx] if by+yy<RH and bx+xx<RW else '.'
                cells.append(c)
        chs=set(cells)
        variants=[]
        if 'W' in chs and 'K' in chs:
            # 白黒同居: 白側 (K を透明に) と黒側 (K のみ) の2枚を重ねる
            variants.append(([CHARV[c] if c!='K' else 0 for c in cells], 1))
            variants.append(([3 if c=='K' else 0 for c in cells], 2))
        else:
            pal = 2 if 'K' in chs else 1          # 黒入りタイルはスプライトパレット2
            variants.append(([CHARV[c] for c in cells], pal))
        for tvals,pal in variants:
            key=(tuple(tvals), pal)
            if key not in tiles: tiles.append(key)
            sprs.append((RY+by-1, tiles.index(key), RX+bx, pal))   # OAM y = top-1
    assert len(sprs)<=SPR_MAX, f'{name}: スプライト {len(sprs)} 枚 ({SPR_MAX}まで)'
    for y in range(240):                          # 走査線8枚制限 (分割スプライト込み)
        n=sum(1 for (sy,_,_,_) in sprs if sy+1<=y<sy+9)
        assert n<=8, f'{name}: y={y} でスプライトが横に {n} 枚 (走査線8枚制限)'
    tables[name]=sprs
if len(tiles) > len(FREED):
    # 半目レイヤーを捨て、「閉じ目をまぶたラインでクリップ」した自動半目に切替
    print(f'タイル {len(tiles)} 枚 > {len(FREED)} — 半目を閉じ目のクリップで自動生成します')
    c_ys=[y for y in range(RH) if any(c!='.' for c in layers['closed'][y])]
    lid = c_ys[0] + int((c_ys[-1]-c_ys[0])*0.62) if c_ys else 0
    layers['half'] = [[layers['closed'][y][x] if y<=lid else '.' for x in range(RW)] for y in range(RH)]
    tiles=[]; tables={}
    for name in ('closed','white','half'):
        g=layers[name]
        sprs=[]
        for (bx,by) in pack(name, g):
            cells=[]
            for yy in range(8):
                for xx in range(8):
                    c=g[by+yy][bx+xx] if by+yy<RH and bx+xx<RW else '.'
                    cells.append(c)
            chs=set(cells)
            variants=[]
            if 'W' in chs and 'K' in chs:
                variants.append(([CHARV[c] if c!='K' else 0 for c in cells], 1))
                variants.append(([3 if c=='K' else 0 for c in cells], 2))
            else:
                variants.append(([CHARV[c] for c in cells], 2 if 'K' in chs else 1))
            for tvals,pal in variants:
                key=(tuple(tvals), pal)
                if key not in tiles: tiles.append(key)
                sprs.append((RY+by-1, tiles.index(key), RX+bx, pal))
        assert len(sprs)<=SPR_MAX, f'{name}: スプライト {len(sprs)} 枚 ({SPR_MAX}まで)'
        tables[name]=sprs
assert len(tiles)<=len(FREED), f'タイル {len(tiles)} 枚 (16まで)'
# ウィンク用: 閉じ目は手前の目 (x>=193) を先頭に並べる
tables['closed'].sort(key=lambda s: 0 if s[2]>=193 else 1)
near_n = sum(1 for s in tables['closed'] if s[2]>=193)
print('tiles:',len(tiles),'sprs:',{k:len(v) for k,v in tables.items()},'near:',near_n)

# ---- title_chr.s: PT0 スロット書き換え ----
assert len(chrb)==8192   # (前処理で pristine から読み込み+焼き込み済み)
for k,(t,_pal) in enumerate(tiles):
    tid=FREED[k]
    p0=[];p1=[]
    for y in range(8):
        b0=b1=0
        for x in range(8):
            v=t[y*8+x]; b0=(b0<<1)|(v&1); b1=(b1<<1)|(v>>1)
        p0.append(b0);p1.append(b1)
    chrb[tid*16:(tid+1)*16]=p0+p1
for k in range(len(tiles),len(FREED)):       # 未使用スロットは空に
    tid=FREED[k]; chrb[tid*16:(tid+1)*16]=[0]*16
lines=['; タイトル用 CHR バンク1 (blink エディタ反映済み — tools/apply_blink.py)']
for o in range(0,8192,16):
    if o==4096: lines.append('; ---- PT1 (下半分) ----')
    lines.append('    .byte '+','.join(f'${v:02X}' for v in chrb[o:o+16]))
open(ROOT+'assets/title_chr.s','w').write('\n'.join(lines)+'\n')

# ---- title_screen.s: TITLE_EYE ブロックを差し替え ----
scr=open(ROOT+'assets/title_screen.s').read()
def tbl(sp):
    return ','.join(f'${(y&255):02X},${FREED[t]:02X},${p:02X},${x:02X}' for (y,t,x,p) in sp)
block=(f'TITLE_EYE_N   = {len(tables["closed"])}\n'
       f'TITLE_EYE_HN  = {len(tables["half"])}\n'
       f'TITLE_EYE_ON  = {len(tables["white"])}\n'
       f'TITLE_EYE_NEAR = {near_n}\n'
       '.segment "RODATA"\n'
       'title_eye_spr:       ; 閉じ目 (blink エディタ)\n'
       '    .byte '+tbl(tables['closed'])+'\n'
       'title_eye_half:      ; 半目\n'
       '    .byte '+tbl(tables['half'])+'\n'
       'title_eye_open:      ; 白目 (開き目で常時表示)\n'
       '    .byte '+tbl(tables['white'])+'\n'
       'title_eye_pal:       ; パレット1=肌/茶/白, パレット2=肌/茶/黒 ($3F15-$3F1B)\n'
       '    .byte $37,$17,$30,$0F,$37,$17,$0F\n')
i=scr.index('TITLE_EYE_N')
j=scr.index('title_eye_pal:')
j=scr.index('\n', scr.index('.byte', j))+1
scr = scr[:i] + block + scr[j:]
open(ROOT+'assets/title_screen.s','w').write(scr)
print('applied. make で再ビルドしてください')
