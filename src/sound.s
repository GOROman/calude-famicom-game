; 音源ドライバ: TR-808 風リズム + ベース
;   キック/スネア = DMC (DPCM サンプル, assets/drums.s $C000/$C3C0)
;   ハイハット    = ノイズ + ソフトウェアエンベロープ (クローズ=速い減衰, オープン=遅い)
;   ベース        = 三角波 + ビブラート LFO (サインテーブルでピッチ変調)
; 16 ステップシーケンサ (1ステップ = 8フレーム ≈ 112BPM の16分)

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
    lda #$30            ; 矩形波はミュート
    sta SQ1_VOL
    sta SQ2_VOL
    sta NOI_VOL         ; ノイズ音量0
    lda #$80
    sta TRI_LIN         ; 三角波停止
    lda #0
    sta snd_tick
    sta snd_step
    sta hat_vol
    sta vib_phase
    rts

update_sound:
    ; ---- ステップ進行 ----
    lda snd_tick
    bne @no_step
    ldx snd_step
    lda drum_pat,x
    tay
    and #2              ; スネア (DMC は1本なのでキックより優先)
    beq @try_kick
    jsr trig_snare
    jmp @drums_done
@try_kick:
    tya
    and #1
    beq @drums_done
    jsr trig_kick
@drums_done:
    tya
    and #4              ; クローズハット
    beq :+
    lda #10
    sta hat_vol
    lda #3              ; 速い減衰
    sta hat_decay
    jsr trig_hat
:   tya
    and #8              ; オープンハット
    beq :+
    lda #12
    sta hat_vol
    lda #1              ; 遅い減衰
    sta hat_decay
    jsr trig_hat
:   ; ---- ベース (三角波) ----
    lda bass_pat,x
    beq @bass_off
    tax
    lda bass_lo_tbl,x
    sta bass_per_lo
    sta TRI_LO
    lda bass_hi_tbl,x
    ora #%11111000      ; 長さカウンタ最大
    sta TRI_HI
    lda #$FF            ; リニアカウンタ制御+最大 → 鳴らし続ける
    sta TRI_LIN
    jmp @no_step
@bass_off:
    lda #$80            ; 消音
    sta TRI_LIN
@no_step:
    inc snd_tick
    lda snd_tick
    cmp #8
    bcc :+
    lda #0
    sta snd_tick
    inc snd_step
    lda snd_step
    and #15
    sta snd_step
:
    ; ---- ハイハットのソフトウェアエンベロープ (毎フレーム減衰) ----
    lda hat_vol
    beq @hat_done
    sec
    sbc hat_decay
    bcs :+
    lda #0
:   sta hat_vol
    ora #$30            ; 長さ停止 + 固定音量モード
    sta NOI_VOL
@hat_done:
    ; ---- ベースのビブラート LFO (周期 32F ≈ 1.9Hz, 振幅 ±2) ----
    inc vib_phase
    lda vib_phase
    lsr
    and #15
    tax
    lda bass_per_lo
    clc
    adc vib_tbl,x
    sta TRI_LO
    rts

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
; ノート番号 (0=休符, 1=G1 2=A1 3=C2 4=D2 5=E2)
bass_pat:
    .byte 2,0,2,0, 2,0,4,3, 2,0,2,0, 5,4,3,0
; 三角波の周期 (NTSC: 1789773/(32*f)-1)
bass_lo_tbl: .byte 0,$74,$F8,$56,$F8,$A5
bass_hi_tbl: .byte 0,$04,$03,$03,$02,$02
; ビブラート: 2*sin(2πi/16)
vib_tbl: .byte 0,1,1,2,2,2,1,1,0,$FF,$FF,$FE,$FE,$FE,$FF,$FF
.segment "CODE"
