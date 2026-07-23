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
    rts                 ; 地面/ブロックは level_init の列描画が担当

.segment "RODATA"
palette_data:
    ; BG パレット0 (空色, 暗緑, 明緑, 茶 = 地面用)
    .byte $21,$09,$29,$17
    .byte $21,$09,$29,$17
    .byte $21,$09,$29,$17
    .byte $21,$09,$29,$17
    ; スプライトパレット0: 狩人 (輪郭=黒, フード/服=緑, 肌/弦=肌色)
    .byte $21,$0F,$1A,$27
    ; スプライトパレット1: 決意マン (青=目/口, 黄=体, 白=顔)
    .byte $21,$12,$28,$30
    .byte $21,$0F,$1A,$27
    .byte $21,$0F,$1A,$27
