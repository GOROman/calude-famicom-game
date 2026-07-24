#!/usr/bin/env python3
# 目パチエディタ (docs/tools/blinkedit) の JSON をアセットへ反映する
#   python3 tools/apply_blink.py blink.json
# タイル: タイトル CHR PT0 の空きスロット (マージで確保済みの16枚) を書き換え
# テーブル: assets/title_screen.s の TITLE_EYE_* を再生成
import re, sys, json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '/'
FREED = [206,100,232,224,251,172,179,181,21,203,242,204,177,215,194,229]
CHARV = {'.':0,'S':1,'B':2,'W':3}

data = json.load(open(sys.argv[1]))
RX,RY = data['region']['x'], data['region']['y']
RW,RH = data['region']['w'], data['region']['h']
layers = {k:[list(r) for r in v] for k,v in data['layers'].items()}

# ---- パック (エディタと同じ貪欲法) ----
tiles=[]; tables={}
for name in ('closed','half','white'):
    g=layers[name]
    covered=[[False]*RW for _ in range(RH)]
    sprs=[]
    for y in range(RH):
        for x in range(RW):
            if g[y][x]!='.' and not covered[y][x]:
                t=[]
                for yy in range(8):
                    for xx in range(8):
                        c=g[y+yy][x+xx] if y+yy<RH and x+xx<RW else '.'
                        t.append(CHARV[c])
                        if y+yy<RH and x+xx<RW: covered[y+yy][x+xx]=True
                t=tuple(t)
                if t not in tiles: tiles.append(t)
                sprs.append((RY+y-1, tiles.index(t), RX+x))   # OAM y = top-1
    assert len(sprs)<=8, f'{name}: スプライト {len(sprs)} 枚 (8まで)'
    tables[name]=sprs
assert len(tiles)<=len(FREED), f'タイル {len(tiles)} 枚 (16まで)'
# ウィンク用: 閉じ目は手前の目 (x>=193) を先頭に並べる
tables['closed'].sort(key=lambda s: 0 if s[2]>=193 else 1)
near_n = sum(1 for s in tables['closed'] if s[2]>=193)
print('tiles:',len(tiles),'sprs:',{k:len(v) for k,v in tables.items()},'near:',near_n)

# ---- title_chr.s: PT0 スロット書き換え ----
def parse_bytes(text):
    out=[]
    for line in text.splitlines():
        line=line.strip()
        m=re.match(r'\.res (\d+), \$00', line)
        if m: out += [0]*int(m.group(1)); continue
        if line.startswith('.byte'):
            out += [int(v,16) for v in re.findall(r'\$([0-9A-Fa-f]{2})', line)]
    return out
chrb=parse_bytes(open(ROOT+'assets/title_chr.s').read())
assert len(chrb)==8192
for k,t in enumerate(tiles):
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
    return ','.join(f'${(y&255):02X},${FREED[t]:02X},$01,${x:02X}' for (y,t,x) in sp)
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
       'title_eye_pal:       ; 肌/茶/白 (スプライトパレット1)\n'
       '    .byte $37,$17,$30\n')
i=scr.index('TITLE_EYE_N')
j=scr.index('title_eye_pal:')
j=scr.index('\n', scr.index('.byte', j))+1
scr = scr[:i] + block + scr[j:]
open(ROOT+'assets/title_screen.s','w').write(scr)
print('applied. make で再ビルドしてください')
