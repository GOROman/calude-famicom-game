; CHR-ROM パターンデータ (残り領域はリンカが $00 で埋める)
; 主人公: 狩人 Calude (16x16 = 8x8 タイル4枚)。フード+弓持ち、右向き
; ドット絵は scratchpad の hunter.py で生成

; tile $00: blank
    .res 16, $00
; tile $01: hunter top-left
    .byte $0F,$0F,$7F,$FF,$FF,$7F,$7F,$31
    .byte $00,$00,$00,$00,$03,$03,$03,$01
; tile $02: hunter top-right
    .byte $F0,$F0,$F4,$F2,$F2,$F2,$F2,$E2
    .byte $00,$00,$00,$70,$D0,$F0,$F0,$E0
; tile $03: hunter bottom-left
    .byte $30,$00,$00,$00,$03,$03,$07,$07
    .byte $07,$0F,$0F,$1F,$03,$03,$00,$00
; tile $04: hunter bottom-right
    .byte $1A,$02,$02,$02,$62,$64,$70,$70
    .byte $F8,$F0,$F0,$F8,$60,$60,$00,$00

; ---- BG タイル (悪魔城伝説風: cv_tiles.py で生成) ----
; tile $05: grass top (地面の上端: 明緑の草 + 茶の土)
    .byte $FF,$EF,$00,$00,$42,$00,$00,$48
    .byte $FF,$EF,$00,$EF,$AD,$00,$DD,$95
; tile $06: dirt (土: 茶ベースに暗色の粒)
    .byte $00,$00,$44,$00,$00,$91,$00,$00
    .byte $00,$EF,$AB,$00,$BD,$2C,$00,$EF

; tile $07: block (レンガブロック: 茶ベース+暗色の目地)
    .byte $FE,$82,$82,$82,$82,$FE,$00,$00
    .byte $FE,$FC,$FC,$FC,$FC,$80,$00,$DE

; tile $08: arrow (矢: 右向き。左向きは水平反転で描画)
; r3 に鏃の上、r4 にシャフト(肌色)+鏃(黒)、r5 に鏃の下
    .byte $00,$00,$00,$04,$FF,$04,$00,$00
    .byte $00,$00,$00,$00,$FC,$00,$00,$00

; ---- アニメポーズ (scratchpad の poses.py で生成) ----
; tile $09: walk2 bottom-left (足を開いた歩きポーズ)
    .byte $30,$00,$00,$00,$0C,$0C,$1C,$1C
    .byte $07,$0F,$0F,$1F,$0C,$0C,$00,$00
; tile $0A: walk2 bottom-right
    .byte $1A,$02,$02,$02,$32,$34,$1C,$1C
    .byte $F8,$F0,$F0,$F8,$30,$30,$00,$00
; tile $0B: jump bottom-left (足をたたんだ空中ポーズ)
    .byte $30,$00,$00,$00,$03,$07,$00,$00
    .byte $07,$0F,$0F,$1F,$03,$00,$00,$00
; tile $0C: jump bottom-right
    .byte $1A,$02,$02,$02,$62,$74,$00,$00
    .byte $F8,$F0,$F0,$F8,$60,$00,$00,$00
; tile $0D: attack top-left (弓を引くポーズ)
    .byte $0F,$0F,$7F,$FF,$FF,$7F,$7F,$31
    .byte $00,$00,$00,$00,$03,$03,$03,$01
; tile $0E: attack top-right
    .byte $F0,$F0,$F2,$F1,$F5,$F5,$FD,$E5
    .byte $00,$00,$00,$70,$D4,$F4,$FC,$E4

; tile $0F: 未使用 (行頭合わせのパディング)
    .res 16, $00
; tile $10-$4F: 隠しメッセージ
.include "easteregg.s"

; ---- 16x16 メタタイル (scratchpad の brick16.py で生成) ----
; SMB 風の 16x16 ブロック (輪郭+左上ハイライト+レンガ目地)
; tile $50: block16 TL
    .byte $00,$7F,$40,$40,$40,$40,$40,$40
    .byte $00,$7F,$7E,$7E,$7E,$7E,$7E,$60
; tile $51: block16 TR
    .byte $00,$FE,$02,$02,$02,$02,$02,$02
    .byte $00,$FE,$FC,$FC,$FC,$FC,$FC,$04
; tile $52: block16 BL
    .byte $40,$40,$40,$40,$40,$40,$7F,$00
    .byte $7F,$7F,$7F,$7F,$7F,$7F,$40,$00
; tile $53: block16 BR
    .byte $02,$02,$02,$02,$02,$02,$FE,$00
    .byte $FC,$DC,$DC,$DC,$DC,$DC,$00,$00

; ---- 決意マン (scratchpad の ketsuiman.py で生成。スプライトパレット1) ----
; tile $54: ketsuiman TL
    .byte $00,$00,$00,$03,$07,$0F,$0F,$0F
    .byte $01,$03,$07,$0F,$1F,$3B,$79,$F9
; tile $55: ketsuiman TR
    .byte $00,$00,$00,$C0,$E0,$F0,$F0,$F0
    .byte $80,$C0,$E0,$F0,$F8,$DC,$9E,$9F
; tile $56: ketsuiman BL
    .byte $0F,$0F,$07,$00,$00,$00,$00,$00
    .byte $FF,$FE,$7F,$3F,$1F,$0F,$03,$01
; tile $57: ketsuiman BR
    .byte $F0,$F0,$E0,$00,$00,$00,$00,$00
    .byte $FF,$7F,$FE,$FC,$F8,$F0,$C0,$80

; ---- 決意マン ダメージ顔 (X目+口開け) と ヒットエフェクト (hurtfx.py で生成) ----
; tile $58: ketsuiman hurt TL
    .byte $00,$00,$00,$03,$07,$0F,$0F,$0F
    .byte $01,$03,$07,$0F,$1F,$3F,$7B,$FD
; tile $59: ketsuiman hurt TR
    .byte $00,$00,$00,$C0,$E0,$F0,$F0,$F0
    .byte $80,$C0,$E0,$F0,$F8,$FC,$DE,$BF
; tile $5A: ketsuiman hurt BL
    .byte $0F,$0F,$07,$00,$00,$00,$00,$00
    .byte $FF,$FC,$7E,$3F,$1F,$0F,$03,$01
; tile $5B: ketsuiman hurt BR
    .byte $F0,$F0,$E0,$00,$00,$00,$00,$00
    .byte $FF,$3F,$7E,$FC,$F8,$F0,$C0,$80
; tile $5C: hit fx small (小スパーク)
    .byte $00,$10,$28,$44,$28,$10,$00,$00
    .byte $00,$10,$38,$6C,$38,$10,$00,$00
; tile $5D: hit fx big (炸裂バースト)
    .byte $99,$42,$00,$81,$81,$00,$42,$99
    .byte $99,$5A,$24,$C3,$C3,$24,$5A,$99

; ---- アイテム (items.py で生成) ----
; tile $5E: star item (無敵の星, パレット1)
    .byte $00,$00,$00,$18,$18,$00,$00,$00
    .byte $10,$10,$38,$FF,$7C,$38,$6C,$44
; tile $5F: power item (パワー矢, パレット0)
    .byte $18,$3C,$7E,$18,$18,$18,$3C,$00
    .byte $18,$3C,$7E,$18,$18,$18,$3C,$00

; ---- 狩人ダメージ顔と「ステージクリア!」 (clear_death.py で生成) ----
; tile $60: hunter hurt TL (X目)
    .byte $0F,$0F,$7F,$FF,$FF,$7F,$7F,$31
    .byte $00,$00,$00,$00,$03,$03,$03,$01
; tile $61: hunter hurt TR
    .byte $F0,$F0,$F4,$F2,$F2,$F2,$F2,$E2
    .byte $00,$00,$00,$70,$A0,$D0,$90,$E0
; tile $62-$69: 「ステージクリア!」 (美咲太字, 色3)
    .byte $00,$7E,$06,$0C,$0C,$3E,$E3,$00
    .byte $00,$7E,$06,$0C,$0C,$3E,$E3,$00
    .byte $7E,$00,$FF,$18,$18,$18,$30,$00
    .byte $7E,$00,$FF,$18,$18,$18,$30,$00
    .byte $00,$00,$C0,$7F,$00,$00,$00,$00
    .byte $00,$00,$C0,$7F,$00,$00,$00,$00
    .byte $6F,$30,$63,$33,$06,$0C,$78,$00
    .byte $6F,$30,$63,$33,$06,$0C,$78,$00
    .byte $18,$1F,$33,$63,$06,$0C,$38,$00
    .byte $18,$1F,$33,$63,$06,$0C,$38,$00
    .byte $66,$66,$66,$66,$06,$0C,$38,$00
    .byte $66,$66,$66,$66,$06,$0C,$38,$00
    .byte $7F,$03,$1E,$1C,$18,$18,$30,$00
    .byte $7F,$03,$1E,$1C,$18,$18,$30,$00
    .byte $60,$60,$60,$60,$00,$60,$00,$00
    .byte $60,$60,$60,$60,$00,$60,$00,$00

; tile $6A-$6D: 遠景の山シルエット (紺)
    .byte $01,$03,$07,$0F,$1F,$3F,$7F,$FF
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $80,$C0,$E0,$F0,$F8,$FC,$FE,$FF
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $10,$38,$7C,$FE,$FF,$FF,$FF,$FF
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; tile $6E-$7F: 未使用
    .res 18*16, $00
; tile $80-$BF: ASCII フォント ($20-$5F)
.include "font.s"

; ---- ボス決意マン (32x32 = 4x4 タイル $C0-$CF, bossgen.py 生成) ----
; tile (boss) 0,0
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; tile $D1: boss 0,1
    .byte $00,$00,$00,$00,$00,$00,$0F,$0F
    .byte $03,$03,$0F,$0F,$3F,$3F,$FF,$FF
; tile $D2: boss 0,2
    .byte $00,$00,$00,$00,$00,$00,$F0,$F0
    .byte $C0,$C0,$F0,$F0,$FC,$FC,$FF,$FF
; tile $D3: boss 0,3
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $00,$00,$00,$00,$00,$00,$00,$00
; tile $D4: boss 1,0
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $03,$03,$0F,$0F,$3F,$3F,$FF,$FF
; tile $D5: boss 1,1
    .byte $3F,$3F,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$CF,$CF,$C3,$C3,$C3,$C3
; tile $D6: boss 1,2
    .byte $FC,$FC,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$FF,$F3,$F3,$C3,$C3,$C3,$C3
; tile $D7: boss 1,3
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $C0,$C0,$F0,$F0,$FC,$FC,$FF,$FF
; tile $D8: boss 2,0
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $FF,$FF,$FF,$FF,$3F,$3F,$0F,$0F
; tile $D9: boss 2,1
    .byte $FF,$FF,$FF,$FF,$3F,$3F,$00,$00
    .byte $FF,$FF,$FC,$FC,$FF,$FF,$FF,$FF
; tile $DA: boss 2,2
    .byte $FF,$FF,$FF,$FF,$FC,$FC,$00,$00
    .byte $FF,$FF,$3F,$3F,$FF,$FF,$FF,$FF
; tile $DB: boss 2,3
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $FF,$FF,$FF,$FF,$FC,$FC,$F0,$F0
; tile $DC: boss 3,0
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $03,$03,$00,$00,$00,$00,$00,$00
; tile $DD: boss 3,1
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $FF,$FF,$FF,$FF,$0F,$0F,$03,$03
; tile $DE: boss 3,2
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $FF,$FF,$FF,$FF,$F0,$F0,$C0,$C0
; tile $DF: boss 3,3
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $C0,$C0,$00,$00,$00,$00,$00,$00
