; ゲーム状態: 0=プレイ中 1=ステージクリア 2=死亡演出 3=ゲームオーバー
; HUD (残機表示) と状態テキスト (「ステージクリア!」 / GAMEOVER) の描画も担当

STATE_TIME_CLEAR = 240
STATE_TIME_DEATH = 60
STATE_TIME_OVER  = 240
TEXT_OAM = 84           ; スプライト 21-28 (8文字)
HUD_OAM  = 120          ; スプライト 30,31 (残機アイコン+数字)

.segment "CODE"

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
    jmp reset           ; クリア/ゲームオーバー → 最初からやり直し
@respawn:
    dec lives
    beq @game_over
    jsr player_init     ; 残機があればスタート地点から再開
    lda #0
    sta game_state
    sta weapon_level
    sta star_timer
    rts
@game_over:
    lda #3
    sta game_state
    lda #STATE_TIME_OVER
    sta state_timer
    rts

; ---- HUD: 残機 (狩人の頭アイコン + 数字) と状態テキスト ----
draw_hud:
    lda #15             ; 左上に残機表示
    sta OAM_BUF+HUD_OAM
    sta OAM_BUF+HUD_OAM+4
    lda #$01            ; 狩人の頭タイル
    sta OAM_BUF+HUD_OAM+1
    lda lives
    clc
    adc #$90            ; '0' のタイル ($80 + $30-$20)
    sta OAM_BUF+HUD_OAM+5
    lda #0
    sta OAM_BUF+HUD_OAM+2
    sta OAM_BUF+HUD_OAM+6
    lda #8
    sta OAM_BUF+HUD_OAM+3
    lda #18
    sta OAM_BUF+HUD_OAM+7

    ; 状態テキスト
    lda game_state
    cmp #1
    beq @clear_text
    cmp #3
    beq @over_text
    ldx #28             ; 非表示
    lda #$FF
:   sta OAM_BUF+TEXT_OAM,x
    dex
    dex
    dex
    dex
    bpl :-
    rts
@clear_text:
    ldx #0              ; text_tiles の先頭 (ステージクリア!)
    beq @text
@over_text:
    ldx #8              ; GAMEOVER
@text:
    ldy #TEXT_OAM
@tloop:
    lda #100            ; 画面中央あたり
    sta OAM_BUF,y
    iny
    lda text_tiles,x
    sta OAM_BUF,y
    iny
    lda #1              ; パレット1 (白)
    sta OAM_BUF,y
    iny
    txa
    and #7
    asl
    asl
    asl
    clc
    adc #96             ; X = 96 + 文字番号*8
    sta OAM_BUF,y
    iny
    inx
    txa
    and #7
    bne @tloop
    rts

.segment "RODATA"
text_tiles:
    .byte $62,$63,$64,$65,$66,$67,$68,$69   ; ステージクリア!
    .byte $A7,$A1,$AD,$A5,$AF,$B6,$A5,$B2   ; GAMEOVER (ASCII フォント)
.segment "CODE"
