; ラウンド画面のセリフ + 顔データ (roundface_gen.py 生成)
.segment "RODATA"
round_dlg0:
    .byte $E8,$F1,$E2,$FD,$FE,$FA,$FF,$F0,$E5,$EA,$EB,$F9,$FA,$FF,$E4,$F4,$E2,$FF,$00
round_dlg1:
    .byte $E8,$F1,$E2,$FA,$FF,$E9,$E3,$F3,$E3,$F5,$FF,$E6,$E4,$F2,$F7,$EE,$F9,$FF,$00
round_dlg2:
    .byte $EF,$E3,$F8,$FF,$E9,$E3,$F3,$E3,$E9,$EF,$E7,$FF,$ED,$F6,$F2,$F8,$FF,$00
round_dlg3:
    .byte $F1,$F8,$E2,$FF,$E8,$F1,$E2,$FA,$FF,$E6,$FC,$EC,$F9,$FB,$7F,$7F,$FF,$00
round_dlg_lo: .byte <round_dlg0,<round_dlg1,<round_dlg2,<round_dlg3
round_dlg_hi: .byte >round_dlg0,>round_dlg1,>round_dlg2,>round_dlg3
; 顔タイル ID (4列x3行, NT へそのまま並べる)
round_face_ids:
    .byte $D0,$D1,$D2,$D3
    .byte $D4,$D5,$D6,$D7
    .byte $D8,$D9,$DA,$DB
ROUND_EYE_N = 6
round_eye_cell:   .byte 4,5,6,8,9,10   ; 顔グリッド内セル番号
round_eye_open:   .byte $D4,$D5,$D6,$D8,$D9,$DA
round_eye_closed: .byte $DC,$DD,$DE,$DF,$E0,$E1
round_eye_ahi: .byte $20,$20,$20,$20,$20,$20
round_eye_alo: .byte $AE,$AF,$B0,$CE,$CF,$D0
.segment "CODE"
