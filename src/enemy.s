; 敵: 3種類 (0=歩く決意マン 1=コウモリ 2=ホッパー) 最大3体
; - 歩行: 2フレームに1px、壁と穴で折り返す
; - コウモリ: 毎フレーム1px + サイン波で上下に飛ぶ。穴は越える
; - ホッパー: プレイヤーめがけて放物線ジャンプ
; 矢/踏みつけで撃破。踏みは空中コンボで得点倍増

ENEMY_GROUND = 184      ; 地上系の接地 Y
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
    lda stage_enemy_type,y
    sta enemy_type,x
    lda #ENEMY_GROUND
    sta enemy_ypos,x
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
:   ; ---- 消失アニメ (flag=2) → リスポーン待ち (flag=3) → 再登場 ----
    ldx #2
@dying_loop:
    lda enemy_flag,x
    cmp #2
    bne @chk_respawn
    dec enemy_timer,x
    bne @dying_next
    lda #3              ; 消え終わり → リスポーン待ちへ
    sta enemy_flag,x
    lda #220
    sta enemy_timer,x
    jsr spawn_item      ; アイテムをドロップ
    jmp @dying_next
@chk_respawn:
    cmp #3
    bne @dying_next
    dec enemy_timer,x
    bne @dying_next
    ; 画面右端の先に再登場 (世界の端なら左後方)
    lda scroll_lo
    clc
    adc #16
    sta enemy_xlo,x
    lda scroll_hi
    adc #1              ; scroll + 272
    sta enemy_xhi,x
    cmp #4
    bcc :+
    lda scroll_lo       ; 世界右端を越える → 画面左後方 (scroll-24)
    sec
    sbc #24
    sta enemy_xlo,x
    lda scroll_hi
    sbc #0
    sta enemy_xhi,x
:   lda #ENEMY_GROUND
    sta enemy_ypos,x
    lda #1
    sta enemy_flag,x
    sta enemy_dir,x     ; プレイヤー側 (左) へ
    lda #0
    sta enemy_timer,x
@dying_next:
    dex
    bpl @dying_loop
    ; ---- 移動 (種類別, 生存中のみ) ----
    ldx #2
@move_loop:
    lda enemy_flag,x
    cmp #1
    beq :+
    jmp @move_next
:   lda enemy_type,x
    beq @walker
    cmp #1
    bne :+
    jmp @bat
:   jmp @hopper

@walker:
    lda #ENEMY_GROUND
    sta enemy_ypos,x
    lda frame_count     ; 2フレームに1px
    and #1
    beq :+
    jmp @move_next
:   lda enemy_dir,x
    bne @w_left
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
    bcc @w_done
    lda enemy_xlo,x     ; ぶつかった → 1px 戻して反転
    bne :+
    dec enemy_xhi,x
:   dec enemy_xlo,x
    lda #1
    sta enemy_dir,x
    bne @w_done
@w_left:
    lda enemy_xlo,x
    ora enemy_xhi,x
    beq @w_turn_r       ; 世界の左端
    lda enemy_xlo,x
    bne :+
    dec enemy_xhi,x
:   dec enemy_xlo,x     ; 左へ 1px
    lda enemy_xlo,x     ; 前縁 (x+0)
    sta tmp
    lda enemy_xhi,x
    sta tmp2
    jsr enemy_probe
    bcc @w_done
    inc enemy_xlo,x     ; ぶつかった → 1px 戻して反転
    bne @w_turn_r
    inc enemy_xhi,x
@w_turn_r:
    lda #0
    sta enemy_dir,x
@w_done:
    jmp @move_next

@bat:
    inc enemy_timer,x   ; 位相
    txa                 ; Y = 132 + wave[(timer/2 + slot*11) & 31]
    asl
    asl
    asl
    adc enemy_timer,x   ; slot*8 + timer (ラフな位相ずらし)
    lsr
    and #31
    tay
    lda bat_wave,y
    clc
    adc #132
    sta enemy_ypos,x
    lda enemy_dir,x     ; 毎フレーム 1px (歩行の2倍速)
    bne @b_left
    inc enemy_xlo,x
    bne :+
    inc enemy_xhi,x
:   lda enemy_xlo,x     ; 前縁で壁チェック (飛行高度)
    clc
    adc #15
    sta tmp
    lda enemy_xhi,x
    adc #0
    sta tmp2
    jsr enemy_probe_wall
    bcc @b_done
    lda #1
    sta enemy_dir,x
    bne @b_done
@b_left:
    lda enemy_xlo,x
    ora enemy_xhi,x
    beq @b_turn_r
    lda enemy_xlo,x
    bne :+
    dec enemy_xhi,x
:   dec enemy_xlo,x
    lda enemy_xlo,x
    sta tmp
    lda enemy_xhi,x
    sta tmp2
    jsr enemy_probe_wall
    bcc @b_done
@b_turn_r:
    lda #0
    sta enemy_dir,x
@b_done:
    jmp @move_next

@hopper:
    inc enemy_timer,x
    lda enemy_timer,x
    and #63
    sta enemy_timer,x
    bne :+
    ; 跳び始め: プレイヤーの方を向く
    lda world_x_lo
    cmp enemy_xlo,x
    lda world_x_hi
    sbc enemy_xhi,x
    bcs @h_face_r
    lda #1
    sta enemy_dir,x
    bne :+
@h_face_r:
    lda #0
    sta enemy_dir,x
:   ldy enemy_timer,x   ; Y = 接地 - 跳躍アーク
    lda #ENEMY_GROUND
    sec
    sbc hop_arc,y
    sta enemy_ypos,x
    lda hop_arc,y       ; 空中のみ横移動 (1px)
    beq @h_done
    lda enemy_dir,x
    bne @h_left
    inc enemy_xlo,x
    bne :+
    inc enemy_xhi,x
:   lda enemy_xlo,x
    clc
    adc #15
    sta tmp
    lda enemy_xhi,x
    adc #0
    sta tmp2
    jsr enemy_probe_wall
    bcc @h_done
    lda #1
    sta enemy_dir,x
    bne @h_done
@h_left:
    lda enemy_xlo,x
    ora enemy_xhi,x
    beq @h_turn_r
    lda enemy_xlo,x
    bne :+
    dec enemy_xhi,x
:   dec enemy_xlo,x
    lda enemy_xlo,x
    sta tmp
    lda enemy_xhi,x
    sta tmp2
    jsr enemy_probe_wall
    bcc @h_done
@h_turn_r:
    lda #0
    sta enemy_dir,x
@h_done:
@move_next:
    dex
    bmi @collisions
    jmp @move_loop

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
    lda arrow_y,y       ; 縦: 矢の中心が敵の高さ帯にあるか (+8 バイアスで上下に寛容)
    clc
    adc #8
    sec
    sbc enemy_ypos,x
    cmp #22
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
:   lda enemy_ypos,x
    clc
    adc #4
    jsr kill_enemy
    lda #1              ; 矢で撃破 = 100点
    jsr add_score
    jmp @col_next
@arrow_next:
    iny
    cpy #2
    bne @arrow_chk
    ; --- プレイヤー接触 (d = 足元 - 敵上端 が 1..47 で重なり) ---
    lda player_y
    clc
    adc #32
    sec
    sbc enemy_ypos,x
    beq @col_next
    bcc @col_next
    cmp #48
    bcs @col_next
    sta tmp3            ; めり込み深さ
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
    ; 接触! 落下中に浅く当たれば踏みつけ
    lda on_ground
    bne @player_die     ; 地上で接触 → やられ
    lda vel_y_hi
    bmi @player_die     ; 上昇中 → やられ
    lda tmp3
    cmp #14
    bcs @player_die     ; 深くめり込んでいる → やられ
    inc stomp_chain     ; 踏みつけ! 空中コンボで倍々
    lda enemy_ypos,x
    sec
    sbc #4
    jsr kill_enemy
    lda stomp_chain     ; 200,400,800,1600,3200点...
    cmp #5
    bcc :+
    lda #5
:   tay
    lda #1
@chain_shift:
    asl
    dey
    bne @chain_shift
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
    lda enemy_ypos,x
    clc
    adc #4
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
; ダメージアニメ + ヒットエフェクト + ヒットストップ + 画面フラッシュ
kill_enemy:
    sta fx_y
    lda #2
    sta enemy_flag,x
    lda #28
    sta enemy_timer,x
    lda #12
    sta fx_timer
    lda #3              ; 撃破の手応え: 3F 世界停止
    sta hitstop
    lda #2
    sta kill_flash      ; BG 色フラッシュ
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

; ---- 敵の横衝突: tmp/tmp2 = 前縁 X, probe_res = 判定 Y。C=1 → 壁 ----
; enemy_probe は穴でも C=1 (歩行系用)。enemy_probe_wall は壁のみ
enemy_probe:
    lda #ENEMY_GROUND + 8
    sta probe_res
    jsr enemy_probe_wall
    bcs @wall
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
@wall:
    sec
    rts

enemy_probe_wall:
    lda tmp2
    cmp #4
    bcs @wall2          ; 世界の右端の外
    txa
    pha
    lda enemy_ypos,x
    clc
    adc #8              ; 体の中心の高さで判定
    jsr probe_top
    cmp #$FF
    beq @clear2
    pla
    tax
@wall2:
    sec
    rts
@clear2:
    pla
    tax
    clc
    rts

; ---- 敵を OAM バッファへ (4枚 x 3体, パレット1) ----
draw_enemies:
    ldx #0              ; スロット
    ldy #ENEMY_OAM      ; OAM オフセット
@loop:
    lda enemy_flag,x
    bne :+
    jmp @hide
:   cmp #3
    bne :+
    jmp @hide
:   cmp #2
    bne @alive_tiles
    lda enemy_timer,x   ; 消失アニメ: 後半 (残り12F以下) は点滅
    cmp #13
    bcs @hurt_tiles
    and #2
    bne @hide
@hurt_tiles:
    lda enemy_type,x    ; ダメージ顔は歩行型のみ (他は点滅で表現)
    bne @alive_tiles
    lda #$6C            ; ダメージ顔 (X目+口開け)
    bne @set_base       ; 常に分岐
@alive_tiles:
    lda enemy_type,x
    cmp #1
    bne @ket_base
    lda frame_count     ; コウモリ: 8Fごとに羽ばたき
    and #%00001000
    beq :+
    lda #$7A
    bne @set_base
:   lda #$76
    bne @set_base
@ket_base:
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
    lda enemy_ypos,x
    sta OAM_BUF,y       ; 上段 Y
    sta OAM_BUF+4,y
    clc
    adc #8
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

.segment "RODATA"
bat_wave: .byte 20,23,27,31,34,36,38,39,40,39,38,36,34,31,27,23,20,16,12,8,5,3,1,0,0,0,1,3,5,8,12,16
hop_arc:  .byte 0,2,4,6,8,10,12,13,15,17,18,19,20,22,23,24,24,25,26,26,27,27,27,27,27,27,27,27,27,26,26,25,24,24,23,22,20,19,18,17,15,13,12,10,8,6,4,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
.segment "CODE"

; スポーン位置/種類はステージ別テーブル (assets/levels.s) を参照
