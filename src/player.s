; プレイヤー: 左右移動 + ジャンプ (Y は 8.8 固定小数点の速度で滑らかに)

PLAYER_SPEED    = 2         ; 横移動 px/フレーム
PLAYER_GROUND_Y = 184       ; 接地時のスプライト上端 Y (地面ライン = 200)
PLAYER_X_MAX    = 240 - 16  ; 右端クランプ
JUMP_VEL_HI     = $FB       ; ジャンプ初速 -5.0 px/フレーム (上位バイト)
GRAVITY_LO      = $40       ; 重力 0.25 px/フレーム^2

.segment "CODE"
player_init:
    lda #120
    sta player_x
    lda #PLAYER_GROUND_Y
    sta player_y
    lda #1
    sta on_ground
    rts

update_player:
    ; ---- 左右移動 ----
    lda buttons
    and #BTN_LEFT
    beq @not_left
    lda #1
    sta facing
    lda player_x
    sec
    sbc #PLAYER_SPEED
    bcs :+
    lda #0              ; 左端でクランプ
:   sta player_x
@not_left:
    lda buttons
    and #BTN_RIGHT
    beq @not_right
    lda #0
    sta facing
    lda player_x
    clc
    adc #PLAYER_SPEED
    cmp #PLAYER_X_MAX
    bcc :+
    lda #PLAYER_X_MAX   ; 右端でクランプ
:   sta player_x
@not_right:

    ; ---- ジャンプ開始 ----
    lda on_ground
    beq @airborne
    lda buttons
    and #BTN_A
    beq @done           ; 接地中で A 押下なし → 縦方向の処理なし
    lda #0
    sta on_ground
    sta vel_y_lo
    lda #JUMP_VEL_HI
    sta vel_y_hi

@airborne:
    ; 速度 += 重力
    lda vel_y_lo
    clc
    adc #GRAVITY_LO
    sta vel_y_lo
    lda vel_y_hi
    adc #0
    sta vel_y_hi
    ; 座標 += 速度 (8.8 固定小数点)
    lda player_y_sub
    clc
    adc vel_y_lo
    sta player_y_sub
    lda player_y
    adc vel_y_hi
    sta player_y
    ; ---- 着地判定 ----
    cmp #PLAYER_GROUND_Y
    bcc @done           ; まだ地面より上
    lda #PLAYER_GROUND_Y
    sta player_y
    lda #0
    sta player_y_sub
    sta vel_y_lo
    sta vel_y_hi
    lda #1
    sta on_ground
@done:
    rts

; ---- 16x16 メタスプライト (8x8 x4枚) を OAM バッファへ ----
draw_player:
    lda facing
    beq :+
    lda #$40            ; 左向きは水平反転属性
:   sta tmp_attr
    ldy #0              ; パーツ番号 0-3
    ldx #0              ; OAM オフセット
@loop:
    lda player_y
    clc
    adc spr_yoff,y
    sta OAM_BUF,x       ; Y
    inx
    lda facing
    bne @flip
    lda tiles_right,y
    bne @store_tile     ; タイル番号は常に非0なので必ず分岐
@flip:
    lda tiles_left,y
@store_tile:
    sta OAM_BUF,x       ; タイル
    inx
    lda tmp_attr
    sta OAM_BUF,x       ; 属性 (パレット0)
    inx
    lda player_x
    clc
    adc spr_xoff,y
    sta OAM_BUF,x       ; X
    inx
    iny
    cpy #4
    bne @loop
    rts

.segment "RODATA"
spr_xoff:    .byte 0, 8, 0, 8
spr_yoff:    .byte 0, 0, 8, 8
tiles_right: .byte $01, $02, $03, $04
tiles_left:  .byte $02, $01, $04, $03   ; 反転時は左右の列を入れ替え
