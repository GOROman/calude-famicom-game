; ゲーム状態: 0=プレイ中 1=ステージクリア 2=死亡演出 3=ゲームオーバー
; ステージ進行 (1-1〜1-4)、HUD (残機/ステージ番号)、状態テキストの描画も担当

STATE_TIME_CLEAR = 240
STATE_TIME_DEATH = 60
STATE_TIME_OVER  = 240
TEXT_OAM = 100          ; スプライト 25-36 (最大12文字)
HUD_OAM  = 148          ; スプライト 37-41 (残機 + ステージ番号)
SCORE_OAM = 168         ; スプライト 42-47 (スコア6桁)
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
    ; coin_ptr = coin_maps + current_stage * 8, 取得フラグをクリア
    lda current_stage
    asl
    asl
    asl
    clc
    adc #<coin_maps
    sta coin_ptr
    lda #>coin_maps
    adc #0
    sta coin_ptr+1
    ldx #7
    lda #0
:   sta coin_taken,x
    dex
    bpl :-
    lda #15             ; ゲーム中はフェードなし (全音量)
    sta snd_fade
    jsr ppu_init        ; パレット + ネームテーブルクリア
    jsr level_init      ; 最初の2画面分を描画
    jsr player_init
    jsr enemy_init
    jsr boss_init       ; 1-4 ならボス出現
    lda #0
    sta scroll_lo
    sta scroll_hi
    sta arrow_flag
    sta arrow_flag+1
    sta item_flag
    sta item_flag+1
    sta fx_timer
    ; ---- スーパーマリオ風ラウンド表示 (黒画面 + STAGE 1-N + 残機) ----
    lda #6
    sta game_state
    lda #120            ; 2秒
    sta state_timer
    jsr draw_round
    lda #%10000000      ; NMI 再開
    sta PPUCTRL
    lda #%00010110      ; スプライトのみ (BG 非表示 = 黒)
    sta PPUMASK
    rts

; ---- ラウンド表示のスプライトを OAM へ (state 6 の間は他に描画なし) ----
draw_round:
    ldx #0              ; OAM 全消し
    lda #$FF
:   sta OAM_BUF,x
    inx
    bne :-
    ldx #0              ; 文字インデックス
    ldy #0              ; OAM オフセット
@text:                  ; 1行目 "STAGE" (y=88, 5枚)
    lda round_text,x
    beq @line2
    sta OAM_BUF+1,y     ; タイル
    lda #88
    sta OAM_BUF,y       ; Y
    lda #0
    sta OAM_BUF+2,y     ; 属性
    txa                 ; X = 108 + i*8
    asl
    asl
    asl
    clc
    adc #108
    sta OAM_BUF+3,y
    iny
    iny
    iny
    iny
    inx
    bne @text           ; 常に分岐
@line2:                 ; 2行目 "1-N" (y=104, 3枚, スキャンライン8枚制限を回避)
    lda #104
    sta OAM_BUF,y
    sta OAM_BUF+4,y
    sta OAM_BUF+8,y
    lda #$91            ; '1'
    sta OAM_BUF+1,y
    lda #$8D            ; '-'
    sta OAM_BUF+5,y
    lda current_stage
    clc
    adc #$91            ; '1'〜'4'
    sta OAM_BUF+9,y
    lda #0
    sta OAM_BUF+2,y
    sta OAM_BUF+6,y
    sta OAM_BUF+10,y
    lda #116
    sta OAM_BUF+3,y
    lda #124
    sta OAM_BUF+7,y
    lda #132
    sta OAM_BUF+11,y
    tya
    clc
    adc #12
    tay
@icon:
    ; 顔アイコン x 残機 (y=118)
    lda #118
    sta OAM_BUF,y
    iny
    lda #$03            ; 顔タイル
    sta OAM_BUF,y
    iny
    lda #0
    sta OAM_BUF,y
    iny
    lda #108
    sta OAM_BUF,y
    iny
    lda #119
    sta OAM_BUF,y
    iny
    lda #$B8            ; 'X'
    sta OAM_BUF,y
    iny
    lda #0
    sta OAM_BUF,y
    iny
    lda #120
    sta OAM_BUF,y
    iny
    lda #119
    sta OAM_BUF,y
    iny
    lda lives
    clc
    adc #$90            ; 残機の数字
    sta OAM_BUF,y
    iny
    lda #0
    sta OAM_BUF,y
    iny
    lda #132
    sta OAM_BUF,y
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
    sta snd_fade        ; BGM フェードイン開始
    sta blink_phase
    sta blink_again
    sta title_exit
    sta fade_amt
    lda #90
    sta blink_timer
    lda #$A5            ; LFSR シード
    sta rng
    lda #$70            ; パレットフェードインから開始
    sta fade_amt
    lda #0
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
    bit PPUSTATUS       ; スプライトパレット1/2 = 目パチ用 (肌/茶/白, 肌/茶/黒)
    lda #$3F
    sta PPUADDR
    lda #$15
    sta PPUADDR
    ldx #0
:   lda title_eye_pal,x
    sta PPUDATA
    inx
    cpx #7
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

; ---- エンディング画面: 1-4 クリアで到達 ----
show_ending:
    lda #0
    sta PPUCTRL
    sta PPUMASK
    sta nmi_ready
    sta scroll_lo
    sta scroll_hi
    jsr set_chr_bank    ; A=0: フォントのあるゲームバンク
    lda #15
    sta snd_fade
    jsr ppu_init        ; ネームテーブルクリア
    bit PPUSTATUS       ; 黒背景 + 白/赤文字のパレット
    lda #$3F
    sta PPUADDR
    lda #$00
    sta PPUADDR
    ldx #0
:   lda ending_palette,x
    sta PPUDATA
    inx
    cpx #16
    bne :-
    ; テキスト行を書く
    ldx #0
@lines:
    lda ending_lines,x      ; PPU アドレス hi
    beq @lines_done
    pha
    inx
    lda ending_lines,x      ; lo
    pha
    inx
    lda ending_lines,x      ; テキストポインタ lo
    sta text_ptr
    inx
    lda ending_lines,x      ; hi
    sta text_ptr+1
    inx
    pla
    tay
    pla
    jsr write_bg_text
    jmp @lines
@lines_done:
    ldx #0                  ; スプライト全消し
    lda #$FF
:   sta OAM_BUF,x
    inx
    bne :-
    lda #5
    sta game_state
    lda #%10000000
    sta PPUCTRL
    lda #%00011110
    sta PPUMASK
    rts

; ---- BG に 0 終端のタイル列を書く: A=PPUアドレス上位, Y=下位 ----
write_bg_text:
    bit PPUSTATUS
    sta PPUADDR
    sty PPUADDR
    ldy #0
:   lda (text_ptr),y
    beq :+
    sta PPUDATA
    iny
    bne :-
:   rts

; ---- エンディングの更新: START でタイトルへ ----
update_ending:
    inc frame_count
    lda buttons
    and #BTN_START
    beq @done
    lda prev_buttons
    and #BTN_START
    bne @done
    jmp show_title
@done:
    rts

; ---- タイトルの更新: メニュー選択 + 決定 ----
update_title:
    inc frame_count
    ; ---- 8bit LFSR (目パチのランダム化) ----
    lda rng
    asl
    bcc :+
    eor #$1D
:   sta rng
    ; ---- 退場演出中: ウィンク → パレットフェード → 遷移 ----
    lda title_exit
    beq @no_exit
    inc title_exit
    lda title_exit
    cmp #30
    bcc @exit_draw      ; まずウィンクだけ (30F)
    sec                 ; 以降 8F ごとに 1 段暗く
    sbc #30
    lsr
    lsr
    lsr
    clc
    adc #1
    asl
    asl
    asl
    asl
    sta fade_amt
    lda title_exit
    cmp #110            ; ウィンク30F + フェード80F で遷移
    bcc @exit_draw
    jmp @go_selected
@exit_draw:
    jmp @draw_eyes
@no_exit:
    lda fade_amt        ; タイトル表示フェードイン (8Fごとに1段明るく)
    beq @fadein_done
    lda frame_count
    and #7
    bne @fadein_done
    lda fade_amt
    sec
    sbc #$10
    sta fade_amt
@fadein_done:
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
    ; ---- 目パチ FSM: 開→半目→閉→半目→開。間隔ランダム + 時々2連 ----
    dec blink_timer
    bne @draw_eyes
    lda blink_phase
    bne :+
    lda #1              ; 開→半目 (閉じ際)
    sta blink_phase
    lda #3
    sta blink_timer
    lda rng             ; 2連目パチの抽選 (約1/4)
    and #7
    cmp #2
    bcs @draw_eyes
    lda #1
    sta blink_again
    bne @draw_eyes
:   cmp #1
    bne :+
    lda #2              ; 半目→閉
    sta blink_phase
    lda #7
    sta blink_timer
    bne @draw_eyes
:   cmp #2
    bne :+
    lda #3              ; 閉→半目 (開き際)
    sta blink_phase
    lda #3
    sta blink_timer
    bne @draw_eyes
:   lda #0              ; 半目→開
    sta blink_phase
    lda blink_again
    beq @rand_wait
    lda #0
    sta blink_again
    lda #14             ; 2連目パチ: 少し置いてもう一度
    sta blink_timer
    bne @draw_eyes
@rand_wait:
    lda rng             ; 次の目パチまで 80〜207F のランダム
    and #127
    clc
    adc #80
    sta blink_timer
@draw_eyes:
    ldx #0              ; まず目スプライト枠 (16枚) を全部隠す
    lda #$FF
:   sta OAM_BUF+8,x
    inx
    inx
    inx
    inx
    cpx #64
    bne :-
    lda fade_amt        ; フェード中 (イン/アウト共) はカーソルも目も非表示
    beq :+
    lda #$FF
    sta OAM_BUF+4
    bne @eyes_done      ; 常に分岐
:   lda title_exit      ; 退場演出: ウィンク (手前の目だけ閉じ)
    beq @by_phase
    ldx #0
:   lda title_eye_spr,x
    sta OAM_BUF+8,x
    inx
    cpx #(TITLE_EYE_NEAR*4)
    bne :-
    ; カーソルも消す (ウィンクの主役を立てる)
    lda #$FF
    sta OAM_BUF+4
    bne @eyes_done
@by_phase:
    lda blink_phase
    beq @eyes_open
    cmp #2
    beq @eyes_closed
    ldx #0              ; 半目
:   lda title_eye_half,x
    sta OAM_BUF+8,x
    inx
    cpx #(TITLE_EYE_HN*4)
    bne :-
    beq @eyes_done
@eyes_closed:
    ldx #0
:   lda title_eye_spr,x
    sta OAM_BUF+8,x
    inx
    cpx #(TITLE_EYE_N*4)
    bne :-
    beq @eyes_done
@eyes_open:
    ldx #0              ; 白目 (開き目のとき常時表示)
:   lda title_eye_open,x
    sta OAM_BUF+8,x
    inx
    cpx #(TITLE_EYE_ON*4)
    bne :-
@eyes_done:
    ; START / A で決定 → ウィンク+フェードの退場演出を開始
    lda buttons
    and #(BTN_START | BTN_A)
    beq @done
    lda prev_buttons
    and #(BTN_START | BTN_A)
    bne @done
    lda menu_sel
    cmp #2
    beq @done           ; OPTION は未実装 (飾り)
    lda #1
    sta title_exit
    jsr sfx_start       ; 開始ジングル (BGM は update_sound 側で停止)
    rts

@go_selected:
    lda menu_sel
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
    sta coin_ones
    sta coin_tens
    jmp start_stage
@done:
    rts

; ---- 一番右 (WORLD_X_MAX) まで行ったらステージクリア! ----
; ただしボス決意マンが生きている間はクリアできない
check_clear:
    lda boss_state
    cmp #1
    beq @no
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
    cmp #6
    beq @round_go
    cmp #2
    beq @respawn
    cmp #3
    beq @to_reset
    ; クリア → 次のステージへ。1-4 をクリアしたらエンディング!
    inc current_stage
    lda current_stage
    cmp #NUM_STAGES
    bcc :+
    lda #0
    sta current_stage
    jmp show_ending
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
    lda #0              ; ゲームオーバージングルの頭出し
    sta snd_tick
    rts
@to_reset:
    jmp reset
@round_go:
    lda #0              ; ラウンド表示終了 → プレイ開始
    sta game_state
    lda #%00011110      ; BG + スプライト表示
    sta PPUMASK
    rts

; ---- HUD: 残機 + ステージ番号 + 状態テキスト ----
draw_hud:
    ; 残機 (左上: 狩人アイコン + 数字)
    lda #15
    sta OAM_BUF+HUD_OAM
    sta OAM_BUF+HUD_OAM+4
    sta OAM_BUF+HUD_OAM+8
    sta OAM_BUF+HUD_OAM+12
    sta OAM_BUF+HUD_OAM+16
    lda #$03            ; 狩人の顔タイル (頭の右下)
    sta OAM_BUF+HUD_OAM+1
    lda lives
    clc
    adc #$90            ; '0' のタイル ($80 + $30-$20)
    sta OAM_BUF+HUD_OAM+5
    ; コイン (右上: アイコン + 2桁。ステージ番号はラウンド画面で表示)
    lda #$75            ; コインアイコン
    sta OAM_BUF+HUD_OAM+9
    lda coin_tens
    clc
    adc #$90
    sta OAM_BUF+HUD_OAM+13
    lda coin_ones
    clc
    adc #$90
    sta OAM_BUF+HUD_OAM+17
    lda #0
    sta OAM_BUF+HUD_OAM+2
    sta OAM_BUF+HUD_OAM+6
    sta OAM_BUF+HUD_OAM+14
    sta OAM_BUF+HUD_OAM+18
    lda #1              ; コインアイコンは金色 (パレット1)
    sta OAM_BUF+HUD_OAM+10
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
title_menu_y: .byte 122, 136, 150      ; START / CONTINUE / OPTION のカーソル Y
round_text:   .byte $B3,$B4,$A1,$A7,$A5,0  ; "STAGE"
ending_palette:
    .byte $0F,$0F,$16,$30
    .byte $0F,$0F,$16,$30
    .byte $0F,$0F,$16,$30
    .byte $0F,$0F,$16,$30
; エンディング行テーブル: PPUアドレス hi, lo, テキストポインタ lo, hi。終端 0
ending_lines:
    .byte $21,$08, <end_txt1, >end_txt1   ; 行8  col8:  CONGRATULATIONS!
    .byte $21,$85, <end_txt2, >end_txt2   ; 行12 col5:  ALL KETSUIMAN DEFEATED
    .byte $21,$C9, <end_txt3, >end_txt3   ; 行14 col9:  BY YOUR ACTION
    .byte $22,$8A, <end_txt4, >end_txt4   ; 行20 col10: PRESENTED BY
    .byte $22,$C7, <end_txt5, >end_txt5   ; 行22 col7:  GOROMAN AND CLAUDE
    .byte $23,$4C, <end_txt6, >end_txt6   ; 行26 col12: THE END
    .byte 0
; ASCII → タイル ($80 + c - $20)
end_txt1: .byte $A3,$AF,$AE,$A7,$B2,$A1,$B4,$B5,$AC,$A1,$B4,$A9,$AF,$AE,$B3,$81,0
end_txt2: .byte $A1,$AC,$AC,$80,$AB,$A5,$B4,$B3,$B5,$A9,$AD,$A1,$AE,$80,$A4,$A5,$A6,$A5,$A1,$B4,$A5,$A4,0
end_txt3: .byte $A2,$B9,$80,$B9,$AF,$B5,$B2,$80,$A1,$A3,$B4,$A9,$AF,$AE,0
end_txt4: .byte $B0,$B2,$A5,$B3,$A5,$AE,$B4,$A5,$A4,$80,$A2,$B9,0
end_txt5: .byte $A7,$AF,$B2,$AF,$AD,$A1,$AE,$80,$A1,$AE,$A4,$80,$A3,$AC,$A1,$B5,$A4,$A5,0
end_txt6: .byte $B4,$A8,$A5,$80,$A5,$AE,$A4,0
.segment "CODE"
