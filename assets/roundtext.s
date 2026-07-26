; ラウンド画面のセリフ + 顔データ (roundface_gen.py 生成 / かなは美咲フォント)
.segment "RODATA"
round_dlg0:
    .byte $EC,$E7,$E5,$F3,$F8,$F1,$01,$E8,$EF,$E2,$FE,$FF,$F3,$02,$E8,$EF,$E2,$FB,$01,$E5,$EE,$F7,$F0,$F6,$EC,$FA,$81,$00
round_dlg1:
    .byte $E8,$EF,$E2,$FB,$01,$E9,$E3,$F2,$E3,$F4,$02,$E5,$E4,$F0,$F6,$EC,$FA,$81,$00
round_dlg2:
    .byte $ED,$E3,$F9,$01,$E9,$E3,$F2,$E3,$E9,$ED,$E6,$02,$EB,$F5,$F0,$F9,$81,$00
round_dlg3:
    .byte $EF,$F9,$E2,$01,$E8,$EF,$E2,$FB,$02,$E5,$FD,$EA,$FA,$FC,$8E,$8E,$81,$00
round_dlg_lo: .byte <round_dlg0,<round_dlg1,<round_dlg2,<round_dlg3
round_dlg_hi: .byte >round_dlg0,>round_dlg1,>round_dlg2,>round_dlg3
round_face_ids:
    .byte $D0,$D1,$D2,$D3
    .byte $D4,$D5,$D6,$D7
    .byte $D8,$D9,$DA,$DB
ROUND_EYE_N = 6
round_eye_open:   .byte $D5,$D6,$D7,$D9,$DA,$DB
round_eye_closed: .byte $DC,$DD,$DE,$DF,$E0,$E1
round_eye_ahi: .byte $20,$20,$20,$20,$20,$20
round_eye_alo: .byte $A7,$A8,$A9,$C7,$C8,$C9
ROUND_FACE_ATTR1 = $00
ROUND_FACE_ATTR2 = $00
.segment "CODE"
; 顔ウィンドウ属性コピー用: 属性行内オフセット (行0-3 x 列5-7)
round_attr_ofs:
    .byte 0,1,2, 8,9,10, 16,17,18, 24,25,26
pause_txt:
    .byte $B0,$A1,$B5,$B3,$A5,$00   ; "PAUSE"
