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

    ; 地面: タイル行25 (y=200-207) に草, 行26-29 に土
    ; $2000 + 25*32 = $2320
    bit PPUSTATUS
    lda #$23
    sta PPUADDR
    lda #$20
    sta PPUADDR
    lda #$05            ; 草タイル x32
    ldx #32
@grass:
    sta PPUDATA
    dex
    bne @grass
    lda #$06            ; 土タイル x128 (4行)
    ldx #128
@dirt:
    sta PPUDATA
    dex
    bne @dirt
    rts

.segment "RODATA"
palette_data:
    ; BG パレット0 (空色, 暗緑, 明緑, 茶 = 地面用)
    .byte $21,$09,$29,$17
    .byte $21,$09,$29,$17
    .byte $21,$09,$29,$17
    .byte $21,$09,$29,$17
    ; スプライトパレット (輪郭=黒, フード/服=緑, 肌/弦=肌色)
    .byte $21,$0F,$1A,$27
    .byte $21,$0F,$1A,$27
    .byte $21,$0F,$1A,$27
    .byte $21,$0F,$1A,$27
