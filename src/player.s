; プレイヤー: 左右移動 + ジャンプ (Y は 8.8 固定小数点の速度で滑らかに)

PLAYER_SPEED    = 2         ; 横移動 px/フレーム
PLAYER_GROUND_Y = 184       ; 接地時のスプライト上端 Y (地面ライン = 200)

; スーパーマリオ風可変ジャンプ (SMB の JumpMForceData/FallMForceData 相当)
JUMP_VEL_HI     = $FC       ; ジャンプ初速 -4.0 px/フレーム (SMB PlayerYSpdData)
GRAV_HOLD       = $20       ; 上昇中に A 押下中の弱い重力 (SMB JumpMForceData)
GRAV_FALL       = $70       ; A 解放後/下降中の強い重力 (SMB FallMForceData)
MAX_FALL_SPEED  = 4         ; 落下速度の上限 px/フレーム (SMB ImposeGravity)

.segment "CODE"
player_init:
    lda #120            ; ワールド X = 120 (画面中央スタート)
    sta world_x_lo
    lda #0
    sta world_x_hi
    lda #PLAYER_GROUND_Y
    sta player_y
    lda #1
    sta on_ground
    rts

update_player:
    ; ---- 左右移動 (16bit ワールド座標) ----
    lda buttons
    and #BTN_LEFT
    beq @not_left
    lda #1
    sta facing
    lda world_x_lo
    sec
    sbc #PLAYER_SPEED
    sta world_x_lo
    lda world_x_hi
    sbc #0
    sta world_x_hi
    bpl @not_left
    lda #0              ; 左端 (world 0) でクランプ
    sta world_x_lo
    sta world_x_hi
@not_left:
    lda buttons
    and #BTN_RIGHT
    beq @not_right
    lda #0
    sta facing
    lda world_x_lo
    clc
    adc #PLAYER_SPEED
    sta world_x_lo
    lda world_x_hi
    adc #0
    sta world_x_hi
    cmp #>WORLD_X_MAX   ; 右端クランプ
    bcc @not_right
    lda world_x_lo
    cmp #<WORLD_X_MAX
    bcc @not_right
    lda #<WORLD_X_MAX
    sta world_x_lo
    lda #>WORLD_X_MAX
    sta world_x_hi
@not_right:

    ; ---- ジャンプ開始 (A の立ち上がりエッジのみ。押しっぱなし再ジャンプ禁止) ----
    lda on_ground
    beq @airborne
    lda buttons
    and #BTN_A
    beq @done           ; 接地中で A 押下なし → 縦方向の処理なし
    lda prev_buttons
    and #BTN_A
    bne @done           ; 前フレームから押しっぱなし → ジャンプしない
    lda #0
    sta on_ground
    sta vel_y_lo
    lda #JUMP_VEL_HI
    sta vel_y_hi
    lda player_y
    sta jump_origin_y   ; SMB: 跳んだ高さの判定用に開始位置を記録

@airborne:
    ; 重力選択: 上昇中かつ A 押下中だけ弱い重力 → 押下時間でジャンプ高が変わる
    ldy #GRAV_FALL
    lda vel_y_hi
    bpl @apply_grav     ; 下降中 (速度 >= 0) は常に強い重力
    lda buttons
    and #BTN_A
    bne @weak_grav      ; A 押下中は弱い重力
    lda jump_origin_y   ; SMB DiffToHaltJump: 跳び始め (1px 未満上昇) は
    sec                 ; A を離していても弱い重力のまま
    sbc player_y
    cmp #1
    bcs @apply_grav
@weak_grav:
    ldy #GRAV_HOLD
@apply_grav:
    tya                 ; 速度 += 重力
    clc
    adc vel_y_lo
    sta vel_y_lo
    lda vel_y_hi
    adc #0
    sta vel_y_hi
    ; 落下速度の上限
    bmi @no_cap         ; 上昇中はそのまま
    cmp #MAX_FALL_SPEED
    bcc @no_cap
    lda #MAX_FALL_SPEED
    sta vel_y_hi
    lda #0
    sta vel_y_lo
@no_cap:
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
    lda world_x_lo      ; 画面 X = ワールド X - スクロール X
    sec
    sbc scroll_lo
    sta player_x
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
