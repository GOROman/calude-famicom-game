// README 用スクリーンショット3枚 (タイトル/ジャンプ/ボス戦) をヘッドレス撮影
// 使い方: node tools/capture_screens.js '{"game_state":67,...}' 出力ディレクトリ
// ZP アドレスは build/dbg.txt から tools/update_screens.py が渡す
const fs = require('fs'), path = require('path');
const EMU = path.join(process.env.HOME, 'work/github.com/GOROman/cluade-famicom-emu/web');
const A = JSON.parse(process.argv[2]);
const OUT = process.argv[3];
const ROM = path.join(__dirname, '..', 'game.nes');

async function boot() {
  const src = fs.readFileSync(path.join(EMU, 'nes.js'), 'utf8');
  const wasmBin = fs.readFileSync(path.join(EMU, 'nes.wasm'));
  const fn = new Function('module', 'exports', 'require', 'process', 'console', '__dirname',
    src + '\n;return typeof createNesModule!=="undefined"?createNesModule:module.exports;');
  const m = { exports: {} };
  const create = fn(m, m.exports, require, process, console, EMU);
  const mod = await create({ instantiateWasm: (imp, cb) => {
    WebAssembly.instantiate(wasmBin, imp).then(r => cb(r.instance, r.module)); return {};
  }});
  const rom = fs.readFileSync(ROM);
  mod._nes_init(44100);
  const buf = mod._nes_rom_buffer(rom.length);
  mod.HEAPU8.set(rom, buf);
  mod._nes_load_rom(rom.length);
  mod._nes_power_on();
  return mod;
}
const save = (m, name) => {
  const p = m._nes_framebuffer();
  fs.writeFileSync(path.join(OUT, name + '.rgba'), Buffer.from(m.HEAPU8.subarray(p, p + 256 * 240 * 4)));
};

(async () => {
  // ---- 1. タイトル画面 (フェードイン完了後) ----
  let m = await boot();
  const ram = () => m.HEAPU8.subarray(m._nes_ram(), m._nes_ram() + 2048);
  const zp = a => ram()[a];
  const run = (n, btn) => { m._nes_set_buttons(0, btn); for (let i = 0; i < n; i++) m._nes_frame(); };
  run(320, 0);
  save(m, 'title');

  // ---- 2. ゲームプレイ (ジャンプ中) ----
  run(2, 0x08); run(1, 0);
  let w = 0; while (zp(A.game_state) !== 6 && w < 500) { m._nes_frame(); w++; }
  while (zp(A.game_state) === 6) m._nes_frame();
  run(40, 0x80);          // 少し右へ
  run(14, 0x81);          // ジャンプ (頂点付近で撮る)
  save(m, 'jump');

  // ---- 3. ボス戦 (1-4 終盤へテレポート歩行) ----
  m = await boot();
  run(200, 0);
  ram()[A.menu_sel] = 1; ram()[A.current_stage] = 3;   // CONTINUE で 1-4
  run(2, 0x08); run(1, 0);
  w = 0; while (zp(A.game_state) !== 6 && w < 500) { m._nes_frame(); w++; }
  while (zp(A.game_state) === 6) m._nes_frame();
  for (let wx = 120; wx < 860; wx += 4) {              // 無敵テレポート歩行
    ram()[A.world_x_lo] = wx & 255; ram()[A.world_x_hi] = wx >> 8;
    ram()[A.player_y] = 168; ram()[A.on_ground] = 1;
    ram()[A.vel_y_lo] = 0; ram()[A.vel_y_hi] = 0;
    ram()[A.star_timer] = 255;
    m._nes_frame();
  }
  ram()[A.star_timer] = 0;
  run(40, 0);                                          // ボスが跳ぶのを待つ
  run(1, 0x02); run(8, 0);                             // 弓を構えた瞬間
  save(m, 'boss');
  console.log('captured: title/jump/boss, boss_state=' + zp(A.boss_state));
})();
