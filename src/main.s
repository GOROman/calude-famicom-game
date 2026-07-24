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
jump_origin_y: .res 1   ; ジャンプ開始時の Y (SMB DiffToHaltJump 用)
arrow_flag:   .res 2    ; 矢: 0=なし 1=右 2=左 (最大2発)
arrow_xlo:    .res 2    ; 矢のワールド X (16bit)
arrow_xhi:    .res 2
arrow_y:      .res 2
spr_tile_buf: .res 4    ; 表示するタイル4枚 (facing 反映済み: TL,TR,BL,BR)
anim_timer:   .res 1    ; 歩きアニメ用カウンタ
attack_timer: .res 1    ; 攻撃ポーズの残りフレーム
tmp2:         .res 1
tmp3:         .res 1
frame_count:  .res 1    ; グローバルフレームカウンタ
enemy_flag:   .res 3    ; 決意マン: 0=いない 1=生存
enemy_xlo:    .res 3    ; ワールド X (16bit)
enemy_xhi:    .res 3
enemy_dir:    .res 3    ; 0=右へ 1=左へ
enemy_timer:  .res 3    ; ダメージ/消失アニメの残りフレーム
fx_timer:     .res 1    ; ヒットエフェクトの残りフレーム
fx_xlo:       .res 1    ; エフェクトのワールド X (16bit)
fx_xhi:       .res 1
fx_y:         .res 1
item_flag:    .res 2    ; アイテム: 0=なし 1=無敵の星 2=パワー矢
item_xlo:     .res 2    ; ワールド X (16bit)
item_xhi:     .res 2
item_y:       .res 2
star_timer:   .res 1    ; 無敵の残り (2フレームに1減)
weapon_level: .res 1    ; 0=通常矢 1=パワー矢 (速い+貫通)
game_state:   .res 1    ; 0=プレイ中 1=クリア 2=死亡演出 3=ゲームオーバー
state_timer:  .res 1    ; 演出の残りフレーム
lives:        .res 1    ; 残機
snd_tick:     .res 1    ; 音源: ステップ内フレーム (0-7)
snd_step:     .res 1    ; 音源: シーケンサステップ (0-15)
snd_bar:      .res 1    ; 音源: 小節 (0-3, コード進行 Am F C G)
hat_vol:      .res 1    ; ハイハットの現在音量 (エンベロープ)
hat_decay:    .res 1    ; ハイハットの減衰速度
vib_phase:    .res 1    ; ベースビブラートの LFO 位相
mel_vol:      .res 1    ; リードの現在音量 (ソフトエンベロープ)
bass_cur_lo:  .res 1    ; 303 ベース: 現在周期 (スライド中の値)
bass_cur_hi:  .res 1
bass_tgt_lo:  .res 1    ; 303 ベース: ターゲット周期
bass_tgt_hi:  .res 1
bass_age:     .res 1    ; ノートオンからの経過 (ビブラート深さ切替)
sfx1_type:    .res 1    ; SQ1 SFX: 0=なし 1=ジャンプ 2=ミス
sfx1_t:       .res 1
sfx2_type:    .res 1    ; SQ2 SFX: 0=なし 1=ショット 2=敵撃破
sfx2_t:       .res 1
sfxn_t:       .res 1    ; ノイズ SFX (敵ヒット) の残り
current_stage: .res 1   ; 0-3 = ステージ 1-1〜1-4
level_ptr:    .res 2    ; 現在ステージの level_map ポインタ
probe_res:    .res 1    ; probe_two の中間結果
text_ptr:     .res 2    ; 状態テキストのテーブルポインタ
score:        .res 4    ; スコア (100点単位の10進4桁, index0=最上位)
menu_sel:     .res 1    ; タイトルメニュー選択 (0=START 1=CONTINUE 2=OPTION)
boss_state:   .res 1    ; ボス: 0=不在 1=生存 2=撃破演出
boss_hp:      .res 1
boss_xlo:     .res 1    ; ワールド X (16bit)
boss_xhi:     .res 1
boss_y:       .res 1
boss_vy_lo:   .res 1    ; 縦速度 (8.8)
boss_vy_hi:   .res 1
boss_timer:   .res 1    ; 行動/演出タイマー
boss_flash:   .res 1    ; 被弾フラッシュ (無敵時間)
snd_fade:     .res 1    ; BGM フェードイン (0-15 の音量キャップ)
mel_note:     .res 1    ; メロディの前ノート (同音はタイ = リトリガしない)
coin_ones:    .res 1    ; コイン枚数 (10進 下桁)
coin_tens:    .res 1    ; コイン枚数 (10進 上桁)
coin_ptr:     .res 2    ; 現在ステージの coin_map ポインタ
coin_ppu_hi:  .res 1    ; 取得コインの消去先 PPU アドレス (0=なし)
coin_ppu_lo:  .res 1

.segment "BSS"
col_buf:      .res 30   ; 1列分のタイルバッファ (縦30タイル)
coin_taken:   .res 8    ; 取得済みコインのビットマップ (メタ列 0-63)

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

    jsr sound_init
    lda #3              ; 残機3でスタート
    sta lives
    lda #0
    sta current_stage
    jsr show_title      ; まずはタイトル画面 (START でゲーム開始)

main_loop:
    jsr read_controller
    lda game_state
    beq @playing
    cmp #4
    bne :+
    jsr update_title    ; タイトル画面 (メニュー選択)
    jmp @finish
:   cmp #5
    bne @in_state
    jsr update_ending   ; エンディング (START でタイトルへ)
    jmp @finish
@in_state:
    jsr update_state    ; クリア/死亡/ゲームオーバー演出中
    lda game_state      ; 演出からタイトル/エンディングへ遷移したら
    cmp #4              ; このフレームの描画はスキップ (OAM 残留防止)
    bcs @finish
    jmp @draw
@playing:
    jsr update_player
    jsr update_arrows
    jsr update_enemies
    jsr update_boss
    jsr update_items
    jsr update_coins
    jsr check_clear
@draw:
    jsr update_camera
    jsr draw_player
    jsr draw_arrows
    jsr draw_enemies
    jsr draw_boss
    jsr draw_items
    jsr draw_hud
@finish:
    jsr update_sound
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
    bne :+
    jmp @skip           ; メインループが間に合っていなければ何もしない
:
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
    ; ---- 取得コインの BG タイル消去 ----
    lda coin_ppu_hi
    beq @no_coin_erase
    bit PPUSTATUS
    sta PPUADDR
    lda coin_ppu_lo
    sta PPUADDR
    lda #0
    sta PPUDATA
    sta coin_ppu_hi
@no_coin_erase:
    ; ---- タイトル: パレットサイクルでロゴを輝かせる ----
    lda game_state
    cmp #4
    bne @no_palanim
    lda frame_count     ; (update_title が毎フレーム加算)
    and #7
    bne @no_palanim
    lda frame_count
    lsr
    lsr
    lsr
    and #7
    tax
    bit PPUSTATUS
    lda #$3F
    sta PPUADDR
    lda #$09            ; BG パレット2 スロット1 (ロゴの金色)
    sta PPUADDR
    lda logo_cycle,x
    sta PPUDATA
@no_palanim:
    ; スクロールとネームテーブル選択 (PPUADDR を触った後に必ず再設定)
    lda scroll_hi
    and #1
    ora #%10000000
    ldx game_state      ; ゲーム中のスプライトは PT1 (タイトルは PT0)
    cpx #4
    beq :+
    ora #%00001000
:   sta PPUCTRL
    lda scroll_lo
    sta PPUSCROLL
    lda #$00
    sta PPUSCROLL
    sta nmi_ready
    ; ---- タイトル画面: スプライト0ヒットで PT0→PT1 に切替 (上下スプリット) ----
    lda game_state
    cmp #4
    bne @no_split
    ldy #200            ; フラグのクリア待ち (プリレンダライン)
@wc1:
    ldx #40
@wc2:
    bit PPUSTATUS
    bvc @cleared
    dex
    bne @wc2
    dey
    bne @wc1
    jmp @no_split
@cleared:
    ldy #250            ; ヒット待ち (split 行, ~136 ライン後)
@wh1:
    ldx #80
@wh2:
    bit PPUSTATUS
    bvs @hit
    dex
    bne @wh2
    dey
    bne @wh1
    jmp @no_split
@hit:
    lda #%10010000      ; 下半分は PT1
    sta PPUCTRL
@no_split:
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
.include "arrow.s"
.include "enemy.s"
.include "item.s"
.include "state.s"
.include "sound.s"
.include "boss.s"

.segment "RODATA"
logo_cycle: .byte $27,$37,$28,$38,$27,$17,$07,$17  ; 金色の明滅 (炎のゆらぎ)

.segment "VECTORS"
    .addr nmi, reset, irq

.include "../assets/drums.s"
.include "../assets/title_screen.s"

.segment "CHR"
.include "../assets/chr.s"
; PT0 残り ($D0-$FF) をパディングして PT1 = ゲーム用スプライトバンク
    .res (256-208)*16, $00
.include "../assets/sprites.s"

.segment "CHRTITLE"
.include "../assets/title_chr.s"
