; PPU 初期化: パレット設定とネームテーブルのクリア
; 呼び出し時は描画オフ (PPUMASK=0) であること

.segment "CODE"
ppu_init:
    ; パレット転送 ($3F00-$3F1F)
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$00
@pal:
    lda palette_data,x
    sta PPUDATA
    inx
    cpx #32
    bne @pal

    ; ネームテーブル2面 + 属性テーブルをタイル0でクリア ($2000-$27FF)
    bit PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #$08            ; 256バイト x 8ページ = $800
    ldy #$00
    lda #$00
@clr:
    sta PPUDATA
    iny
    bne @clr
    dex
    bne @clr
    rts

.segment "RODATA"
palette_data:
    ; BG パレット (背景色 = 空色)
    .byte $21,$0F,$29,$30
    .byte $21,$0F,$29,$30
    .byte $21,$0F,$29,$30
    .byte $21,$0F,$29,$30
    ; スプライトパレット (輪郭=黒, 体=赤, アクセント=白)
    .byte $21,$0F,$16,$30
    .byte $21,$0F,$16,$30
    .byte $21,$0F,$16,$30
    .byte $21,$0F,$16,$30
