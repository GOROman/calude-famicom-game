; 弓矢: B ボタンで発射、画面内に最大2発
; 方向: 通常=向いている左右 / 上+B=真上 / 下+B=真下 (空中クリア用)
; flag: 0=なし 1=右 2=左 3=上 4=下

ARROW_TILE  = $74
ARROW_VTILE = $7E       ; 縦向きの矢 (下向きは V フリップ)
ARROW_OAM   = 32        ; OAM バッファ内オフセット (スプライト8,9 = プレイヤー8枚の次)

.segment "CODE"

update_arrows:
    ; ---- 移動と画面外判定 (発射より先に処理 → 発射フレームでは動かない) ----
    ldx #0
@move_loop:
    lda arrow_flag,x
    bne :+
    jmp @next
:   cmp #3
    bcc @horiz
    beq @move_up
    ; --- 下向き ---
    ldy weapon_level
    lda arrow_y,x
    clc
    adc arrow_speed_tbl,y
    sta arrow_y,x
    cmp #216
    bcc @vtip
    jmp @despawn
@move_up:
    ldy weapon_level
    lda arrow_y,x
    sec
    sbc arrow_speed_tbl,y
    sta arrow_y,x
    cmp #16
    bcs @vtip
    jmp @despawn
@vtip:
    ; 縦矢の先端ブロック判定 (x+4)
    lda arrow_xlo,x
    clc
    adc #4
    sta tmp
    lda arrow_xhi,x
    adc #0
    sta tmp2
    txa
    pha
    lda arrow_y,x
    clc
    adc #4
    jsr probe_top
    cmp #$FF
    beq @vtip_clear
    pla
    tax
    jmp @despawn
@vtip_clear:
    pla
    tax
    jmp @next
@horiz:
    cmp #1
    bne @move_left
    ldy weapon_level    ; パワー矢は速い
    lda arrow_xlo,x     ; 右へ
    clc
    adc arrow_speed_tbl,y
    sta arrow_xlo,x
    lda arrow_xhi,x
    adc #0
    sta arrow_xhi,x
    jmp @check
@move_left:
    ldy weapon_level
    lda arrow_xlo,x     ; 左へ
    sec
    sbc arrow_speed_tbl,y
    sta arrow_xlo,x
    lda arrow_xhi,x
    sbc #0
    sta arrow_xhi,x
    bmi @despawn        ; ワールド左端外
@check:
    ; ---- ブロック命中判定 (矢の先端) ----
    lda arrow_flag,x
    cmp #1
    bne @tip_left
    lda arrow_xlo,x     ; 右向き: 先端 = x+8
    clc
    adc #8
    sta tmp
    lda arrow_xhi,x
    adc #0
    jmp @tip_do
@tip_left:
    lda arrow_xlo,x     ; 左向き: 先端 = x
    sta tmp
    lda arrow_xhi,x
@tip_do:
    sta tmp2
    cmp #4
    bcs @despawn        ; ワールド外
    txa
    pha
    lda arrow_y,x
    clc
    adc #4              ; シャフトの高さで判定
    jsr probe_top
    cmp #$FF
    beq @tip_clear
    pla                 ; ブロックに刺さった → 消滅
    tax
    jmp @despawn
@tip_clear:
    pla
    tax
    ; 画面内か: (world - scroll) が 0..255 に収まるか
    lda arrow_xlo,x
    sec
    sbc scroll_lo
    lda arrow_xhi,x
    sbc scroll_hi
    beq @next           ; 上位=0 → 画面内
@despawn:
    lda #0
    sta arrow_flag,x
@next:
    inx
    cpx #2
    beq :+
    jmp @move_loop
:
    ; ---- 発射: B の立ち上がりエッジ ----
    lda buttons
    and #BTN_B
    beq @done
    lda prev_buttons
    and #BTN_B
    bne @done
    ldx #0              ; 空きスロットを探す (通常は1発, パワー矢で2発)
    lda arrow_flag
    beq @spawn
    lda weapon_level
    beq @done           ; 通常装備は1発まで
    ldx #1
    lda arrow_flag+1
    bne @done           ; 2発とも飛行中 → 撃てない
@spawn:
    lda buttons         ; 上+B = 真上へ / 下+B = 真下へ
    and #BTN_UP
    bne @spawn_up
    lda buttons
    and #BTN_DOWN
    bne @spawn_down
    lda facing
    beq @spawn_right
    lda #2              ; 左向き発射
    sta arrow_flag,x
    lda world_x_lo      ; 発射位置: プレイヤー左端-8
    sec
    sbc #8
    sta arrow_xlo,x
    lda world_x_hi
    sbc #0
    sta arrow_xhi,x
    jmp @spawn_y
@spawn_right:
    lda #1              ; 右向き発射
    sta arrow_flag,x
    lda world_x_lo      ; 発射位置: プレイヤー右端
    clc
    adc #16
    sta arrow_xlo,x
    lda world_x_hi
    adc #0
    sta arrow_xhi,x
@spawn_y:
    lda player_y        ; 弓の高さ (手元 = 胴のあたり)
    clc
    adc #10
    sta arrow_y,x
    jmp @spawn_fx
@spawn_up:
    lda #3
    sta arrow_flag,x
    jsr @spawn_center_x
    lda player_y        ; 頭上から
    sec
    sbc #6
    sta arrow_y,x
    jmp @spawn_fx
@spawn_down:
    lda #4
    sta arrow_flag,x
    jsr @spawn_center_x
    lda player_y        ; 足元から
    clc
    adc #30
    sta arrow_y,x
@spawn_fx:
    lda #12             ; 弓を引くポーズを12フレーム表示
    sta attack_timer
    jsr sfx_shot
@done:
    rts
@spawn_center_x:
    lda world_x_lo      ; プレイヤー中央
    clc
    adc #4
    sta arrow_xlo,x
    lda world_x_hi
    adc #0
    sta arrow_xhi,x
    rts

; ---- 矢を OAM バッファへ (スプライト 8,9) ----
draw_arrows:
    ldx #0              ; スロット
    ldy #ARROW_OAM      ; OAM オフセット
@loop:
    lda arrow_flag,x
    bne @visible
    lda #$FF            ; 非アクティブ → 画面外へ
    sta OAM_BUF,y
    jmp @next
@visible:
    lda arrow_y,x
    sta OAM_BUF,y       ; Y
    iny
    lda arrow_flag,x
    cmp #3
    bcc @h_tile
    lda #ARROW_VTILE    ; 縦向き
    sta OAM_BUF,y
    iny
    lda arrow_flag,x
    cmp #4
    bne :+
    lda #$80            ; 下向きは V フリップ
    .byte $2C
:   lda #$00
    jmp @attr
@h_tile:
    lda #ARROW_TILE
    sta OAM_BUF,y       ; タイル
    iny
    lda arrow_flag,x
    cmp #2
    bne :+
    lda #$40            ; 左向きは水平反転
    .byte $2C           ; bit abs (次の lda #0 をスキップ)
:   lda #$00
@attr:
    sta OAM_BUF,y       ; 属性
    iny
    lda arrow_xlo,x
    sec
    sbc scroll_lo
    sta OAM_BUF,y       ; X (画面座標)
    dey
    dey
    dey
@next:
    iny
    iny
    iny
    iny
    inx
    cpx #2
    bne @loop
    rts

.segment "RODATA"
arrow_speed_tbl: .byte 4, 6 ; 矢の速度 (通常, パワー矢)
.segment "CODE"
