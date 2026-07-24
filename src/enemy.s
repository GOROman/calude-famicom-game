; 決意マン: 地上をパトロールする敵 (最大3体)
; - 2フレームに1px 移動、ブロックや世界の端で折り返す
; - 矢が当たると倒れる / 上から踏むと倒せてプレイヤーはバウンド
; - 地上で接触するとプレイヤーはスタート地点に戻される

ENEMY_Y      = 184      ; 地上歩行 (プレイヤーと同じ接地高)
ENEMY_OAM    = 40       ; OAM オフセット (スプライト 10-21: 4枚 x 3体)
ENEMY_ATTR   = %00000001 ; スプライトパレット1

.segment "CODE"
enemy_init:
    lda current_stage   ; テーブル基点 = ステージ * 3
    asl
    clc
    adc current_stage
    sta tmp
    ldx #2
@loop:
    txa
    clc
    adc tmp
    tay
    lda stage_enemy_lo,y
    sta enemy_xlo,x
    lda stage_enemy_hi,y
    sta enemy_xhi,x
    lda #1
    sta enemy_flag,x
    sta enemy_dir,x     ; 左向きに歩き出す
    lda #0
    sta enemy_timer,x
    dex
    bpl @loop
    rts

update_enemies:
    inc frame_count
    ; ---- ヒットエフェクトのカウントダウン ----
    lda fx_timer
    beq :+
    dec fx_timer
:   ; ---- 消失アニメのカウントダウン (flag=2 → 0) ----
    ldx #2
@dying_loop:
    lda enemy_flag,x
    cmp #2
    bne @dying_next
    dec enemy_timer,x
    bne @dying_next
    lda #0
    sta enemy_flag,x
    jsr spawn_item      ; 消え終わったらアイテムをドロップ
@dying_next:
    dex
    bpl @dying_loop
    ; ---- 移動 (2フレームに1px, 生存中のみ) ----
    lda frame_count
    and #1
    bne @collisions
    ldx #2
@move_loop:
    lda enemy_flag,x
    cmp #1
    bne @move_next
    lda enemy_dir,x
    bne @move_left
    inc enemy_xlo,x     ; 右へ 1px
    bne :+
    inc enemy_xhi,x
:   lda enemy_xlo,x     ; 前縁 (x+15)
    clc
    adc #15
    sta tmp
    lda enemy_xhi,x
    adc #0
    sta tmp2
    jsr enemy_probe
    bcc @move_next
    lda enemy_xlo,x     ; ぶつかった → 1px 戻して反転
    bne :+
    dec enemy_xhi,x
:   dec enemy_xlo,x
    lda #1
    sta enemy_dir,x
    bne @move_next
@move_left:
    lda enemy_xlo,x
    ora enemy_xhi,x
    beq @turn_right     ; 世界の左端
    lda enemy_xlo,x
    bne :+
    dec enemy_xhi,x
:   dec enemy_xlo,x     ; 左へ 1px
    lda enemy_xlo,x     ; 前縁 (x+0)
    sta tmp
    lda enemy_xhi,x
    sta tmp2
    jsr enemy_probe
    bcc @move_next
    inc enemy_xlo,x     ; ぶつかった → 1px 戻して反転
    bne @turn_right
    inc enemy_xhi,x
@turn_right:
    lda #0
    sta enemy_dir,x
@move_next:
    dex
    bpl @move_loop

@collisions:
    ; ---- 矢とプレイヤーの当たり判定 (生存中のみ) ----
    ldx #2
@col_loop:
    lda enemy_flag,x
    cmp #1
    beq :+
    jmp @col_next
:   ; --- 矢 (2スロット) ---
    ldy #0
@arrow_chk:
    lda arrow_flag,y
    beq @arrow_next
    lda arrow_y,y       ; 縦: 矢が敵の高さ帯にあるか
    cmp #177
    bcc @arrow_next
    cmp #200
    bcs @arrow_next
    lda arrow_xlo,y     ; 横: (ax+7) - ex が 0..22 なら命中
    clc
    adc #7
    sta tmp
    lda arrow_xhi,y
    adc #0
    sta tmp2
    lda tmp
    sec
    sbc enemy_xlo,x
    sta tmp
    lda tmp2
    sbc enemy_xhi,x
    bne @arrow_next
    lda tmp
    cmp #23
    bcs @arrow_next
    lda weapon_level    ; 命中! パワー矢は貫通する (通常矢は消える)
    bne :+
    lda #0
    sta arrow_flag,y
:   lda #188
    jsr kill_enemy
    lda #1              ; 矢で撃破 = 100点
    jsr add_score
    jmp @col_next
@arrow_next:
    iny
    cpy #2
    bne @arrow_chk
    ; --- プレイヤー接触 ---
    lda player_y        ; 縦: 敵の高さ帯に重なっているか (py+32 > 185)
    cmp #154
    bcc @col_next
    lda world_x_lo      ; 横: (px+13) - ex が 0..26 なら接触
    clc
    adc #13
    sta tmp
    lda world_x_hi
    adc #0
    sta tmp2
    lda tmp
    sec
    sbc enemy_xlo,x
    sta tmp
    lda tmp2
    sbc enemy_xhi,x
    bne @col_next
    lda tmp
    cmp #27
    bcs @col_next
    ; 接触! 落下中に上から当たれば踏みつけ
    lda on_ground
    bne @player_die     ; 地上で接触 → やられ
    lda vel_y_hi
    bmi @player_die     ; 上昇中 → やられ
    lda player_y
    cmp #177
    bcs @player_die     ; 深くめり込んでいる → やられ
    lda #180            ; 踏みつけ! 決意マンは行動に倒れた
    jsr kill_enemy
    lda #2              ; 踏みつけ = 200点
    jsr add_score
    lda #0
    sta vel_y_lo
    lda #$FD            ; プレイヤーは -3.0 でバウンド
    sta vel_y_hi
    lda player_y
    sta jump_origin_y
    jmp @col_next
@player_die:
    lda star_timer      ; 無敵中なら触れた決意マンのほうが倒れる
    beq @really_die
    lda #188
    jsr kill_enemy
    jmp @col_next
@really_die:
    jsr player_die_start ; 点滅+ダメージ顔の死亡演出へ
@col_next:
    dex
    bmi @done
    jmp @col_loop
@done:
    rts

; ---- 敵を倒す: A = エフェクト Y, X = 敵スロット ----
; ダメージアニメ (28F: 前半ダメージ顔 → 後半点滅消失) とヒットエフェクトを起動
kill_enemy:
    sta fx_y
    lda #2
    sta enemy_flag,x
    lda #28
    sta enemy_timer,x
    lda #12
    sta fx_timer
    jsr sfx_hit         ; ヒットのノイズ + 撃破ジングル
    jsr sfx_defeat
    lda enemy_xlo,x     ; エフェクトは敵の中央
    clc
    adc #4
    sta fx_xlo
    lda enemy_xhi,x
    adc #0
    sta fx_xhi
    rts

; ---- 敵の横衝突: tmp/tmp2 = 前縁 X。C=1 → 壁 (X レジスタは保存) ----
enemy_probe:
    lda tmp2
    cmp #4
    bcs @wall           ; 世界の右端の外
    txa
    pha
    lda #ENEMY_Y + 8    ; 体の中心の高さで判定
    jsr probe_top
    cmp #$FF
    beq @clear
    pla
    tax
@wall:
    sec
    rts
@clear:
    pla
    tax
    txa                 ; 進む先が穴なら引き返す (決意マンは穴に落ちない)
    pha
    jsr get_feature
    cmp #FEAT_PIT
    beq @pit
    pla
    tax
    clc
    rts
@pit:
    pla
    tax
    sec
    rts

; ---- 決意マンを OAM バッファへ (4枚 x 3体, パレット1) ----
draw_enemies:
    ldx #0              ; スロット
    ldy #ENEMY_OAM      ; OAM オフセット
@loop:
    lda enemy_flag,x
    beq @hide
    cmp #2
    bne @alive_tiles
    lda enemy_timer,x   ; 消失アニメ: 後半 (残り12F以下) は点滅
    cmp #13
    bcs @hurt_tiles
    and #2
    bne @hide
@hurt_tiles:
    lda #$6C            ; ダメージ顔 (X目+口開け)
    bne @set_base       ; 常に分岐
@alive_tiles:
    lda #$68
@set_base:
    sta tmp3
    lda enemy_xlo,x     ; 画面 X (スクロール圏外なら非表示)
    sec
    sbc scroll_lo
    sta tmp
    lda enemy_xhi,x
    sbc scroll_hi
    bne @hide
    lda #ENEMY_Y
    sta OAM_BUF,y       ; 上段 Y
    sta OAM_BUF+4,y
    lda #ENEMY_Y + 8
    sta OAM_BUF+8,y     ; 下段 Y
    sta OAM_BUF+12,y
    lda tmp3
    sta OAM_BUF+1,y
    clc
    adc #1
    sta OAM_BUF+5,y
    adc #1
    sta OAM_BUF+9,y
    adc #1
    sta OAM_BUF+13,y
    lda #ENEMY_ATTR
    sta OAM_BUF+2,y
    sta OAM_BUF+6,y
    sta OAM_BUF+10,y
    sta OAM_BUF+14,y
    lda tmp
    sta OAM_BUF+3,y
    sta OAM_BUF+11,y
    clc
    adc #8
    sta OAM_BUF+7,y
    sta OAM_BUF+15,y
    jmp @next
@hide:
    lda #$FF
    sta OAM_BUF,y
    sta OAM_BUF+4,y
    sta OAM_BUF+8,y
    sta OAM_BUF+12,y
@next:
    tya
    clc
    adc #16
    tay
    inx
    cpx #3
    beq @fx
    jmp @loop
@fx:
    ; ---- ヒットエフェクト (スプライト22 = OAM+88): 小→大の炸裂 ----
    lda fx_timer
    beq @fx_hide
    lda fx_xlo
    sec
    sbc scroll_lo
    sta tmp
    lda fx_xhi
    sbc scroll_hi
    bne @fx_hide
    lda fx_y
    sta OAM_BUF+88
    lda fx_timer
    cmp #7
    bcs @fx_small
    lda #$71            ; 後半: 大バースト
    bne @fx_tile
@fx_small:
    lda #$70            ; 前半: 小スパーク
@fx_tile:
    sta OAM_BUF+89
    lda #ENEMY_ATTR
    sta OAM_BUF+90
    lda tmp
    sta OAM_BUF+91
    rts
@fx_hide:
    lda #$FF
    sta OAM_BUF+88
    rts

; スポーン位置はステージ別テーブル stage_enemy_lo/hi (assets/levels.s) を参照
