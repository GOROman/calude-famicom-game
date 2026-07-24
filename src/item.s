; アイテム: 決意マンを倒すとドロップ (スロットごとに種類が決まっている)
;   1 = 無敵の星   … 約8.5秒無敵。触れた決意マンが逆に倒れる。プレイヤーは点滅
;   2 = パワー矢   … 矢が速くなり (4→6px/f) 敵を貫通する。やられると失う

ITEM_OAM = 76           ; スプライト 19,20

.segment "CODE"

; ---- ドロップ: X = 敵スロット (消失アニメ完了時に呼ばれる) ----
spawn_item:
    ldy #0              ; 空きアイテムスロットを探す
    lda item_flag
    beq @slot_ok
    ldy #1
    lda item_flag+1
    bne @no_slot
@slot_ok:
    lda drop_table,x
    sta item_flag,y
    lda enemy_xlo,x     ; 敵の中央にドロップ
    clc
    adc #4
    sta item_xlo,y
    lda enemy_xhi,x
    adc #0
    sta item_xhi,y
    lda #192            ; 地面の上に置く
    sta item_y,y
@no_slot:
    rts

update_items:
    ; ---- 無敵タイマー (2フレームに1減) ----
    lda star_timer
    beq @pickup
    lda frame_count
    and #1
    bne @pickup
    dec star_timer
@pickup:
    ; ---- 取得判定 ----
    ldx #1
@loop:
    lda item_flag,x
    beq @next
    lda player_y        ; 縦: py+16 > iy かつ py < iy+8
    clc
    adc #16
    cmp item_y,x
    bcc @next
    beq @next
    lda item_y,x
    clc
    adc #8
    cmp player_y
    bcc @next
    beq @next
    lda world_x_lo      ; 横: (px+15) - ix が 0..22
    clc
    adc #15
    sta tmp
    lda world_x_hi
    adc #0
    sta tmp2
    lda tmp
    sec
    sbc item_xlo,x
    sta tmp
    lda tmp2
    sbc item_xhi,x
    bne @next
    lda tmp
    cmp #23
    bcs @next
    ; ---- 取得! ----
    lda item_xlo,x      ; キラキラ (ヒットエフェクト流用)
    sta fx_xlo
    lda item_xhi,x
    sta fx_xhi
    lda item_y,x
    sta fx_y
    lda #12
    sta fx_timer
    lda item_flag,x
    cmp #2
    beq @power
    lda #$FF            ; 無敵の星
    sta star_timer
    bne @took           ; 常に分岐
@power:
    lda #1              ; パワー矢
    sta weapon_level
@took:
    lda #0
    sta item_flag,x
    lda #5              ; アイテム取得 = 500点
    jsr add_score
@next:
    dex
    bpl @loop
    rts

; ---- アイテムを OAM バッファへ (スプライト 19,20) ----
draw_items:
    ldx #1
    ldy #ITEM_OAM + 4
@loop:
    lda item_flag,x
    beq @hide
    lda item_xlo,x      ; 画面 X (圏外なら非表示)
    sec
    sbc scroll_lo
    sta tmp
    lda item_xhi,x
    sbc scroll_hi
    bne @hide
    lda item_y,x
    sta OAM_BUF,y
    lda item_flag,x
    cmp #2
    beq @power_tile
    lda #$5E            ; 星 (パレット1 = 黄/白)
    sta OAM_BUF+1,y
    lda #1
    bne @attr
@power_tile:
    lda #$5F            ; パワー矢 (パレット0)
    sta OAM_BUF+1,y
    lda #0
@attr:
    sta OAM_BUF+2,y
    lda tmp
    sta OAM_BUF+3,y
    jmp @next
@hide:
    lda #$FF
    sta OAM_BUF,y
@next:
    dey
    dey
    dey
    dey
    dex
    bpl @loop
    rts

.segment "RODATA"
drop_table: .byte 1, 2, 1   ; 敵スロット → ドロップ (星, パワー矢, 星)
.segment "CODE"
