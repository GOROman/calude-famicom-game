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

; tile $07-$0F: 未使用 (行頭合わせのパディング)
    .res 9*16, $00
; tile $10-$4F: 隠しメッセージ
.include "easteregg.s"
