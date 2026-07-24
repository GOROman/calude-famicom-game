; iNES ヘッダ (Mapper 3 / CNROM: CHR 16KB をバンク切替)
.segment "HEADER"
    .byte "NES", $1A
    .byte 2             ; PRG-ROM 16KB x2 = 32KB
    .byte 4             ; CHR-ROM 8KB x4 (0=ゲーム 1=タイトル 2=タイトル演出 3=予備)
    .byte %00110001     ; Mapper 3, 垂直ミラーリング (横スクロール用)
    .byte %00000000
    .res 8, $00
