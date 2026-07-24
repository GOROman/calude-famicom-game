; ボス決意マン: 1-4 の終盤に鎮座する 32x32 の大決意マン (HP 8)
; - プレイヤーに向かって跳びはねる。接触するとミス (無敵中は1ダメージ与える)
; - 矢 = 1ダメージ / 踏みつけ = 2ダメージ+バウンド。被弾後は20Fの無敵フラッシュ
; - ボス生存中はステージクリア不可 (check_clear がゲートする)
; - 撃破で2000点 + 連続バースト演出

BOSS_OAM     = 176      ; スプライト 44-59 (4x4 = 16枚)
BOSS_GROUND  = 168      ; 接地時の上端 Y (32px なので 168+32=200)
BOSS_HP_MAX  = 8
BOSS_SPAWN_X = 920

.segment "CODE"

; ---- ステージ開始時に呼ぶ: 1-4 だけボスが現れる ----
boss_init:
    lda #0
    sta boss_state
    lda current_stage
    cmp #3
    bne @done
    lda #1
    sta boss_state
    lda #BOSS_HP_MAX
    sta boss_hp
    lda #<BOSS_SPAWN_X
    sta boss_xlo
    lda #>BOSS_SPAWN_X
    sta boss_xhi
    lda #BOSS_GROUND
    sta boss_y
    lda #0
    sta boss_vy_lo
    sta boss_vy_hi
    sta boss_flash
    lda #60
    sta boss_timer
@done:
    rts

update_boss:
    lda boss_state
    bne :+
    rts
:   cmp #2
    bne @alive
    ; ---- 撃破演出: 点滅しつつ周期的にバースト ----
    dec boss_timer
    beq @gone
    lda boss_timer
    and #15
    bne @no_burst
    lda boss_xlo        ; バーストをボスの中でランダムっぽく散らす
    clc
    adc boss_timer
    sta fx_xlo
    lda boss_xhi
    adc #0
    sta fx_xhi
    lda boss_y
    clc
    adc boss_timer
    and #31
    clc
    adc boss_y
    sec
    sbc #8
    sta fx_y
    lda #12
    sta fx_timer
    jsr sfx_hit
@no_burst:
    rts
@gone:
    lda #0
    sta boss_state
    rts

@alive:
    ; ---- フラッシュ (無敵) 減衰 ----
    lda boss_flash
    beq :+
    dec boss_flash
:   ; ---- 行動: 接地中はタイマー → ジャンプ / 空中は放物線 ----
    lda boss_y
    cmp #BOSS_GROUND
    bcc @airborne
    dec boss_timer
    bne @collisions
    lda #40             ; 次のジャンプまでの間隔
    sta boss_timer
    lda #$FD            ; 跳ぶ (-3.0)
    sta boss_vy_hi
    lda #0
    sta boss_vy_lo
    dec boss_y          ; 空中判定に入れる
    jmp @collisions
@airborne:
    ; 重力
    lda boss_vy_lo
    clc
    adc #$30
    sta boss_vy_lo
    lda boss_vy_hi
    adc #0
    sta boss_vy_hi
    ; y += vy
    lda boss_vy_hi
    clc
    adc boss_y
    sta boss_y
    cmp #BOSS_GROUND
    bcc @chase
    lda #BOSS_GROUND    ; 着地
    sta boss_y
    lda #0
    sta boss_vy_lo
    sta boss_vy_hi
    jmp @collisions
@chase:
    ; 空中ではプレイヤーの方向へ 1px/F
    lda world_x_lo
    sec
    sbc boss_xlo
    lda world_x_hi
    sbc boss_xhi
    bmi @move_left
    inc boss_xlo        ; 右へ
    bne @collisions
    inc boss_xhi
    jmp @collisions
@move_left:
    lda boss_xlo
    bne :+
    dec boss_xhi
:   dec boss_xlo

@collisions:
    ; ---- 矢との判定 (2スロット) ----
    ldy #0
@arrow_loop:
    lda arrow_flag,y
    beq @arrow_next
    lda boss_flash
    bne @arrow_next     ; 無敵中は当たらない
    lda arrow_y,y       ; 縦: ボスの高さ帯 (y .. y+32)
    clc
    adc #4
    cmp boss_y
    bcc @arrow_next
    sec
    sbc boss_y
    cmp #32
    bcs @arrow_next
    lda arrow_xlo,y     ; 横: (ax+7) - bx が 0..38
    clc
    adc #7
    sta tmp
    lda arrow_xhi,y
    adc #0
    sta tmp2
    lda tmp
    sec
    sbc boss_xlo
    sta tmp
    lda tmp2
    sbc boss_xhi
    bne @arrow_next
    lda tmp
    cmp #39
    bcs @arrow_next
    lda #0              ; 命中!
    sta arrow_flag,y
    lda #1
    jsr boss_damage
    jmp @player_chk
@arrow_next:
    iny
    cpy #2
    bne @arrow_loop

@player_chk:
    ; ---- プレイヤー接触 (32x32 vs 16x16) ----
    lda boss_state
    cmp #1
    bne @done
    lda player_y        ; 縦: py+16 > by && py < by+32
    clc
    adc #16
    cmp boss_y
    bcc @done
    beq @done
    lda boss_y
    clc
    adc #32
    cmp player_y
    bcc @done
    beq @done
    lda world_x_lo      ; 横: (px+15) - bx が 0..46
    clc
    adc #15
    sta tmp
    lda world_x_hi
    adc #0
    sta tmp2
    lda tmp
    sec
    sbc boss_xlo
    sta tmp
    lda tmp2
    sbc boss_xhi
    bne @done
    lda tmp
    cmp #47
    bcs @done
    ; 接触!
    lda star_timer
    beq @not_star
    lda #1              ; 無敵中: 触れるだけで1ダメージ
    jsr boss_damage
    rts
@not_star:
    lda on_ground
    bne @hurt_player
    lda vel_y_hi
    bmi @hurt_player    ; 上昇中 → やられ
    lda player_y        ; 踏みつけ: ボス上部 (体の上1/3 まで)
    clc
    adc #16
    sec
    sbc boss_y
    cmp #12
    bcs @hurt_player
    lda #2              ; 踏みつけ = 2ダメージ + バウンド
    jsr boss_damage
    lda #0
    sta vel_y_lo
    lda #$FD
    sta vel_y_hi
    lda player_y
    sta jump_origin_y
    rts
@hurt_player:
    jsr player_die_start
@done:
    rts

; ---- ダメージ: A = 量。無敵中は無効。HP0 で撃破演出へ ----
boss_damage:
    ldx boss_flash
    beq :+
    rts
:   sta tmp
    jsr sfx_hit
    lda boss_hp
    sec
    sbc tmp
    sta boss_hp
    beq @defeated
    bmi @defeated
    lda #20             ; 無敵フラッシュ
    sta boss_flash
    rts
@defeated:
    lda #2              ; 撃破演出へ
    sta boss_state
    lda #90
    sta boss_timer
    lda #20             ; ボス撃破 = 2000点
    jsr add_score
    jsr sfx_defeat
    rts

; ---- 描画: 4x4 = 16 スプライト (パレット1) ----
draw_boss:
    lda boss_state
    bne :+
    jmp @hide
:   cmp #2
    bne :+
    lda boss_timer      ; 撃破演出は速い点滅
    and #2
    beq :+
    jmp @hide
:   lda boss_flash      ; 被弾中は点滅
    and #2
    beq :+
    jmp @hide
:   ; 画面 X (圏外なら非表示)
    lda boss_xlo
    sec
    sbc scroll_lo
    sta tmp
    lda boss_xhi
    sbc scroll_hi
    beq :+
    jmp @hide
:   ; 右端 32px はみ出しチェック (画面 X > 224 で簡易非表示)
    lda tmp
    cmp #225
    bcc :+
    jmp @hide
:   ldy #0              ; OAM オフセット
    ldx #0              ; パーツ 0-15
@loop:
    txa
    and #%00001100      ; 行 (パーツ/4) * 8 ... 行 = 上位2bit
    asl                 ; *2 → 行*8
    clc
    adc boss_y
    sta OAM_BUF+BOSS_OAM,y
    iny
    txa
    clc
    adc #$C0            ; タイル $C0 + パーツ
    sta OAM_BUF+BOSS_OAM,y
    iny
    lda #1              ; パレット1 (決意マン色)
    sta OAM_BUF+BOSS_OAM,y
    iny
    txa
    and #3              ; 列 * 8
    asl
    asl
    asl
    clc
    adc tmp
    sta OAM_BUF+BOSS_OAM,y
    iny
    inx
    cpx #16
    bne @loop
    rts
@hide:
    ldx #0
    lda #$FF
:   sta OAM_BUF+BOSS_OAM,x
    inx
    inx
    inx
    inx
    cpx #64
    bcc :-
    rts
