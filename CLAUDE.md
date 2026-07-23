# CLAUDE.md

狩人行動 (Calude Kodo) — ファミコン用横スクロールアクション (ca65 アセンブラ)。

## 開発ルール

- **開発日誌を毎回書く**: 機能追加・変更のたびに `docs/diary/` へエッセイ風の開発日誌を書く。Step 単位のファイル (step1.md, step2.md, ...) に、Step をまたがない作業は該当 Step のファイルへの追記か番外編として書く。`docs/diary/README.md` の索引と本体 README の「開発日誌」リンクも更新する。
- マイルストーンごとに `roms/` へ連番付きで ROM をアーカイブし (例: `roms/11-ketsuiman.nes`)、README の「▶ 遊ぶ」プレイリンクを最新の roms/ ファイルに張り替える。
- ROM を更新したら `docs/editor/base.nes` も差し替える (ステージエディタが ROM 書き出しのベースに使う。ROM 内の `LVLMAP01` マーカー直後 64 バイトが level_map)。
- 検証は cluade-famicom-emu (`~/work/github.com/GOROman/cluade-famicom-emu`) の WASM コアを Node.js でヘッドレス実行して行う。ブラウザ確認はタブ非アクティブで止まるので不向き。
- リポジトリ名の綴り (calude / cluade) は意図的。修正しないこと。
