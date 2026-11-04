# capturas a distintos instantes tras el arranque
set ::t0 0
proc shot {name} { screenshot -raw $::env(OUT)/$name.png }
after time 6  { shot a1 }
after time 9  { shot a2 }
after time 12 { shot a3 }
after time 15 { shot a4 }
after time 18 { shot a5 }
after time 24 { shot a6 }
after time 30 { exit }
