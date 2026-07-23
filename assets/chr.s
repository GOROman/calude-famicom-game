; CHR-ROM パターンデータ (残り領域はリンカが $00 で埋める)
; プレイヤーは 16x16 (8x8 タイル4枚構成)

; tile $00: blank
    .res 16, $00
; tile $01: player top-left
    .byte $3F,$40,$98,$98,$80,$87,$40,$3F
    .byte $00,$3F,$7F,$7F,$7F,$7F,$3F,$00
; tile $02: player top-right
    .byte $FC,$02,$19,$19,$01,$E1,$02,$FC
    .byte $00,$FC,$FE,$FE,$FE,$FE,$FC,$00
; tile $03: player bottom-left
    .byte $13,$10,$16,$10,$19,$09,$09,$0F
    .byte $0C,$0F,$0F,$0F,$06,$06,$06,$00
; tile $04: player bottom-right
    .byte $C8,$08,$68,$08,$98,$90,$90,$78
    .byte $30,$F0,$F0,$F0,$60,$60,$60,$00
