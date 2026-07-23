# 狩人行動 (Calude Kodo)

**狩人 (かりゅーど)** が主人公のファミコン(NES)**横スクロールアクションゲーム**。6502 アセンブラ (ca65) でフルスクラッチ開発するプロジェクトです。[Claude Code](https://claude.com/claude-code) (Fable 5) と一緒にステップバイステップで作っていきます。

**▶ 遊ぶ: [cluade-famicom-emu で直接ブート](https://goroman.github.io/cluade-famicom-emu/?pin=0&debug=1&rom=https://raw.githubusercontent.com/GOROman/calude-famicom-game/main/game.nes)**

動作確認には自作 WASM エミュレータ [cluade-famicom-emu](https://github.com/GOROman/cluade-famicom-emu) を使用。

![スクリーンショット: ジャンプ中のカリュード](docs/screenshot.png)

## ストーリー

世界は「**決意マン**」に支配されてしまった。決意マンは決意する。「明日から本気を出す」「今度こそやる」「絶対にやり遂げる」——だが、決意だけして何も行動しない。

狩人カリュードは今日も行く。武器は弓ではない。「**行動**」だ。決意だけの者たちを、実際に動くことで打ち倒していく——狩人行動 (Calude Kodo)、それは行動する者の物語。

## 必要環境

- macOS (他OSでも cc65 と make があれば可)
- [cc65](https://cc65.github.io/) ツールチェーン (ca65 / ld65)

```sh
brew install cc65
```

## ビルド

```sh
make          # game.nes を生成 (iNES形式, Mapper 0 / NROM-256)
make run      # cluade-famicom-emu をローカル配信してブラウザで開く
make clean
```

`make run` 後、ブラウザの「ROMを開く」から `game.nes` を読み込むと起動します。
([Web版エミュレータ](https://goroman.github.io/cluade-famicom-emu/) に直接読み込んでもOK)

## 操作方法

| 操作 | NES | キーボード (cluade-famicom-emu) |
|------|-----|------|
| 左右移動 | 十字キー ←→ | 矢印キー ←→ |
| ジャンプ | A | X |

## 構成

```
├── Makefile           # ca65/ld65 ビルド
├── nes.cfg            # ld65 リンカ設定 (PRG 32KB + CHR 8KB)
├── src/
│   ├── main.s         # エントリ・リセット処理・メインループ・NMI
│   ├── header.s       # iNES ヘッダ
│   ├── ppu.s          # PPU 初期化・画面クリア・パレット
│   ├── controller.s   # コントローラ読み取り
│   ├── player.s       # プレイヤー移動・ジャンプ物理・メタスプライト描画
│   └── level.s        # レベルデータ・カメラ・列ストリーミング
└── assets/
    └── chr.s          # CHR パターンデータ (.byte 直書き)
```

## 技術メモ

- **ゲームループ**: メインループで入力→更新→シャドウOAM ($0200) 書き込み → NMI (vblank) で OAM DMA 転送
- **ジャンプ物理**: スーパーマリオ風の可変ジャンプ (A の押下時間で高さが変わる)。Y 速度は 8.8 固定小数点、初速 -4.0 px/f。上昇中に A 押下中は弱い重力 ($20)、A 解放後や下降中は強い重力 ($70)、落下速度上限 4 px/f — SMB の JumpMForceData / FallMForceData / ImposeGravity と同じ方式。長押しで約62px、タップで約25px
- **プレイヤー**: 16x16 メタスプライト (8x8 x4枚)。左右反転は水平フリップ属性+タイル列入れ替え
- **横スクロール**: 垂直ミラーリングの2画面をリングとして使用。プレイヤーは16bitワールド座標で動き、カメラは画面中央 (x=120) に追従、[0, 768] でクランプ。8px境界を越えるたびに画面外の1列 (縦30タイル) を NMI 中に PPU へ縦書き転送する列ストリーミング (SMB 方式)
- **レベル**: 128列 (4画面分) を列単位のフィーチャコード (平地/柱/浮きブロック) で圧縮した `level_map` から生成

## ロードマップ

- [x] **Step 1**: 画面クリア + スプライト表示、左右移動とジャンプ
- [x] **Step 2**: 背景 (地面・ブロック) と横スクロール
- [ ] **Step 3**: 地形との当たり判定
- [ ] **Step 4**: 敵キャラクター「決意マン」と接触判定
- [ ] **Step 5**: サウンド (BGM / 効果音)
- [ ] **Step 6**: タイトル画面・ゲームオーバー

## License

MIT
