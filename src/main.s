; ファミコン 横スクロールアクション — ステップ1
; 画面クリア + プレイヤーの左右移動とジャンプ

.include "header.s"

; ---- PPU / APU レジスタ ----
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007
OAMDMA    = $4014
APUSTATUS = $4015
JOY1      = $4016
FRAMECNT  = $4017

OAM_BUF   = $0200       ; スプライト用シャドウ OAM (256バイト)

.segment "ZEROPAGE"
nmi_ready:    .res 1    ; 1=描画データ準備完了 (NMI が 0 に戻す)
buttons:      .res 1    ; A B Select Start Up Down Left Right (bit7..bit0)
prev_buttons: .res 1    ; 前フレームの buttons (エッジ検出用)
player_x:     .res 1    ; X 座標 (スプライト左上)
player_y:     .res 1    ; Y 座標 整数部
player_y_sub: .res 1    ; Y 座標 小数部 (8.8 固定小数点)
vel_y_lo:     .res 1    ; Y 速度 小数部
vel_y_hi:     .res 1    ; Y 速度 整数部 (符号付き)
on_ground:    .res 1    ; 1=接地中
facing:       .res 1    ; 0=右向き 1=左向き
tmp_attr:     .res 1
world_x_lo:   .res 1    ; プレイヤーのワールド X (16bit)
world_x_hi:   .res 1
scroll_lo:    .res 1    ; カメラスクロール X (16bit)
scroll_hi:    .res 1
prev_col:     .res 1    ; 前フレームの左端列番号 (ストリーミング検出用)
col_pending:  .res 1    ; NMI で転送する列番号 ($FF=なし)
col_ppu_hi:   .res 1    ; 転送先 PPU アドレス
col_ppu_lo:   .res 1
tmp:          .res 1

.segment "BSS"
col_buf:      .res 30   ; 1列分のタイルバッファ (縦30タイル)

.segment "CODE"
reset:
    sei
    cld
    ldx #$40
    stx FRAMECNT        ; APU フレーム IRQ 無効化
    ldx #$FF
    txs
    inx                 ; X = 0
    stx PPUCTRL         ; NMI 無効
    stx PPUMASK         ; 描画オフ
    stx APUSTATUS       ; APU 全チャンネルオフ
    bit PPUSTATUS
:   bit PPUSTATUS       ; vblank 1回目待ち (PPU ウォームアップ)
    bpl :-

    ; RAM クリア ($0000-$07FF)
    lda #$00
    tax
@clr_ram:
    sta $0000,x
    sta $0100,x
    sta $0300,x
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne @clr_ram
    ; シャドウ OAM は $FF で埋めて全スプライトを画面外へ
    lda #$FF
@clr_oam:
    sta OAM_BUF,x
    inx
    bne @clr_oam

:   bit PPUSTATUS       ; vblank 2回目待ち
    bpl :-

    jsr ppu_init        ; パレット設定 + ネームテーブルクリア
    jsr level_init      ; 最初の2画面分 (64列) を描画
    jsr player_init

    lda #%10000000      ; NMI 有効, BG/SP ともパターンテーブル0
    sta PPUCTRL
    lda #%00011110      ; BG + スプライト表示
    sta PPUMASK

main_loop:
    jsr read_controller
    jsr update_player
    jsr update_camera
    jsr draw_player
    lda #1
    sta nmi_ready
:   lda nmi_ready       ; NMI (vblank) を待つ
    bne :-
    jmp main_loop

; ---- NMI: vblank 中に OAM DMA とスクロール再設定 ----
nmi:
    pha
    txa
    pha
    tya
    pha
    lda nmi_ready
    beq @skip           ; メインループが間に合っていなければ何もしない
    lda #$00
    sta OAMADDR
    lda #>OAM_BUF
    sta OAMDMA
    ; キューされた列があれば転送 (縦書き = アドレス+32 モード)
    lda col_pending
    cmp #$FF
    beq @no_col
    lda #%10000100
    sta PPUCTRL
    jsr write_column
@no_col:
    ; スクロールとネームテーブル選択 (PPUADDR を触った後に必ず再設定)
    lda scroll_hi
    and #1
    ora #%10000000
    sta PPUCTRL
    lda scroll_lo
    sta PPUSCROLL
    lda #$00
    sta PPUSCROLL
    sta nmi_ready
@skip:
    pla
    tay
    pla
    tax
    pla
irq:
    rti

.include "ppu.s"
.include "controller.s"
.include "player.s"
.include "level.s"

.segment "VECTORS"
    .addr nmi, reset, irq

.segment "CHR"
.include "../assets/chr.s"
