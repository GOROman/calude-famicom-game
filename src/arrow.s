; 弓矢: B ボタンで発射、画面内に最大2発
; ワールド座標で飛び、画面外に出たら消える

ARROW_SPEED = 4         ; px/フレーム
ARROW_TILE  = $08
ARROW_OAM   = 16        ; OAM バッファ内オフセット (スプライト4,5 = プレイヤーの次)

.segment "CODE"

update_arrows:
    ; ---- 移動と画面外判定 (発射より先に処理 → 発射フレームでは動かない) ----
    ldx #0
@move_loop:
    lda arrow_flag,x
    beq @next
    cmp #1
    bne @move_left
    lda arrow_xlo,x     ; 右へ
    clc
    adc #ARROW_SPEED
    sta arrow_xlo,x
    lda arrow_xhi,x
    adc #0
    sta arrow_xhi,x
    jmp @check
@move_left:
    lda arrow_xlo,x     ; 左へ
    sec
    sbc #ARROW_SPEED
    sta arrow_xlo,x
    lda arrow_xhi,x
    sbc #0
    sta arrow_xhi,x
    bmi @despawn        ; ワールド左端外
@check:
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
    bne @move_loop

    ; ---- 発射: B の立ち上がりエッジ ----
    lda buttons
    and #BTN_B
    beq @done
    lda prev_buttons
    and #BTN_B
    bne @done
    ldx #0              ; 空きスロットを探す
    lda arrow_flag
    beq @spawn
    ldx #1
    lda arrow_flag+1
    bne @done           ; 2発とも飛行中 → 撃てない
@spawn:
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
    lda player_y        ; 弓の高さ (手元)
    clc
    adc #6
    sta arrow_y,x
    lda #12             ; 弓を引くポーズを12フレーム表示
    sta attack_timer
@done:
    rts

; ---- 矢を OAM バッファへ (スプライト 4,5) ----
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
    lda #ARROW_TILE
    sta OAM_BUF,y       ; タイル
    iny
    lda arrow_flag,x
    cmp #2
    bne :+
    lda #$40            ; 左向きは水平反転
    .byte $2C           ; bit abs (次の lda #0 をスキップ)
:   lda #$00
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
