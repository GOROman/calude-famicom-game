; 音源ドライバ: TR-808 リズム + TB-303 風ベース + コード進行するメロディ + SFX
;   キック/スネア = DMC (DPCM サンプル, assets/drums.s $C000/$C3C0)
;   ハイハット    = ノイズ + ソフトウェアエンベロープ (クローズ=速い減衰, オープン=遅い)
;   ベース        = 三角波。ノート間ポルタメント (64/F スライド) と
;                   「鳴り始めは深く→浅く」のビブラートでレゾナンスのうねりを再現
;   メロディ      = SQ1 (ソフトエンベロープ 9→6) + SQ2 の2ステップ遅れエコー
;   コード進行    = タイトルはカノン進行 C G Am Em F C F G の8小節 (128 ステップ)
;   SFX           = ジャンプ/ショット/ミス (SQ1・SQ2), 敵ヒット (NOI), クリアファンファーレ
; 16 ステップ/小節, 1ステップ = 8フレーム ≈ 112BPM の16分

SQ1_VOL   = $4000
SQ2_VOL   = $4004
TRI_LIN   = $4008
TRI_LO    = $400A
TRI_HI    = $400B
NOI_VOL   = $400C
NOI_FREQ  = $400E
NOI_LEN   = $400F
DMC_FREQ  = $4010
DMC_ADDR  = $4012
DMC_LEN   = $4013

KICK_ADDR  = $00        ; ($C000-$C000)/64
KICK_LEN   = $3A        ; 929 バイト
SNARE_ADDR = $0F        ; ($C3C0-$C000)/64
SNARE_LEN  = $27        ; 625 バイト

.segment "CODE"
sound_init:
    lda #%00001111      ; SQ1 SQ2 TRI NOI 有効 (DMC はトリガ時にオン)
    sta APUSTATUS
    lda #$30            ; 全チャンネルミュートから開始
    sta SQ1_VOL
    sta SQ2_VOL
    sta NOI_VOL
    lda #$80
    sta TRI_LIN
    lda #$08            ; スイープ無効
    sta $4001
    sta $4005
    lda #0
    sta snd_tick
    sta snd_step
    sta snd_bar
    sta hat_vol
    sta vib_phase
    sta mel_vol
    sta mel_note
    sta mel_age
    sta mel_per_lo
    sta sfx1_type
    sta sfx2_type
    sta sfxn_t
    sta bass_cur_lo
    sta bass_cur_hi
    lda #15
    sta snd_fade
    rts

; ---- SFX トリガ API ----
sfx_jump:
    lda #1
    sta sfx1_type
    lda #0
    sta sfx1_t
    rts
sfx_miss:
    lda #2
    sta sfx1_type
    lda #0
    sta sfx1_t
    rts
sfx_shot:
    lda #1
    sta sfx2_type
    lda #0
    sta sfx2_t
    rts
sfx_defeat:
    lda #2
    sta sfx2_type
    lda #0
    sta sfx2_t
    rts
sfx_hit:
    lda #10
    sta sfxn_t
    rts
sfx_coin:
    lda #3
    sta sfx2_type
    lda #0
    sta sfx2_t
    rts
sfx_start:
    lda #3
    sta sfx1_type
    lda #0
    sta sfx1_t
    rts

; ================= メイン更新 (毎フレーム) =================
update_sound:
    lda game_state
    cmp #1
    bne @not_fanfare
    jmp fanfare_update  ; クリア中はファンファーレ専用
@not_fanfare:
    cmp #3
    bne @not_gameover
    jmp gameover_update ; ゲームオーバー: BGM停止 + 三角波ジングル
@not_gameover:
    cmp #2
    bne @not_dead
    lda #$80            ; ミス中は BGM を止める (SFX のみ鳴る)
    sta TRI_LIN
    lda #$30
    sta NOI_VOL
    lda #%10110000
    sta SQ1_VOL
    sta SQ2_VOL
    jmp sfx_overlay
@not_dead:
    ldx game_state      ; START 押下 (タイトル退場演出) 中は BGM 停止
    cpx #4
    bne @not_texit
    ldx title_exit
    beq @not_texit
    lda #$80
    sta TRI_LIN
    lda #$30
    sta NOI_VOL
    lda #%10110000
    sta SQ1_VOL
    sta SQ2_VOL
    jmp sfx_overlay     ; 開始ジングルだけ鳴る
@not_texit:
    ; ---- フェードイン (タイトル画面で 0→15) ----
    lda game_state
    cmp #4
    bne @fade_done
    lda snd_tick
    bne @fade_done
    lda snd_step        ; 2ステップごとに1段 (段階的な導入を聴かせる)
    and #1
    bne @fade_done
    lda snd_fade
    cmp #15
    bcs @fade_done
    inc snd_fade
@fade_done:
    lda snd_tick
    beq :+
    jmp @no_step
:   ; ---- 新しいステップ: pos = bar*16 + step ----
    lda snd_bar
    asl
    asl
    asl
    asl
    ora snd_step
    sta tmp             ; tmp = 曲内位置 (0-63)
    ldx snd_step        ; ドラムはフェード中も最初から鳴る (リズム先行)
    lda drum_pat,x
    tax                 ; X = ドラムビット
    and #2              ; スネア (DMC は1本なのでキックより優先)
    beq @try_kick
    jsr trig_snare
    jmp @drums_done
@try_kick:
    txa
    and #1
    beq @drums_done
    jsr trig_kick
@drums_done:
    txa
    and #4              ; クローズハット
    beq :+
    lda #10
    sta hat_vol
    lda #3
    sta hat_decay
    jsr trig_hat
:   txa
    and #8              ; オープンハット
    beq :+
    lda #12
    sta hat_vol
    lda #1
    sta hat_decay
    jsr trig_hat
:   ; ---- ベース (スイープなし: ノートオンで周期を直接セット) ----
    ldy tmp
    jsr get_bass        ; 曲別 (タイトル=コード進行 / ゲーム=Am グルーヴ)
    beq @bass_off
    tax
    lda #0
    sta bass_age        ; 鳴り始め → 深いビブラート
    lda bass_lo_tbl,x
    sta bass_tgt_lo
    sta bass_cur_lo
    lda bass_hi_tbl,x
    sta bass_tgt_hi
    sta bass_cur_hi
    lda #$FF            ; リニアカウンタ制御+最大 → 鳴らし続ける
    sta TRI_LIN
    jmp @melody
@bass_off:
    lda #$80            ; 消音 (cur は保持 → 次ノートへスライド)
    sta TRI_LIN
@melody:
    ; ---- メロディ (SQ1): ゲーム中は鳴らさない / タイトルはフェード終盤から ----
    lda game_state
    cmp #4
    bcc @mel_rest       ; ゲーム中 (0-3) はメロディなし
    cmp #6
    bcs @mel_rest       ; ラウンド表示中もなし
    lda snd_fade
    cmp #11
    bcc @mel_rest
    ldy tmp
    jsr get_mel
    beq @mel_rest
    cmp mel_note        ; 同音が続く場合はタイ (DQ2 風のサステイン)
    beq @echo
    sta mel_note
    tax
    lda #10             ; アタック音量 (10 → 2 へゆっくり減衰 = 透明感)
    sta mel_vol
    lda #0
    sta mel_age
    lda pulse_lo_tbl,x
    sta $4002
    sta mel_per_lo
    lda pulse_hi_tbl,x
    ora #%11111000
    sta $4003
    jmp @echo
@mel_rest:
    lda #0
    sta mel_vol
    sta mel_note
@echo:
    ; ---- SQ2: タイトル/ED=デチューンユニゾン (DQ2風) / ゲーム=2ステップ遅れエコー ----
    lda game_state
    cmp #4
    bcc @echo_rest      ; ゲーム中はエコー (メロディ複製) も鳴らさない
    cmp #6
    bcs @echo_rest
    lda snd_fade        ; メロディ未スタート中はデチューンも休み
    cmp #11
    bcc @echo_rest
    ldy tmp             ; デチューン: 同じノートを周期+1 でずらして重ねる
    jsr get_mel
    beq @echo_rest
    tax
    lda pulse_lo_tbl,x
    clc
    adc #1              ; +1 で数セントのズレ → コーラスのうねり
    sta $4006
    lda pulse_hi_tbl,x
    adc #0
    ora #%11111000
    sta $4007
    jmp @no_step        ; 音量はエンベロープ部で管理 (リードより薄く)
@echo_mode:
    lda tmp
    sec
    sbc #2
    tay
    jsr get_mel
    beq @echo_rest
    tax
    lda pulse_lo_tbl,x
    sta $4006
    lda pulse_hi_tbl,x
    ora #%11111000
    sta $4007
    lda #%10110011      ; デューティ50% 固定音量3
    sta SQ2_VOL
    jmp @no_step
@echo_rest:
    lda #%10110000
    sta SQ2_VOL
@no_step:
    ; ---- ステップ/小節カウンタ ----
    inc snd_tick
    lda snd_tick
    cmp #8
    bcc @envelopes
    lda #0
    sta snd_tick
    inc snd_step
    lda snd_step
    cmp #16
    bcc @envelopes
    lda #0
    sta snd_step
    inc snd_bar
    lda snd_bar
    and #7              ; 8小節 (カノン進行) でループ
    sta snd_bar
@envelopes:
    ; ---- ハイハットのエンベロープ ----
    lda hat_vol
    beq @hat_done
    sec
    sbc hat_decay
    bcs :+
    lda #0
:   sta hat_vol
    jsr cap_vol
    ora #$30
    sta NOI_VOL
@hat_done:
    ; ---- リードの透明感エンベロープ: 10 → 2 へゆっくり減衰 + 遅れビブラート ----
    lda mel_vol
    beq @mel_flat
    inc mel_age
    bne :+
    dec mel_age         ; 255 で張り付き
:   lda snd_tick
    and #3
    bne :+
    lda mel_vol
    cmp #3              ; floor 2 (消え際まで長く尾を引く)
    bcc :+
    dec mel_vol
:   lda mel_age         ; 24F 以降は ±1 の遅れビブラート (ガラスの揺らぎ)
    cmp #24
    bcc @mel_flat
    lsr
    lsr
    lsr
    and #3
    tax
    lda mel_vib,x
    clc
    adc mel_per_lo
    sta $4002
    clc
    adc #1              ; デチューン側も同じ揺らぎ (+1 ずれ維持)
    sta $4006
@mel_flat:
    lda mel_vol
    jsr cap_vol
    ora #%10110000
    sta SQ1_VOL
    ; デチューン (SQ2) はリードより 4 薄く = 透けて重なる
    lda game_state
    cmp #4
    bcc @sq2_env_done   ; ゲーム中の SQ2 は SFX 専用
    cmp #6
    bcs @sq2_env_done
    lda mel_vol
    sec
    sbc #4
    bcs :+
    lda #0
:   jsr cap_vol
    ora #%10110000
    sta SQ2_VOL
@sq2_env_done:
    ; ---- 303 ベース: スライド + レゾナンス風ビブラート ----
    jsr bass_update
    ; ---- SFX オーバーレイ (BGM の上から上書き) ----
    jmp sfx_overlay

; ---- ゲームオーバー: BGM を止めて三角波メインの下降ジングル ----
gameover_update:
    lda #$30            ; SQ/NOI ミュート
    sta NOI_VOL
    lda #%10110000
    sta SQ1_VOL
    sta SQ2_VOL
    ldx snd_tick
    inx
    beq :+              ; 255 で張り付き (鳴り終わり)
    stx snd_tick
:   txa
    lsr
    lsr
    lsr
    lsr                 ; 16F = 1ステップ
    cmp #8
    bcs @go_end
    tay
    lda go_pat,y
    beq @go_end
    tax
    lda bass_lo_tbl,x
    sta TRI_LO
    lda bass_hi_tbl,x
    sta TRI_HI
    lda #$FF
    sta TRI_LIN
    rts
@go_end:
    lda #$80
    sta TRI_LIN
    rts

; ---- 音量キャップ (フェードイン): A = min(A, snd_fade) ----
cap_vol:
    cmp snd_fade
    bcc :+
    lda snd_fade
:   rts

; ---- 曲別のパターン参照 (タイトル=128ステップのカノン進行, ゲーム=Am グルーヴ) ----
get_bass:               ; Y = 曲内位置 → A = ベースノート
    lda game_state
    cmp #4
    bcc @game           ; 4=タイトル 5=エンディング はコード進行曲
    cmp #6
    bcs @game           ; 6=ラウンド表示 はゲーム曲
    tya
    and #127
    tay
    lda bass_pat_title,y
    rts
@game:
    tya
    and #15             ; ゲーム曲のベースは16ステップループ
    tay
    lda bass_pat_game,y
    rts

get_mel:                ; Y = 曲内位置 → A = メロディノート
    lda game_state
    cmp #4
    bcc @game
    cmp #6
    bcs @game
    tya
    and #127
    tay
    lda melody_title,y
    rts
@game:
    tya
    and #31             ; ゲーム曲のメロディは32ステップループ
    tay
    lda melody_game,y
    rts

; ---- ベースのポルタメントとビブラート書き込み ----
bass_update:
    inc vib_phase
    inc bass_age
    bne :+
    dec bass_age        ; 255 で張り付き
:   ; --- cur を tgt へ 64/F でスライド ---
    lda bass_cur_lo
    sec
    sbc bass_tgt_lo
    sta tmp
    lda bass_cur_hi
    sbc bass_tgt_hi
    sta tmp2
    ora tmp
    beq @write          ; 到達済み
    lda tmp2
    bmi @slide_up
    bne @dec64          ; 差 256 以上
    lda tmp
    cmp #65
    bcs @dec64
    jmp @snap
@dec64:
    lda bass_cur_lo
    sec
    sbc #64
    sta bass_cur_lo
    bcs @write
    dec bass_cur_hi
    jmp @write
@slide_up:
    lda bass_tgt_lo
    sec
    sbc bass_cur_lo
    sta tmp
    lda bass_tgt_hi
    sbc bass_cur_hi
    bne @inc64
    lda tmp
    cmp #65
    bcs @inc64
@snap:
    lda bass_tgt_lo
    sta bass_cur_lo
    lda bass_tgt_hi
    sta bass_cur_hi
    jmp @write
@inc64:
    lda bass_cur_lo
    clc
    adc #64
    sta bass_cur_lo
    bcc @write
    inc bass_cur_hi
@write:
    lda snd_fade        ; ベースはフェード中盤 (ドラムの後) から
    cmp #6
    bcs :+
    lda #$80
    sta TRI_LIN
:   ; --- ビブラート: ノート直後 (12F) は深い ±6 → 以後 ±2。うねり=レゾナンス風 ---
    lda vib_phase
    lsr
    and #15
    tax
    lda bass_age
    cmp #12
    bcs @shallow
    lda vib_deep,x
    jmp @have_vib
@shallow:
    lda vib_tbl,x
@have_vib:
    sta tmp
    lda bass_cur_lo
    clc
    adc tmp
    sta TRI_LO
    lda tmp
    bmi @neg
    lda bass_cur_hi
    adc #0
    jmp @sthi
@neg:
    lda bass_cur_hi
    adc #$FF
@sthi:
    and #7
    ora #%11111000
    sta TRI_HI
    rts

; ---- SFX オーバーレイ: BGM のレジスタを上書きして効果音を優先 ----
sfx_overlay:
    ; --- SQ1: ジャンプ (上昇スイープ) / ミス (下降3音) ---
    lda sfx1_type
    bne :+
    jmp @sq2
:   ldx sfx1_t
    cmp #2
    beq @miss
    cmp #3
    beq @startse
    cpx #14             ; ジャンプ: 14F の上昇スイープ
    bcs @end1
    txa
    asl
    asl
    asl
    sta tmp
    lda #$C0
    sec
    sbc tmp
    sta $4002
    cpx #0
    bne :+
    lda #%11111000
    sta $4003
:   lda #%10110111      ; vol 7
    sta SQ1_VOL
    inc sfx1_t
    jmp @sq2
@startse:
    cpx #32             ; 開始ジングル: C4 E4 G4 C5 の上昇 (32F)
    bcs @end1
    txa
    lsr
    lsr
    lsr
    tay
    lda start_seq,y
    tay
    lda pulse_lo_tbl,y
    sta $4002
    txa
    and #7
    bne :+
    lda pulse_hi_tbl,y
    ora #%11111000
    sta $4003
:   lda #%10111000      ; デューティ50% vol 8
    sta SQ1_VOL
    inc sfx1_t
    jmp @sq2
@miss:
    cpx #40             ; ミス: E4 → D4 → A3 の下降 (40F)
    bcs @end1
    ldy #6              ; E4
    cpx #13
    bcc :+
    ldy #5              ; D4
    cpx #26
    bcc :+
    ldy #3              ; A3
:   lda pulse_lo_tbl,y
    sta $4002
    cpx #0
    bne :+
    lda pulse_hi_tbl,y
    ora #%11111000
    sta $4003
:   lda #%10111000      ; vol 8
    sta SQ1_VOL
    inc sfx1_t
    jmp @sq2
@end1:
    lda #0
    sta sfx1_type
@sq2:
    ; --- SQ2: ショット (下降ザップ) / 敵撃破 (上昇アルペジオ) ---
    lda sfx2_type
    bne :+
    jmp @noi
:   ldx sfx2_t
    cmp #2
    beq @defeat
    cmp #3
    beq @coin
    cpx #10             ; ショット: 10F の下降ザップ
    bcs @end2
    txa
    asl
    asl
    clc
    adc #$20
    sta $4006
    cpx #0
    bne :+
    lda #%11111000
    sta $4007
:   lda #%01110110      ; デューティ25% vol 6
    sta SQ2_VOL
    inc sfx2_t
    jmp @noi
@coin:
    cpx #16             ; コイン: B5 → E6 のディン (マリオ風)
    bcs @end2
    ldy #$70            ; B5
    cpx #4
    bcc :+
    ldy #$54            ; E6
:   sty $4006
    cpx #0
    beq :+
    cpx #4
    bne :++
:   lda #%11111000
    sta $4007
:   txa
    lsr
    sta tmp
    lda #12
    sec
    sbc tmp
    ora #%10110000      ; デューティ50%
    sta SQ2_VOL
    inc sfx2_t
    jmp @noi
@defeat:
    cpx #18             ; 撃破: C5 → E5 → G5 (18F)
    bcs @end2
    ldy #10             ; C5
    cpx #6
    bcc :+
    ldy #11             ; E5
    cpx #12
    bcc :+
    ldy #12             ; G5
:   lda pulse_lo_tbl,y
    sta $4006
    lda pulse_hi_tbl,y
    ora #%11111000
    sta $4007
    lda #%01110111      ; デューティ25% vol 7
    sta SQ2_VOL
    inc sfx2_t
    jmp @noi
@end2:
    lda #0
    sta sfx2_type
@noi:
    ; --- ノイズ: 敵ヒット (中域バースト) ---
    lda sfxn_t
    beq @done
    dec sfxn_t
    lda #$06
    sta NOI_FREQ
    lda sfxn_t
    ora #$30
    sta NOI_VOL
@done:
    rts

; ---- クリアファンファーレ (SQ1+SQ2, 他は消音) ----
fanfare_update:
    lda #$30
    sta NOI_VOL
    lda #$80
    sta TRI_LIN
    lda snd_tick
    bne @adv
    ldx snd_step
    cpx #12
    bcs @hold
    lda fanfare_pat,x
    beq @rest
    tax
    lda pulse_lo_tbl,x
    sta $4002
    clc
    adc #1              ; ファンファーレもデチューンで厚く
    sta $4006
    lda pulse_hi_tbl,x
    ora #%11111000
    sta $4003
    sta $4007
    lda #%10111100      ; SQ1 vol 12
    sta SQ1_VOL
    lda #%10110110      ; SQ2 デューティ50% vol 6 (ユニゾン)
    sta SQ2_VOL
    jmp @adv
@rest:
    lda #%10110000
    sta SQ1_VOL
    sta SQ2_VOL
@adv:
    inc snd_tick
    lda snd_tick
    cmp #6              ; ファンファーレは少し速いテンポ
    bcc :+
    lda #0
    sta snd_tick
    inc snd_step
:   rts
@hold:
    lda #%10110000
    sta SQ1_VOL
    sta SQ2_VOL
    jmp @adv

trig_kick:
    lda #$0D            ; 21307Hz, ループなし
    sta DMC_FREQ
    lda #KICK_ADDR
    sta DMC_ADDR
    lda #KICK_LEN
    sta DMC_LEN
    bne restart_dmc     ; 常に分岐
trig_snare:
    lda #$0E            ; 28224Hz
    sta DMC_FREQ
    lda #SNARE_ADDR
    sta DMC_ADDR
    lda #SNARE_LEN
    sta DMC_LEN
restart_dmc:
    lda #%00001111      ; DMC 停止 → 再スタート
    sta APUSTATUS
    lda #%00011111
    sta APUSTATUS
    rts

trig_hat:
    lda #$01            ; 高周波ノイズ
    sta NOI_FREQ
    lda #$08
    sta NOI_LEN
    rts

.segment "RODATA"
; ビット: 0=キック 1=スネア 2=クローズハット 3=オープンハット
drum_pat:
    .byte $05,$04,$08,$04, $07,$04,$08,$04
    .byte $05,$04,$08,$04, $07,$04,$08,$04
; ---- タイトル曲: コード進行 Am → F → C → G (4小節 x 16ステップ) ----
; ベース (0=休符 1=F1 2=G1 3=A1 4=C2 5=D2 6=E2 7=F2 8=G2 9=A2)
bass_pat_title:                             ; カノン進行 C G Am Em F C F G
    .byte 4,0,8,4, 0,4,8,0, 4,4,0,8, 4,0,8,8   ; C
    .byte 2,0,8,2, 0,2,8,0, 2,2,0,8, 2,0,8,8   ; G
    .byte 3,0,9,3, 0,3,9,0, 3,3,0,9, 3,0,9,9   ; Am
    .byte 6,0,8,6, 0,6,8,0, 6,6,0,8, 6,0,8,8   ; Em
    .byte 1,0,7,1, 0,1,7,0, 1,1,0,7, 1,0,7,7   ; F
    .byte 4,0,8,4, 0,4,8,0, 4,4,0,8, 4,0,8,8   ; C
    .byte 1,0,7,1, 0,1,7,0, 1,1,0,7, 1,0,7,7   ; F
    .byte 2,0,8,2, 0,2,8,0, 2,2,0,8, 2,0,8,4   ; G
; メロディ (0=休符 1=F3 2=G3 3=A3 4=C4 5=D4 6=E4 7=F4 8=G4 9=A4 10=C5 11=E5 12=G5 13=B3 14=B4 15=D5)
melody_title:                               ; カノンの下降ライン (E5 D5 C5 B4 A4 G4 ...)
    .byte 11,11,11,0, 15,15,15,0, 10,10,10,0, 15,0,10,15  ; C:  E5 D5 C5 D5
    .byte 14,14,14,0,  8, 8, 8,0, 14,14,14,0, 15,0,14,15  ; G:  B4 G4 B4 D5
    .byte 10,10,10,0, 14,14,14,0,  9, 9, 9,0, 10,0, 9,10  ; Am: C5 B4 A4 C5
    .byte 14,14,14,0,  8, 8, 8,0,  6, 6, 6,0,  8,0, 6, 8  ; Em: B4 G4 E4 G4
    .byte  9, 9, 9,0,  8, 8, 8,0,  7, 7, 7,0,  9,0, 7, 9  ; F:  A4 G4 F4 A4
    .byte  8, 8, 8,0,  6, 6, 6,0,  4, 4, 4,0,  6,0, 4, 6  ; C:  G4 E4 C4 E4
    .byte  7, 7, 7,0,  9, 9, 9,0, 10,10,10,0,  9,0,10, 9  ; F:  F4 A4 C5 A4
    .byte 14,14,14,0, 15,15,15,0, 14,14,14,0,  8,0,14,15  ; G:  B4 D5 B4 G4
; ---- ゲーム曲 (1-1〜): 元の Am グルーヴ (ベース16 / メロディ32 ステップ) ----
bass_pat_game:
    .byte 3,0,3,0, 3,0,5,4, 3,0,3,0, 6,5,4,0
melody_game:
    .byte 3,0,3,4, 6,0,6,5, 4,5,6,0, 8,0,6,5
    .byte 3,0,3,4, 6,0,8,9, 10,0,9,8, 6,5,4,5
; ファンファーレ: C4 E4 G4 C5 . G4 C5 C5
fanfare_pat:
    .byte 4,6,8,10, 0,8,10,10, 0,0,0,0
; 三角波の周期 (NTSC: 1789773/(32*f)-1)
bass_lo_tbl: .byte 0,$00,$74,$F8,$56,$F8,$A5,$80,$39,$FB
bass_hi_tbl: .byte 0,$05,$04,$03,$03,$02,$02,$02,$02,$01
; パルス波の周期 (NTSC: 1789773/(16*f)-1)
pulse_lo_tbl: .byte 0,$80,$39,$FB,$AA,$7C,$52,$3F,$1C,$FD,$D5,$A9,$8E,$C4,$E1,$BD
pulse_hi_tbl: .byte 0,  2,  2,  1,  1,  1,  1,  1,  1,  0,  0,  0,  0,  1,  0,  0
; ビブラート: 浅 (±2) と 深 (±6, ノート直後のレゾナンス風)
vib_tbl:  .byte 0,1,1,2,2,2,1,1,0,$FF,$FF,$FE,$FE,$FE,$FF,$FF
vib_deep: .byte 0,2,4,5,6,5,4,2,0,$FE,$FC,$FB,$FA,$FB,$FC,$FE
mel_vib:  .byte 0,1,0,$FF           ; リードの遅れビブラート (±1)
start_seq: .byte 4,6,8,10           ; 開始ジングル C4 E4 G4 C5
go_pat:    .byte 9,8,7,6,4,3,3,0    ; ゲームオーバー: A3 G3 F3 E3 C3 A2 A2
.segment "CODE"
