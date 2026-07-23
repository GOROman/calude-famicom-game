; レベル: 128列 (4画面分) の列単位マップと横スクロール
; - update_camera: プレイヤー中央追従 + 8px境界を越えたら画面外の列をキュー
; - 列ストリーミング: NMI が col_buf を PPU へ縦書き転送 (SMB 方式)

LEVEL_COLS  = 128
MAX_SCROLL  = (LEVEL_COLS - 32) * 8     ; 768
WORLD_X_MAX = LEVEL_COLS * 8 - 16       ; 1008
CAMERA_LOCK = 120                       ; プレイヤーを置く画面 X

TILE_GRASS = $05
TILE_DIRT  = $06
TILE_BLOCK = $07

.segment "CODE"

; ---- 起動時: 最初の2画面分 (列0-63) を直接描画 (描画オフ中に呼ぶ) ----
level_init:
    lda #$FF
    sta col_pending
    lda #0
    sta prev_col
    ldx #0
@loop:
    txa
    pha
    jsr queue_column
    lda #%00000100      ; NMI オフのまま +32 インクリメント
    sta PPUCTRL
    jsr write_column
    pla
    tax
    inx
    cpx #64
    bne @loop
    lda #0
    sta PPUCTRL
    rts

; ---- カメラ更新: scroll = clamp(world_x - 120, 0, MAX_SCROLL) ----
update_camera:
    lda world_x_lo
    sec
    sbc #CAMERA_LOCK
    sta scroll_lo
    lda world_x_hi
    sbc #0
    sta scroll_hi
    bpl :+
    lda #0              ; 左端
    sta scroll_lo
    sta scroll_hi
:   lda scroll_hi
    cmp #>MAX_SCROLL
    bcc @clamped
    bne @clamp
    lda scroll_lo
    cmp #<MAX_SCROLL
    bcc @clamped
    beq @clamped
@clamp:
    lda #<MAX_SCROLL
    sta scroll_lo
    lda #>MAX_SCROLL
    sta scroll_hi
@clamped:
    ; 左端の列番号 = scroll >> 3 (0..96)
    lda scroll_hi
    sta tmp
    lda scroll_lo
    lsr tmp
    ror a
    lsr tmp
    ror a
    lsr tmp
    ror a
    cmp prev_col
    beq @done           ; 列境界を越えていない
    pha
    bcc @left           ; 減った → 左へスクロール中
    clc                 ; 増えた → 右端の外の列を用意
    adc #32
    jsr queue_column
    jmp @store
@left:
    jsr queue_column    ; 左から入ってくる列を再描画
@store:
    pla
    sta prev_col
@done:
    rts

; ---- 列をキュー: A = レベル列番号 (範囲外は無視) ----
; col_buf 構築 + 転送先 PPU アドレス計算 (2画面のリングに配置)
queue_column:
    cmp #LEVEL_COLS
    bcs @out
    sta col_pending
    jsr render_column
    lda col_pending
    and #63             ; リングスロット (NT0/NT1 で 64列)
    tay
    and #31
    sta col_ppu_lo
    tya
    and #32
    beq :+
    lda #$04            ; スロット32-63 → NT1 ($2400)
:   ora #$20
    sta col_ppu_hi
@out:
    rts

; ---- col_buf を PPU へ転送 (呼び出し前に PPUCTRL を +32 モードにすること) ----
write_column:
    bit PPUSTATUS
    lda col_ppu_hi
    sta PPUADDR
    lda col_ppu_lo
    sta PPUADDR
    ldy #0
:   lda col_buf,y
    sta PPUDATA
    iny
    cpy #30
    bne :-
    lda #$FF
    sta col_pending
    rts

; ---- 列レンダラ: A = タイル列番号 → col_buf (30タイル) ----
; ブロックはスーパーマリオと同じ 16x16 (2x2タイル)。level_map は 16px 単位の
; メタ列 (64個)。タイル列の偶奇でブロックの左半分/右半分を描き分ける。
; フィーチャ: 0=平地 1=ブロック(地上1個) 2=ブロック(縦2個) 3=浮き(低) 4=浮き(高)
render_column:
    tay
    and #1
    sta tmp             ; 0=左半分, 1=右半分
    tya
    lsr
    tax
    lda level_map,x     ; メタ列のフィーチャ
    sta tmp2
    lda #0
    ldy #29
:   sta col_buf,y
    dey
    bpl :-
    lda #TILE_GRASS     ; 地面は常にある
    sta col_buf+25
    lda #TILE_DIRT
    sta col_buf+26
    sta col_buf+27
    sta col_buf+28
    sta col_buf+29
    lda tmp2
    beq @done
    cmp #1
    bne :+
    ldy #23             ; 地上に1個 (行23-24)
    jmp put_block
:   cmp #2
    bne :+
    ldy #21             ; 縦に2個 (行21-24)
    jsr put_block
    ldy #23
    jmp put_block
:   cmp #3
    bne :+
    ldy #18             ; 浮きブロック低 (行18-19)
    jmp put_block
:   ldy #15             ; 浮きブロック高 (行15-16)
    jmp put_block
@done:
    rts

; ---- 16x16 ブロックの半列を書く: Y = 上の行, tmp = 左右半分 ----
put_block:
    ldx tmp
    lda block16_top,x
    sta col_buf,y
    lda block16_bot,x
    iny
    sta col_buf,y
    rts

; ---- 当たり判定: 点 (tmp/tmp2 = ワールドX 16bit, A = Y) を含むソリッドの上端 ----
; 出力: A = 上端 Y (200/184/168/144/120)、空なら $FF。X, tmp3 を破壊
probe_top:
    sta tmp3
    cmp #GROUND_TOP_Y
    bcc :+
    lda #GROUND_TOP_Y   ; 地面
    rts
:   lda tmp             ; メタ列 = (x >> 4) & 63
    lsr
    lsr
    lsr
    lsr
    ldx tmp2
    beq :+
    ora metacol_hi,x
:   tax
    lda level_map,x
    beq @empty
    tax
    lda tmp3
    cmp block_top_tbl,x
    bcc @empty          ; ブロックより上
    cmp block_bot_tbl,x
    bcs @empty          ; ブロックより下
    lda block_top_tbl,x
    rts
@empty:
    lda #$FF
    rts

GROUND_TOP_Y = 200

.segment "RODATA"
metacol_hi:    .byte $00, $10, $20, $30
block_top_tbl: .byte 0, 184, 168, 144, 120  ; フィーチャ番号 → ブロック上端 Y
block_bot_tbl: .byte 0, 200, 200, 160, 136  ; 同 下端 Y
.segment "CODE"

.segment "RODATA"
block16_top: .byte $50, $51             ; 16x16 ブロックの上段 (左, 右)
block16_bot: .byte $52, $53             ; 下段 (左, 右)

; 64メタ列 (16px単位) 分のフィーチャマップ
; 直前の "LVLMAP01" はステージエディタが ROM 内の位置を特定するためのマーカー
level_magic:
    .byte "LVLMAP01"
level_map:
    .res 8, 0                           ; 0-7: 平地
    .byte 3,3                           ; 8-9: 浮きブロック
    .res 3, 0                           ; 10-12
    .byte 1                             ; 13: ブロック
    .byte 0
    .byte 1                             ; 15: ブロック
    .byte 4,4                           ; 16-17: 高い浮きブロック
    .res 2, 0                           ; 18-19
    .byte 3,4,3                         ; 20-22: 山なり
    .res 3, 0                           ; 23-25
    .byte 2                             ; 26: 縦2個
    .byte 0
    .byte 2                             ; 28: 縦2個
    .res 3, 0                           ; 29-31
    .byte 3,4,4,3                       ; 32-35: アーチ
    .res 4, 0                           ; 36-39
    .byte 1,1,2,2                       ; 40-43: 階段
    .res 2, 0                           ; 44-45
    .byte 3,3                           ; 46-47
    .byte 0
    .byte 1,2,2,1                       ; 49-52: 台形
    .byte 0
    .byte 3,3                           ; 54-55
    .res 4, 0                           ; 56-59
    .byte 2,2                           ; 60-61: 高柱
    .res 2, 0                           ; 62-63: ゴール前
