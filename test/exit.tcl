after time 8  { keymatrixdown 8 0x01; after time 0.3 { keymatrixup 8 0x01 } }
after time 14 { screenshot -raw $::env(OUT)/exit1.png }
after time 18 { exit }
