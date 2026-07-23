# calude-famicom-game

ファミコン(NES)の**横スクロールアクションゲーム**を 6502 アセンブラ (ca65) でフルスクラッチ開発するプロジェクト。[Claude Code](https://claude.com/claude-code) (Fable 5) と一緒にステップバイステップで作っていきます。

動作確認には自作 WASM エミュレータ [cluade-famicom-emu](https://github.com/GOROman/cluade-famicom-emu) を使用。

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
│   └── player.s       # プレイヤー移動・ジャンプ物理・メタスプライト描画
└── assets/
    └── chr.s          # CHR パターンデータ (.byte 直書き)
```

## 技術メモ

- **ゲームループ**: メインループで入力→更新→シャドウOAM ($0200) 書き込み → NMI (vblank) で OAM DMA 転送
- **ジャンプ物理**: Y 速度を 8.8 固定小数点で保持。初速 -5.0 px/f、重力 0.25 px/f²
- **プレイヤー**: 16x16 メタスプライト (8x8 x4枚)。左右反転は水平フリップ属性+タイル列入れ替え

## ロードマップ

- [x] **Step 1**: 画面クリア + スプライト表示、左右移動とジャンプ
- [ ] **Step 2**: 背景 (地面・ブロック) と横スクロール
- [ ] **Step 3**: 地形との当たり判定
- [ ] **Step 4**: 敵キャラクターと接触判定
- [ ] **Step 5**: サウンド (BGM / 効果音)
- [ ] **Step 6**: タイトル画面・ゲームオーバー

## License

MIT
