; ゲーム状態: 0=プレイ中 1=ステージクリア 2=死亡演出 3=ゲームオーバー
; ステージ進行 (1-1〜1-4)、HUD (残機/ステージ番号)、状態テキストの描画も担当

STATE_TIME_CLEAR = 240
STATE_TIME_DEATH = 60
STATE_TIME_OVER  = 240
TEXT_OAM = 84           ; スプライト 21-32 (最大12文字)
HUD_OAM  = 132          ; スプライト 33-37 (残機 + ステージ番号)
NUM_STAGES = 4

.segment "CODE"

; ---- ステージ開始: レベル/プレイヤー/敵を初期化して描画を再開 ----
; 死亡リスポーンもここを通る (ネームテーブルを描き直さないと
; 死んだ地点の背景がリングに残り、見た目と当たり判定がズレるバグになる)
start_stage:
    lda #0              ; NMI と描画を止めて安全に再構築
    sta PPUCTRL
    sta PPUMASK
    sta nmi_ready
    ; level_ptr = level_maps + current_stage * 64
    lda #<level_maps
    sta level_ptr
    lda #>level_maps
    sta level_ptr+1
    ldx current_stage
    beq @ptr_done
@ptr_loop:
    lda level_ptr
    clc
    adc #64
    sta level_ptr
    bcc :+
    inc level_ptr+1
:   dex
    bne @ptr_loop
@ptr_done:
    jsr ppu_init        ; パレット + ネームテーブルクリア
    jsr level_init      ; 最初の2画面分を描画
    jsr player_init
    jsr enemy_init
    lda #0
    sta game_state
    sta scroll_lo
    sta scroll_hi
    sta arrow_flag
    sta arrow_flag+1
    sta item_flag
    sta item_flag+1
    sta fx_timer
    lda #%10000000      ; NMI 再開
    sta PPUCTRL
    lda #%00011110      ; BG + スプライト表示
    sta PPUMASK
    rts

; ---- タイトル画面: 黒背景に「狩人行動」ロゴと PUSH START ----
show_title:
    lda #0
    sta PPUCTRL
    sta PPUMASK
    sta nmi_ready
    sta scroll_lo
    sta scroll_hi
    jsr ppu_init        ; ネームテーブルクリア
    ; タイトル用 BG パレット (黒背景, 赤ロゴ, 白文字)
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #0
:   lda title_palette,x
    sta PPUDATA
    inx
    cpx #16
    bne :-
    ; ロゴ「狩人行動」 (タイル $C0-$CF, 2x2 ずつ) を行8-9 中央へ
    lda #$21
    ldx #$0C            ; $210C = 行8 列12
    jsr set_title_ptr_logo_top
    jsr write_bg_row
    lda #$21
    ldx #$2C            ; 行9
    jsr set_title_ptr_logo_bot
    jsr write_bg_row
    ; サブタイトルとコピーライト
    lda #$21
    ldx #$8A            ; 行12 列10
    jsr set_title_ptr_sub
    jsr write_bg_row
    lda #$23
    ldx #$48            ; 行26 列8
    jsr set_title_ptr_copy
    jsr write_bg_row
    ; スプライト全消し
    ldx #0
    lda #$FF
:   sta OAM_BUF,x
    inx
    bne :-
    lda #4
    sta game_state
    lda #%10000000      ; NMI 再開
    sta PPUCTRL
    lda #%00011110
    sta PPUMASK
    rts

set_title_ptr_logo_top:
    pha
    lda #<title_logo_top
    sta text_ptr
    lda #>title_logo_top
    sta text_ptr+1
    pla
    rts
set_title_ptr_logo_bot:
    pha
    lda #<title_logo_bot
    sta text_ptr
    lda #>title_logo_bot
    sta text_ptr+1
    pla
    rts
set_title_ptr_sub:
    pha
    lda #<title_sub
    sta text_ptr
    lda #>title_sub
    sta text_ptr+1
    pla
    rts
set_title_ptr_copy:
    pha
    lda #<title_copy
    sta text_ptr
    lda #>title_copy
    sta text_ptr+1
    pla
    rts

; ---- BG に 0 終端のタイル列を書く: A=PPUアドレス上位, X=下位 ----
write_bg_row:
    bit PPUSTATUS
    sta PPUADDR
    stx PPUADDR
    ldy #0
:   lda (text_ptr),y
    beq @end
    sta PPUDATA
    iny
    bne :-
@end:
    rts

; ---- タイトルの更新: PUSH START 点滅 + START でゲーム開始 ----
update_title:
    inc frame_count
    lda frame_count
    and #32             ; 32フレーム周期で点滅
    bne @hide_push
    lda #<title_push_txt
    sta text_ptr
    lda #>title_push_txt
    sta text_ptr+1
    jsr draw_text
    jmp @check_start
@hide_push:
    ldx #0
    lda #$FF
:   sta OAM_BUF+TEXT_OAM,x
    inx
    inx
    inx
    inx
    cpx #48
    bcc :-
@check_start:
    lda buttons
    and #BTN_START
    beq @done
    lda prev_buttons
    and #BTN_START
    bne @done
    jmp start_stage     ; ゲーム開始!
@done:
    rts

; ---- 一番右 (WORLD_X_MAX) まで行ったらステージクリア! ----
check_clear:
    lda world_x_hi
    cmp #>WORLD_X_MAX
    bcc @no
    lda world_x_lo
    cmp #<WORLD_X_MAX
    bcc @no
    lda #1
    sta game_state
    lda #STATE_TIME_CLEAR
    sta state_timer
    lda #0              ; ファンファーレを頭から
    sta snd_tick
    sta snd_step
@no:
    rts

; ---- 死亡演出の開始 (敵接触・穴落下から呼ばれる) ----
player_die_start:
    lda #2
    sta game_state
    lda #STATE_TIME_DEATH
    sta state_timer
    lda #0              ; 飛んでいる矢は消す
    sta arrow_flag
    sta arrow_flag+1
    jsr sfx_miss
    rts

; ---- 演出の進行 ----
update_state:
    inc frame_count     ; 点滅用 (プレイ中は update_enemies が回している)
    dec state_timer
    beq @expired
    rts
@expired:
    lda game_state
    cmp #2
    beq @respawn
    cmp #3
    beq @to_reset
    ; クリア → 次のステージへ (1-4 の次は 1-1 に周回)
    inc current_stage
    lda current_stage
    cmp #NUM_STAGES
    bcc :+
    lda #0
    sta current_stage
:   jmp start_stage
@respawn:
    dec lives
    beq @game_over
    lda #0              ; やられるとパワー矢と無敵は失う
    sta weapon_level
    sta star_timer
    jmp start_stage     ; ステージを最初から (背景もリセット = 判定ズレ防止)
@game_over:
    lda #3
    sta game_state
    lda #STATE_TIME_OVER
    sta state_timer
    rts
@to_reset:
    jmp reset

; ---- HUD: 残機 + ステージ番号 + 状態テキスト ----
draw_hud:
    ; 残機 (左上: 狩人アイコン + 数字)
    lda #15
    sta OAM_BUF+HUD_OAM
    sta OAM_BUF+HUD_OAM+4
    sta OAM_BUF+HUD_OAM+8
    sta OAM_BUF+HUD_OAM+12
    sta OAM_BUF+HUD_OAM+16
    lda #$01            ; 狩人の頭タイル
    sta OAM_BUF+HUD_OAM+1
    lda lives
    clc
    adc #$90            ; '0' のタイル ($80 + $30-$20)
    sta OAM_BUF+HUD_OAM+5
    ; ステージ番号 (右上: "1-N")
    lda #$91            ; '1'
    sta OAM_BUF+HUD_OAM+9
    lda #$8D            ; '-'
    sta OAM_BUF+HUD_OAM+13
    lda current_stage
    clc
    adc #$91            ; '1'〜'4'
    sta OAM_BUF+HUD_OAM+17
    lda #0
    sta OAM_BUF+HUD_OAM+2
    sta OAM_BUF+HUD_OAM+6
    sta OAM_BUF+HUD_OAM+10
    sta OAM_BUF+HUD_OAM+14
    sta OAM_BUF+HUD_OAM+18
    lda #8
    sta OAM_BUF+HUD_OAM+3
    lda #18
    sta OAM_BUF+HUD_OAM+7
    lda #216
    sta OAM_BUF+HUD_OAM+11
    lda #224
    sta OAM_BUF+HUD_OAM+15
    lda #232
    sta OAM_BUF+HUD_OAM+19

    ; 状態テキスト
    lda game_state
    cmp #1
    beq @clear_text
    cmp #3
    beq @over_text
    ldx #0              ; 非表示 (12スプライト分)
    lda #$FF
:   sta OAM_BUF+TEXT_OAM,x
    inx
    inx
    inx
    inx
    cpx #48
    bcc :-
    rts
@clear_text:
    lda #<clear_txt
    sta text_ptr
    lda #>clear_txt
    sta text_ptr+1
    jmp draw_text
@over_text:
    lda #<gameover_txt
    sta text_ptr
    lda #>gameover_txt
    sta text_ptr+1
; ---- テキスト描画: (text_ptr) = y,tile,x の3バイト組, 終端 y=0 ----
draw_text:
    ldy #0              ; テーブル位置
    ldx #0              ; OAM 相対位置
@loop:
    lda (text_ptr),y
    beq @fill_rest
    sta OAM_BUF+TEXT_OAM,x  ; Y
    iny
    inx
    lda (text_ptr),y
    sta OAM_BUF+TEXT_OAM,x  ; タイル
    iny
    inx
    lda #1                  ; パレット1 (白)
    sta OAM_BUF+TEXT_OAM,x
    inx
    lda (text_ptr),y
    sta OAM_BUF+TEXT_OAM,x  ; X
    iny
    inx
    cpx #48
    bcc @loop
    rts
@fill_rest:
    lda #$FF
:   cpx #48
    bcs :+
    sta OAM_BUF+TEXT_OAM,x
    inx
    inx
    inx
    inx
    bne :-
:   rts

.segment "RODATA"
; ASCII フォントタイル = $80 + (文字コード - $20)
clear_txt:                              ; STAGE CLEAR! (2行組)
    .byte 92,$B3,108, 92,$B4,116, 92,$A1,124, 92,$A7,132, 92,$A5,140
    .byte 106,$A3,104, 106,$AC,112, 106,$A5,120, 106,$A1,128, 106,$B2,136, 106,$81,144
    .byte 0
gameover_txt:                           ; GAMEOVER (1行, 8スプライト制限内)
    .byte 100,$A7,96, 100,$A1,104, 100,$AD,112, 100,$A5,120
    .byte 100,$AF,128, 100,$B6,136, 100,$A5,144, 100,$B2,152
    .byte 0
; ---- タイトル画面のデータ ----
title_palette:                          ; 黒背景, 色2=赤 (ロゴ), 色3=白 (文字)
    .byte $0F,$0F,$16,$30
    .byte $0F,$0F,$16,$30
    .byte $0F,$0F,$16,$30
    .byte $0F,$0F,$16,$30
title_logo_top:                         ; 狩人行動 (上段タイル)
    .byte $C0,$C1,$C4,$C5,$C8,$C9,$CC,$CD,0
title_logo_bot:                         ; 下段
    .byte $C2,$C3,$C6,$C7,$CA,$CB,$CE,$CF,0
title_sub:                              ; CALUDE KODO
    .byte $A3,$A1,$AC,$B5,$A4,$A5,$80,$AB,$AF,$A4,$AF,0
title_copy:                             ; (C)2026 GOROMAN
    .byte $88,$A3,$89,$92,$90,$92,$96,$80,$A7,$AF,$B2,$AF,$AD,$A1,$AE,0
title_push_txt:                         ; PUSH / START (スプライト点滅)
    .byte 150,$B0,112, 150,$B5,120, 150,$B3,128, 150,$A8,136
    .byte 164,$B3,108, 164,$B4,116, 164,$A1,124, 164,$B2,132, 164,$B4,140
    .byte 0
.segment "CODE"
