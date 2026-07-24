; ゲーム状態: 0=プレイ中 1=ステージクリア 2=死亡演出 3=ゲームオーバー
; ステージ進行 (1-1〜1-4)、HUD (残機/ステージ番号)、状態テキストの描画も担当

STATE_TIME_CLEAR = 240
STATE_TIME_DEATH = 60
STATE_TIME_OVER  = 240
TEXT_OAM = 84           ; スプライト 21-32 (最大12文字)
HUD_OAM  = 132          ; スプライト 33-37 (残機 + ステージ番号)
SCORE_OAM = 152         ; スプライト 38-43 (スコア6桁)
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
    jsr set_chr_bank    ; A=0: ゲーム用 CHR バンク
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

; ---- CNROM の CHR バンク切替 (バス競合回避のためテーブル自身へ書く) ----
set_chr_bank:           ; A = バンク (0=ゲーム 1=タイトル)
    tax
    sta chr_bank_tbl,x
    rts

; ---- タイトル画面: TITLE2.png を変換したフルスクリーン画像 ----
; CHR バンク1 / 画面を上下スプリット (スプライト0ヒットで PT0→PT1 切替) して
; 最大510タイルで描画。メニューはカーソルスプライトで選択
show_title:
    lda #0
    sta PPUCTRL
    sta PPUMASK
    sta nmi_ready
    sta scroll_lo
    sta scroll_hi
    sta menu_sel
    lda #1
    jsr set_chr_bank
    ; パレット: BG は画像から生成した4本, スプライトはカーソル用の白
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #0
:   lda title_img_palette,x
    sta PPUDATA
    inx
    cpx #16
    bne :-
    ldx #0
:   lda title_spr_palette,x
    sta PPUDATA
    inx
    cpx #16
    bne :-
    ; ネームテーブル+属性 1024B を $2000 へ一括転送
    bit PPUSTATUS
    lda #$20
    sta PPUADDR
    lda #$00
    sta PPUADDR
    lda #<title_nt
    sta text_ptr
    lda #>title_nt
    sta text_ptr+1
    ldx #4
@page:
    ldy #0
@byte:
    lda (text_ptr),y
    sta PPUDATA
    iny
    bne @byte
    inc text_ptr+1
    dex
    bne @page
    ; スプライト: 全消し → スプライト0 (スプリット検出用, BG の裏に隠す)
    ldx #0
    lda #$FF
:   sta OAM_BUF,x
    inx
    bne :-
    lda #TITLE_SPR0_Y
    sta OAM_BUF+0
    lda #254            ; ソリッドタイル
    sta OAM_BUF+1
    lda #%00100000      ; 優先度: BG の後ろ
    sta OAM_BUF+2
    lda #TITLE_SPR0_X
    sta OAM_BUF+3
    lda #4
    sta game_state
    lda #%10000000      ; NMI 再開 (上半分は PT0)
    sta PPUCTRL
    lda #%00011110
    sta PPUMASK
    rts

; ---- タイトルの更新: メニュー選択 + 決定 ----
update_title:
    inc frame_count
    ; ↓ でカーソル移動
    lda buttons
    and #BTN_DOWN
    beq :+
    lda prev_buttons
    and #BTN_DOWN
    bne :+
    lda menu_sel
    cmp #2
    bcs :+
    inc menu_sel
:   ; ↑ でカーソル移動
    lda buttons
    and #BTN_UP
    beq :+
    lda prev_buttons
    and #BTN_UP
    bne :+
    lda menu_sel
    beq :+
    dec menu_sel
:   ; カーソル (スプライト1, タイル255 = ▶)
    ldx menu_sel
    lda title_menu_y,x
    sta OAM_BUF+4
    lda #255
    sta OAM_BUF+5
    lda #0
    sta OAM_BUF+6
    lda #44
    sta OAM_BUF+7
    ; START / A で決定
    lda buttons
    and #(BTN_START | BTN_A)
    beq @done
    lda prev_buttons
    and #(BTN_START | BTN_A)
    bne @done
    lda menu_sel
    cmp #2
    beq @done           ; OPTION は未実装 (飾り)
    cmp #1
    beq @go             ; CONTINUE: 前回のステージから
    lda #0              ; START: 1-1 から
    sta current_stage
@go:
    lda #3
    sta lives
    lda #0
    sta score
    sta score+1
    sta score+2
    sta score+3
    sta weapon_level
    sta star_timer
    jmp start_stage
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
    lda #10             ; クリアボーナス 1000点
    jsr add_score
@no:
    rts

; ---- スコア加算: A = 100点単位の加算量 (0-99) ----
add_score:
    clc
    adc score+3
    sta score+3
    ldx #3
@norm:
    lda score,x
    cmp #10
    bcc @next
    sec
    sbc #10
    sta score,x
    cpx #0
    beq @cap            ; 最上位から桁あふれ → カンスト
    inc score-1,x       ; 上の桁へ繰り上げ
    jmp @norm
@next:
    dex
    bpl @norm
    rts
@cap:
    lda #9              ; 999900 でカンスト
    sta score
    sta score+1
    sta score+2
    sta score+3
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
    ; スコア (中央上 y=24, 4桁 + "00" = 6スプライト)
    ldx #0
    ldy #0
@score_loop:
    lda #24
    sta OAM_BUF+SCORE_OAM,y
    iny
    lda score,x
    clc
    adc #$90            ; '0' のタイル
    sta OAM_BUF+SCORE_OAM,y
    iny
    lda #0
    sta OAM_BUF+SCORE_OAM,y
    iny
    txa
    asl
    asl
    asl
    clc
    adc #96             ; X = 96 + 桁*8
    sta OAM_BUF+SCORE_OAM,y
    iny
    inx
    cpx #4
    bne @score_loop
    lda #24             ; 固定の下2桁 "00"
    sta OAM_BUF+SCORE_OAM+16
    sta OAM_BUF+SCORE_OAM+20
    lda #$90
    sta OAM_BUF+SCORE_OAM+17
    sta OAM_BUF+SCORE_OAM+21
    lda #0
    sta OAM_BUF+SCORE_OAM+18
    sta OAM_BUF+SCORE_OAM+22
    lda #128
    sta OAM_BUF+SCORE_OAM+19
    lda #136
    sta OAM_BUF+SCORE_OAM+23

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
chr_bank_tbl:      .byte 0, 1          ; CNROM バンク書込先 (値=内容でバス競合回避)
title_spr_palette:                     ; カーソル用 (白)
    .byte $0F,$0F,$0F,$30
    .byte $0F,$0F,$0F,$30
    .byte $0F,$0F,$0F,$30
    .byte $0F,$0F,$0F,$30
title_menu_y: .byte 111, 127, 143      ; START / CONTINUE / OPTION のカーソル Y
.segment "CODE"
