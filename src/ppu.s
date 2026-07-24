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
    ; BG パレット0 (夜: 黒空, 暗茶, 暗緑, 茶 — タイトル画面の暗い雰囲気)
    .byte $0F,$07,$19,$17
    .byte $0F,$07,$19,$17
    .byte $0F,$07,$19,$17
    .byte $0F,$07,$19,$17
    ; スプライトパレット0: 少女狩人 (髪/ブーツ=濃茶, 服=ピンク, 肌)
    .byte $0F,$07,$25,$37
    ; スプライトパレット1: 決意マン (青=目/口, 暗い金=体, 白=顔)
    .byte $0F,$12,$27,$30
    .byte $0F,$07,$25,$37
    .byte $0F,$07,$25,$37
