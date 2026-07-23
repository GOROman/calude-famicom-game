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

; ---- 列レンダラ: A = 列番号 → col_buf (30タイル) ----
; フィーチャ: 0=平地 1=柱(高2) 2=柱(高4) 3=浮きブロック(低) 4=浮きブロック(高)
render_column:
    tax
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
    lda level_map,x
    beq @done
    cmp #1
    bne :+
    lda #TILE_BLOCK
    sta col_buf+23
    sta col_buf+24
    rts
:   cmp #2
    bne :+
    lda #TILE_BLOCK
    sta col_buf+21
    sta col_buf+22
    sta col_buf+23
    sta col_buf+24
    rts
:   cmp #3
    bne :+
    lda #TILE_BLOCK
    sta col_buf+19
    rts
:   lda #TILE_BLOCK
    sta col_buf+16
@done:
    rts

.segment "RODATA"
; 128列分のフィーチャマップ
level_map:
    .res 16, 0                          ; 0-15: 平地
    .byte 3,3,3                         ; 16-18: 浮きブロック
    .res 5, 0                           ; 19-23
    .byte 1                             ; 24: 柱
    .res 3, 0                           ; 25-27
    .byte 1                             ; 28: 柱
    .res 3, 0                           ; 29-31
    .byte 4,4,4,4                       ; 32-35: 高い浮きブロック
    .res 4, 0                           ; 36-39
    .byte 3,3,4,3,3                     ; 40-44: 山なりブロック
    .res 7, 0                           ; 45-51
    .byte 2                             ; 52: 高柱
    .res 3, 0                           ; 53-55
    .byte 2                             ; 56: 高柱
    .res 7, 0                           ; 57-63
    .byte 3,4,4,3                       ; 64-67: アーチ
    .res 12, 0                          ; 68-79
    .byte 1,1,2,2                       ; 80-83: 階段
    .res 4, 0                           ; 84-87
    .byte 3,3,3                         ; 88-90
    .res 5, 0                           ; 91-95
    .byte 1,2,2,1                       ; 96-99: 台形
    .res 8, 0                           ; 100-107
    .byte 3,3,3,3                       ; 108-111
    .res 8, 0                           ; 112-119
    .byte 2,2                           ; 120-121: 高柱
    .res 6, 0                           ; 122-127: ゴール前
