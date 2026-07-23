; CHR-ROM パターンデータ (残り領域はリンカが $00 で埋める)
; 主人公: 狩人 Calude (16x16 = 8x8 タイル4枚)。フード+弓持ち、右向き
; ドット絵は scratchpad の hunter.py で生成

; tile $00: blank
    .res 16, $00
; tile $01: hunter top-left
    .byte $07,$08,$10,$17,$17,$17,$08,$10
    .byte $00,$07,$0F,$0F,$0D,$0F,$07,$0F
; tile $02: hunter top-right
    .byte $E0,$10,$08,$EA,$EB,$EB,$13,$0F
    .byte $00,$E0,$F0,$F0,$B2,$F2,$E2,$F6
; tile $03: hunter bottom-left
    .byte $20,$20,$10,$0C,$09,$09,$09,$1E
    .byte $1F,$1F,$0F,$03,$06,$06,$06,$00
; tile $04: hunter bottom-right
    .byte $07,$07,$0B,$33,$93,$92,$90,$F0
    .byte $FA,$FA,$F2,$C2,$62,$60,$60,$00

; ---- BG タイル (scratchpad の ground.py で生成) ----
; tile $05: grass top (地面の上端: 明緑の草 + 茶の土)
    .byte $00,$44,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$BB,$00,$FF,$DF,$FD,$FF,$BF
; tile $06: dirt (土: 茶ベースに暗色の粒)
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $FF,$EF,$FE,$7F,$FB,$DF,$FF,$F7

; tile $07: block (レンガブロック: 茶ベース+暗色の目地)
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $EE,$EE,$00,$BB,$BB,$00,$EE,$00

; tile $08: arrow (矢: 右向き。左向きは水平反転で描画)
; r3 に鏃の上、r4 にシャフト(肌色)+鏃(黒)、r5 に鏃の下
    .byte $00,$00,$00,$04,$FF,$04,$00,$00
    .byte $00,$00,$00,$00,$FC,$00,$00,$00

; ---- アニメポーズ (scratchpad の poses.py で生成) ----
; tile $09: walk2 bottom-left (足を開いた歩きポーズ)
    .byte $20,$20,$10,$0C,$12,$24,$38,$00
    .byte $1F,$1F,$0F,$03,$0C,$18,$00,$00
; tile $0A: walk2 bottom-right
    .byte $07,$07,$0B,$33,$4B,$25,$1C,$00
    .byte $FA,$FA,$F2,$C2,$32,$18,$00,$00
; tile $0B: jump bottom-left (足をたたんだ空中ポーズ)
    .byte $20,$20,$10,$0F,$13,$13,$0C,$00
    .byte $1F,$1F,$0F,$00,$0C,$0C,$00,$00
; tile $0C: jump bottom-right
    .byte $07,$07,$0B,$C3,$23,$22,$C0,$00
    .byte $FA,$FA,$F2,$02,$C2,$C0,$00,$00
; tile $0D: attack top-left (弓を引くポーズ)
    .byte $07,$08,$10,$17,$17,$17,$08,$10
    .byte $00,$07,$0F,$0F,$0D,$0F,$07,$0F
; tile $0E: attack top-right
    .byte $E0,$10,$08,$EA,$ED,$ED,$19,$3F
    .byte $00,$E0,$F0,$F0,$B4,$F4,$E8,$D8

; tile $0F: 未使用 (行頭合わせのパディング)
    .res 16, $00
; tile $10-$4F: 隠しメッセージ
.include "easteregg.s"

; ---- 16x16 メタタイル (scratchpad の brick16.py で生成) ----
; SMB 風の 16x16 ブロック (輪郭+左上ハイライト+レンガ目地)
; tile $50: block16 TL
    .byte $FF,$9F,$BF,$FF,$FF,$FF,$FF,$FF
    .byte $00,$7F,$7F,$7F,$40,$7B,$7B,$7B
; tile $51: block16 TR
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $00,$DE,$DE,$DE,$02,$FE,$FE,$FE
; tile $52: block16 BL
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $40,$7F,$7F,$7F,$40,$7B,$7B,$00
; tile $53: block16 BR
    .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF
    .byte $02,$DE,$DE,$DE,$02,$FE,$FE,$00

; ---- 決意マン (scratchpad の ketsuiman.py で生成。スプライトパレット1) ----
; tile $54: ketsuiman TL
    .byte $00,$00,$00,$03,$07,$0F,$0F,$0F
    .byte $01,$03,$07,$0F,$1F,$3F,$79,$F9
; tile $55: ketsuiman TR
    .byte $00,$00,$00,$C0,$E0,$F0,$F0,$F0
    .byte $80,$C0,$E0,$F0,$F8,$FC,$9E,$9F
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
