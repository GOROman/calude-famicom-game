; iNES ヘッダ (Mapper 0 / NROM-256)
.segment "HEADER"
    .byte "NES", $1A
    .byte 2             ; PRG-ROM 16KB x2 = 32KB
    .byte 1             ; CHR-ROM 8KB x1
    .byte %00000001     ; Mapper 0, 垂直ミラーリング (横スクロール用)
    .byte %00000000
    .res 8, $00
