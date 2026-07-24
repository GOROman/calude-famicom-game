; iNES ヘッダ (Mapper 3 / CNROM: CHR 16KB をバンク切替)
.segment "HEADER"
    .byte "NES", $1A
    .byte 2             ; PRG-ROM 16KB x2 = 32KB
    .byte 2             ; CHR-ROM 8KB x2 (バンク0=ゲーム, バンク1=タイトル画面)
    .byte %00110001     ; Mapper 3, 垂直ミラーリング (横スクロール用)
    .byte %00000000
    .res 8, $00
