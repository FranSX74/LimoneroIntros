; ---------------------------------------------------------------------------
;  MSX screen 3 saver  -  efectos de texto estilo ttfx (Omarchy) para MSX
;  ROM de 16 KB en 4000h. Cualquier tecla sale a BASIC.
;  Ensamblar con N80 (Nestor80):  N80 src/saver.asm build/saver.rom
; ---------------------------------------------------------------------------

CHGMOD  equ 005Fh
WRTVDP  equ 0047h
SETWRT  equ 0053h
CHSNS   equ 009Ch
KILBUF  equ 0156h
JIFFY   equ 0FC9Eh

FB      equ 0C000h          ; framebuffer 1536 bytes, ya en orden de VRAM (2 px por byte)
FBH     equ 0C0h
LUT     equ 0C800h          ; tabla de 256 bytes: LUT[d+128] = d*k/64
LUTH    equ 0C8h
PARTS   equ 0D000h          ; particulas generadas en RAM (6 bytes c/u, max 1024, centinela 255)
XSEED   equ 0CA30h
V_TICK  equ 0CA01h
V_RLEN  equ 0CA02h
V_RFN   equ 0CA03h          ; word
V_LASTJ equ 0CA05h
V_SPS   equ 0CA06h          ; word
V_TMP   equ 0CA08h
V_LAST  equ 0CA09h
V_KEEP  equ 0CA0Ah          ; 1 = no limpiar el framebuffer (fase de mantenimiento)
V_MASK  equ 0CA0Bh          ; franjas de 8 lineas que toca este efecto (bit g = lineas 8g..8g+7)
V_PREVM equ 0CA0Ch          ; franjas del fotograma anterior
V_T0    equ 0CA0Dh          ; JIFFY al empezar la fase
V_LASTF equ 0CA0Eh          ; 1 = este es el ultimo fotograma de la fase
V_TBUF  equ 0CA70h          ; copia normalizada del texto (24 bytes: 8 amarillo + 16 blanco)
V_N1    equ 0CA90h
V_N2    equ 0CA91h
V_Y1    equ 0CA92h
V_Y2    equ 0CA93h
V_C1    equ 0CA94h
V_C2    equ 0CA95h
V_ROWS  equ 0CA96h
V_W     equ 0CA97h
V_X     equ 0CA98h
V_I     equ 0CA99h
V_ROW   equ 0CA9Ah
V_BITS  equ 0CA9Bh
V_COL   equ 0CA9Ch
V_PX    equ 0CA9Dh
V_PY    equ 0CA9Eh
V_C     equ 0CA9Fh
V_Y0    equ 0CAA0h
V_LP    equ 0CAA1h          ; word
V_GPTR  equ 0CAA3h          ; word
V_OUT   equ 0CAA5h          ; word
V_CNT   equ 0CAA7h          ; word
; --- efecto maquina de escribir (R_TYPE), calculadas una vez en SCANX
V_TH    equ 0CAB0h          ; y >= V_TH => pertenece a la linea 2 (255 = una sola linea)
V_XMIN1 equ 0CAB1h          ; (XMIN, XMAX) deben ir seguidos
V_XMAX1 equ 0CAB2h
V_XMIN2 equ 0CAB3h
V_XMAX2 equ 0CAB4h
V_TA    equ 0CAB5h          ; fin de la escritura de la linea 1 (ticks)
V_TB    equ 0CAB6h          ; fin del avance de linea = inicio de la linea 2
V_TC    equ 0CAB7h          ; fin de la escritura de la linea 2
V_F     equ 0CAB8h          ; filas que sube la linea 1 al hacer el retorno de carro (0 o 7)
V_OYT   equ 0CAB9h          ; desplazamiento total: de la fila inferior a la posicion final
V_TYLEN equ 0CABAh          ; duracion total del efecto
V_YT1   equ 0CABBh          ; fila superior de la primera linea (y de su cursor)
V_H1    equ 0CABCh          ; alto de la primera linea
V_YBOT  equ 0CABDh          ; ultima fila del bloque de texto ya centrado
V_W1    equ 0CABEh
V_W2    equ 0CABFh
V_U     equ 0CAC0h          ; filas subidas hasta ahora
V_OY    equ 0CAC1h          ; desplazamiento actual = OYT - U
V_HC1   equ 0CAC2h          ; columnas ya escritas de cada linea
V_HC2   equ 0CAC3h

        org 4000h
        db "AB"
        dw INIT,0,0,0
        ds 6

; Texto patcheable: 2 lineas de 8 caracteres (ASCII, relleno con espacios) en el offset 0x10
TXTAREA:
        include "text.inc"

; ---------------------------------------------------------------------------
INIT:
        ld a,3
        call CHGMOD             ; screen 3
        ld b,1
        ld c,7
        call WRTVDP             ; borde/fondo negro
        ld a,(JIFFY)
        or 1
        ld l,a
        ld h,0A5h
        ld (XSEED),hl
        ld a,(JIFFY)
        ld (V_LASTJ),a
        call GENTEXT            ; genera las particulas del texto en RAM
        call SCANX              ; medidas del texto para la maquina de escribir
        ld a,3Fh
        ld (V_PREVM),a          ; primer fotograma: limpiar y volcar todo
        xor a
        ld (V_KEEP),a

MAIN:
        call rnd8
        and 15
        cp 9
        jr nc,MAIN              ; 9 efectos de construccion
        ld hl,V_LAST
        cp (hl)
        jr z,MAIN               ; no repetir el efecto anterior
        ld (hl),a
        ld e,a
        ld d,0
        ld hl,TLEN
        add hl,de
        ld a,(hl)               ; longitud de la fase de construccion
        or a
        jr nz,mn_l
        ld a,(V_TYLEN)          ; 0 = depende del texto (maquina de escribir)
mn_l:   push af
        ld hl,EMASK
        add hl,de
        ld a,(hl)
        ld (V_MASK),a
        ld a,e
        ld hl,DISP
        call getfn              ; HL = rutina de render
        pop af
        call RUN                ; construir el logo

        ld a,1
        ld (V_KEEP),a           ; el logo ya esta completo en el framebuffer
        ld a,0Ch
        ld (V_MASK),a           ; el texto solo ocupa las franjas 2 y 3
        ld hl,R_HOLD
        ld a,70
        call RUN                ; mantener con destello
        xor a
        ld (V_KEEP),a
        ld a,3Fh
        ld (V_PREVM),a          ; la proxima fase debe limpiar todo

        call rnd8
        and 3
        cp 3
        jr c,out1
        xor a
out1:   ld e,a
        ld d,0
        ld hl,OLEN
        add hl,de
        ld a,(hl)
        push af
        ld hl,OMASK
        add hl,de
        ld a,(hl)
        ld (V_MASK),a
        ld a,e
        ld hl,ODISP
        call getfn
        pop af
        call RUN                ; deshacer

        xor a
        ld (V_MASK),a
        ld hl,R_NONE
        ld a,10
        call RUN                ; pausa en negro
        jp MAIN

; A = indice, HL = tabla de words -> HL = word[A]
getfn:  add a,a
        ld e,a
        ld d,0
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        ex de,hl
        ret

; ---------------------------------------------------------------------------
;  RUN: HL = rutina de render, A = numero de fotogramas
; ---------------------------------------------------------------------------
RUN:
        ld (V_RFN),hl
        ld (V_RLEN),a
        ld a,(JIFFY)
        ld (V_T0),a
        xor a
        ld (V_LASTF),a
run1:   ld a,(JIFFY)            ; tick = fotogramas "ideales" transcurridos (1 cada 2 interrupciones):
        ld hl,V_T0              ; el efecto dura lo mismo aunque el dibujo sea mas lento
        sub (hl)
        srl a
        ld hl,V_RLEN
        cp (hl)
        jr c,run2
        ld a,(hl)               ; fin de la fase: ultimo fotograma con tick = longitud
        ld hl,V_LASTF
        ld (hl),1
run2:   ld (V_TICK),a
        ld a,(V_KEEP)
        or a
        call z,CLEAR
        ld hl,(V_RFN)
        call callhl
        call BLIT
        call CHSNS
        jp nz,EXIT              ; hay tecla en el buffer
        ld a,(V_LASTF)
        or a
        ret nz
        call PACE
        jr run1

callhl: jp (hl)

EXIT:
        call KILBUF
        ld a,(0F3AEh)           ; LINL40: si el BIOS aun no lo ha fijado, 39 columnas
        or a
        jr nz,exit1
        ld a,39
        ld (0F3AEh),a
exit1:
        xor a
        call CHGMOD             ; vuelve a screen 0
        pop hl                  ; descarta el retorno de RUN
        ret                     ; vuelve al BIOS (arranque normal)


; ---------------------------------------------------------------------------
;  GENTEXT: lee TXTAREA (linea 1 = 8 caracteres en amarillo 7 px de ancho variable,
;  linea 2 = 16 caracteres en blanco 3x5) y genera las particulas en PARTS.
;  TXTAREA+24 = color de la linea 1, TXTAREA+25 = color de la linea 2.
; ---------------------------------------------------------------------------
GENTEXT:
        ld hl,TXTAREA
        ld de,V_TBUF
        ld b,24
gt1:    ld a,(hl)
        inc hl
        cp 'a'
        jr c,gt2
        cp 'z'+1
        jr nc,gt2
        and 0DFh                ; a mayusculas
gt2:    ld (de),a
        inc de
        djnz gt1
        ld a,(TXTAREA+24)
        ld (V_C1),a
        ld a,(TXTAREA+25)
        ld (V_C2),a
        ld hl,V_TBUF
        ld b,8
        call TRIMLEN
        ld (V_N1),a
        ld hl,V_TBUF+8
        ld b,16
        call TRIMLEN
        ld (V_N2),a
        ld hl,V_N1
        ld a,(V_N2)
        or (hl)
        jr nz,gt3
        ld hl,DEFTXT            ; todo vacio: "MSX"
        ld de,V_TBUF
        ld bc,3
        ldir
        ld a,3
        ld (V_N1),a
gt3:    ld a,17                 ; dos lineas: 7 + 2 + 5 = 14 filas, centradas
        ld (V_Y1),a
        ld a,26
        ld (V_Y2),a
        ld a,(V_N2)
        or a
        jr nz,gt4
        ld a,20                 ; solo amarillo
        ld (V_Y1),a
gt4:    ld a,(V_N1)
        or a
        jr nz,gt5
        ld a,21                 ; solo blanco
        ld (V_Y2),a
gt5:    ld hl,PARTS
        ld (V_OUT),hl
        ld (hl),255
        ld hl,0
        ld (V_CNT),hl
        ; ---- linea 1 (amarilla, ancho proporcional)
        ld a,(V_N1)
        or a
        jr z,gt_w
        call YWIDTH
        ld b,a
        ld a,64
        sub b
        srl a
        ld (V_X),a
        ld a,(V_Y1)
        ld (V_Y0),a
        ld a,(V_C1)
        ld (V_COL),a
        ld a,7
        ld (V_ROWS),a
        ld hl,V_TBUF
        ld (V_LP),hl
        ld a,(V_N1)
        ld (V_I),a
yl1:    ld hl,(V_LP)
        ld a,(hl)
        inc hl
        ld (V_LP),hl
        call GLYPHIDX
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl               ; 8*idx
        ld de,FONTY
        add hl,de
        ld a,(hl)               ; ancho del glifo
        ld (V_W),a
        inc hl
        ld (V_GPTR),hl
        call EMITGLYPH
        ld a,(V_W)
        inc a
        ld hl,V_X
        add a,(hl)
        ld (hl),a
        ld hl,V_I
        dec (hl)
        jr nz,yl1
        ; ---- linea 2 (blanca 3x5, ancho fijo)
gt_w:   ld a,(V_N2)
        or a
        ret z
        add a,a
        add a,a
        dec a                   ; 4*n - 1
        ld b,a
        ld a,64
        sub b
        srl a
        ld (V_X),a
        ld a,(V_Y2)
        ld (V_Y0),a
        ld a,(V_C2)
        ld (V_COL),a
        ld a,5
        ld (V_ROWS),a
        ld a,3
        ld (V_W),a
        ld hl,V_TBUF+8
        ld (V_LP),hl
        ld a,(V_N2)
        ld (V_I),a
wl1:    ld hl,(V_LP)
        ld a,(hl)
        inc hl
        ld (V_LP),hl
        call GLYPHIDX
        ld c,a
        add a,a
        add a,a
        add a,c                 ; 5*idx
        ld e,a
        ld d,0
        ld hl,FONTW
        add hl,de
        ld (V_GPTR),hl
        call EMITGLYPH
        ld a,(V_X)
        add a,4
        ld (V_X),a
        ld hl,V_I
        dec (hl)
        jr nz,wl1
        ret

DEFTXT: db "MSX"

; HL = inicio de linea, B = longitud -> A = longitud sin espacios/ceros finales
TRIMLEN:
        ld e,b
        ld d,0
        add hl,de
        dec hl
tl1:    ld a,(hl)
        cp ' '
        jr z,tl2
        or a
        jr nz,tl3
tl2:    dec hl
        djnz tl1
tl3:    ld a,b
        ret

; A = caracter -> A = indice en CHARS (36 = espacio si no se conoce)
GLYPHIDX:
        ld hl,CHARS
        ld bc,45
        cpir
        ld a,36
        ret nz
        ld a,44
        sub c
        ret

; ancho en pixeles de la linea amarilla (V_TBUF, V_N1 letras, 1 px de separacion)
YWIDTH: ld hl,V_TBUF
        ld a,(V_N1)
        ld b,a
        ld d,0FFh
yw1:    push bc
        push de
        push hl
        ld a,(hl)
        call GLYPHIDX
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,FONTY
        add hl,de
        ld a,(hl)
        pop hl
        pop de
        pop bc
        inc a
        add a,d
        ld d,a
        inc hl
        djnz yw1
        ld a,d
        ret

; Dibuja un glifo: V_GPTR = filas (1 byte c/u, bit 7 = pixel izquierdo), V_ROWS filas,
; V_W columnas, en (V_X, V_Y0) con color V_COL
EMITGLYPH:
        xor a
        ld (V_ROW),a
        ld a,(V_Y0)
        ld (V_PY),a
gg1:    ld hl,(V_GPTR)
        ld a,(V_ROW)
        ld e,a
        ld d,0
        add hl,de
        ld a,(hl)
        ld (V_BITS),a
        ld a,(V_X)
        ld (V_PX),a
        ld a,(V_W)
        ld (V_C),a
gg2:    ld a,(V_BITS)
        add a,a
        ld (V_BITS),a
        jr nc,gg3
        ld a,(V_PX)
        ld b,a
        ld a,(V_PY)
        ld c,a
        ld a,(V_COL)
        ld e,a
        call EMIT
gg3:    ld hl,V_PX
        inc (hl)
        ld hl,V_C
        dec (hl)
        jr nz,gg2
        ld hl,V_PY
        inc (hl)
        ld hl,V_ROW
        inc (hl)
        ld a,(V_ROWS)
        cp (hl)
        jr nz,gg1
        ret

; B = x, C = y, E = color -> anade una particula (rx, ry, dly aleatorios), max 1024
EMIT:   ld hl,(V_CNT)
        ld a,h
        cp 4
        ret nc
        inc hl
        ld (V_CNT),hl
        ld hl,(V_OUT)
        ld (hl),b
        inc hl
        ld (hl),c
        inc hl
        ld (hl),e
        inc hl
        push hl
        call xrnd16
        ld a,l
        and 63
        ld d,a                  ; rx
        ld a,h
        and 63
        ld e,a                  ; dly
        call xrnd16
        ld a,l
        and 63
        cp 48
        jr c,em1
        sub 48
em1:    ld c,a                  ; ry
        pop hl
        ld (hl),d
        inc hl
        ld (hl),c
        inc hl
        ld (hl),e
        inc hl
        ld (hl),255             ; centinela
        ld (V_OUT),hl
        ret

; ---------------------------------------------------------------------------
;  Utilidades
; ---------------------------------------------------------------------------
; xorshift de 16 bits: devuelve HL aleatorio (clobbera A)
xrnd16: ld hl,(XSEED)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (XSEED),hl
        ret

rnd8:   push hl
        call xrnd16
        ld a,l
        pop hl
        ret

; limpia solo las franjas que estaban sucias en el fotograma anterior (V_PREVM)
CLEAR:  di
        ld (V_SPS),sp
        ld a,(V_PREVM)
        ld e,a
        ld bc,0
        ld hl,FB+256            ; fin de la franja 0
        ld d,6
cl1:    srl e
        jr nc,cl3
        ld sp,hl
        ld a,32
cl2:    push bc
        push bc
        push bc
        push bc
        dec a
        jr nz,cl2
cl3:    inc h
        dec d
        jr nz,cl1
        ld sp,(V_SPS)
        ei
        ret

; vuelca a la VRAM las franjas (V_MASK | V_PREVM); despues V_PREVM = V_MASK
BLIT:   di
        ld a,(V_MASK)
        ld hl,V_PREVM
        or (hl)
        ld e,a
        ld a,(V_MASK)
        ld (hl),a
        ld d,0
bl_g:   srl e
        jr nc,bl_n
        ld h,d
        ld l,0
        call SETWRT             ; direccion de VRAM = franja * 256
        ld a,d
        add a,FBH
        ld h,a
        ld l,0
        ld c,98h
        ld b,0
bl_1:   outi
        nop                     ; el TMS9918 (MSX1) necesita >= 29 ciclos entre escrituras
        jp nz,bl_1
bl_n:   inc d
        ld a,d
        cp 6
        jr nz,bl_g
        ei
        ret

; espera a que cambie JIFFY desde el ultimo fotograma (sincroniza con el refresco)
PACE:   ld a,(V_LASTJ)
        ld c,a
pc1:    ld a,(JIFFY)
        cp c
        jr nz,pc2
        halt
        jr pc1
pc2:    ld (V_LASTJ),a
        ret

; B = x (0..63), C = y (0..47), E = color (0..15). Fuera de pantalla: no hace nada.
PLOT:   ld a,b
        cp 64
        ret nc
        ld a,c
        cp 48
        ret nc
PLOTF:  ld a,c                  ; (PLOTF = sin comprobar limites)
        rrca
        rrca
        rrca
        and 1Fh
        add a,FBH
        ld h,a                  ; H = FBH + y/8
        ld a,b
        and 0FEh
        add a,a
        add a,a
        ld l,a                  ; L = (x/2)*8
        ld a,c
        and 7
        or l
        ld l,a                  ; + y mod 8
        bit 0,b
        jr nz,plot_odd
        ld a,(hl)
        and 0Fh
        ld d,a
        ld a,e
        add a,a
        add a,a
        add a,a
        add a,a
        or d
        ld (hl),a
        ret
plot_odd:
        ld a,(hl)
        and 0F0h
        or e
        ld (hl),a
        ret

; A = k (0..64).  LUT[i] = ((i-128)*k)/64  (division con suelo)
BUILDLUT:
        ld c,a
        add a,a
        ld d,a
        ld e,0                  ; DE = k*512
        ld hl,0
        or a
        sbc hl,de               ; HL = -k*512  (valor 8.8 de d=-128)
        ld a,c
        ld e,a
        ld d,0
        sla e
        rl d
        sla e
        rl d                    ; DE = k*4  (paso por unidad de d)
        ld bc,LUT
bl1:    ld a,h
        ld (bc),a
        inc c
        add hl,de
        jr nz,bl1
        ret

; A = desplazamiento vertical maximo D (filas): marca las franjas de las filas 16-D .. 31+D
SETMASKD:
        ld c,a
        ld a,16
        sub c
        jr nc,sm1
        xor a
sm1:    rrca
        rrca
        rrca
        and 1Fh                 ; franja inferior
        ld e,a
        ld d,0
        ld hl,LOMASK
        add hl,de
        ld b,(hl)               ; franjas >= la inferior
        ld a,31
        add a,c
        jr nc,sm2
        ld a,255
sm2:    cp 48
        jr c,sm3
        ld a,47
sm3:    rrca
        rrca
        rrca
        and 1Fh                 ; franja superior
        ld e,a
        ld hl,HIMASK
        add hl,de
        ld a,(hl)
        and b
        ld (V_MASK),a
        ret
LOMASK: db 63,62,60,56,48,32
HIMASK: db 1,3,7,15,31,63

R_NONE: ret

; ---------------------------------------------------------------------------
;  Efecto 0: "decrypt" - ruido verde que se fija en el color final
; ---------------------------------------------------------------------------
R_DECRYPT:
        ld ix,PARTS
dc1:    ld b,(ix+0)
        ld a,b
        inc a
        ret z
        ld c,(ix+1)
        ld a,(ix+5)
        add a,10                ; instante en que se fija
        ld hl,V_TICK
        cp (hl)
        jr c,dc_final
        jr z,dc_final
        ld a,(ix+3)
        add a,(hl)              ; ruido barato: (azar fijo + fotograma) mod 4
        and 3
        ld e,a
        ld d,0
        ld hl,GREENS
        add hl,de
        ld e,(hl)
        jr dc_plot
dc_final:
        ld e,(ix+2)
dc_plot:
        call PLOTF
        ld de,6
        add ix,de
        jr dc1

R_RAIN:
        ld a,(V_TICK)
        cp 60
        jr c,rn0
        ld a,60
rn0:    add a,a
        ld (V_TMP),a            ; 2*t
        ld c,a
        ld a,87
        sub c
        jr nc,rnx
        xor a
rnx:    call SETMASKD           ; hasta 87-2t filas por encima del texto
        ld ix,PARTS
rn1:    ld a,(ix+0)
        inc a
        ret z
        ld b,(ix+0)
        ld a,(ix+5)
        add a,24
        ld hl,V_TMP
        sub (hl)
        jr nc,rn2
        xor a
rn2:    ld d,a                  ; distancia que le queda por caer
        ld a,(ix+1)
        sub d
        ld c,a                  ; y = ty - resto
        ld e,(ix+2)
        ld a,d
        or a
        jr z,rn3
        ld e,15                 ; cayendo = blanco
rn3:    call PLOT
        ld de,6
        add ix,de
        jr rn1

; ---------------------------------------------------------------------------
;  Efecto 2: enjambre - los pixeles vuelan desde posiciones al azar
; ---------------------------------------------------------------------------
R_CONVERGE:
        ld a,(V_TICK)
        ld c,a
        ld a,64
        sub c
        jr nc,cv0
        xor a
cv0:    push af
        srl a
        inc a
        call SETMASKD           ; desplazamiento maximo ~ k/2 filas
        pop af
        call BUILDLUT
        ld ix,PARTS
cv1:    ld b,(ix+0)
        ld a,b
        inc a
        ret z
        ld c,(ix+1)
        ld e,(ix+2)
        ld h,LUTH
        ld a,(ix+3)
        sub b
        add a,128
        ld l,a
        ld a,(hl)
        add a,b
        ld b,a                  ; x
        ld a,(ix+4)
        sub c
        add a,128
        ld l,a
        ld a,(hl)
        add a,c
        ld c,a                  ; y
        call PLOTF
        ld de,6
        add ix,de
        jr cv1

R_SWEEP:
        ld ix,PARTS
sw1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+1)
        rrca
        rrca
        and 3Fh
        add a,(ix+0)            ; clave = x + y/4
        ld d,a
        ld a,(V_TICK)
        add a,a
        sub d
        jr c,sw_next
        jr z,sw_next
        call glowplot
sw_next:
        ld de,6
        add ix,de
        jr sw1

; ---------------------------------------------------------------------------
;  Mantener: logo completo con destellos que lo recorren
; ---------------------------------------------------------------------------
R_HOLD:
        ld ix,PARTS
hd1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+1)
        srl a
        add a,(ix+0)            ; x + y/2
        ld hl,V_TICK
        sub (hl)
        sub (hl)
        add a,2
        and 31
        cp 5
        jr nc,hd_next           ; ni entra ni sale del destello
        ld e,15
        cp 2
        jr nc,hd2
        ld e,(ix+2)             ; sale del destello: color final
hd2:    ld b,(ix+0)
        ld c,(ix+1)
        call PLOTF
hd_next:
        ld de,6
        add ix,de
        jr hd1

; ---------------------------------------------------------------------------
;  Explosion: los pixeles salen disparados desde el centro y se apagan
; ---------------------------------------------------------------------------
R_EXPLODE:
        ld a,(V_TICK)
        cp 60
        jr c,ex0
        ld a,59
ex0:    push af
        ld c,a
        srl a
        srl a
        srl a
        ld b,a                  ; k/8
        ld a,c
        srl a
        add a,b
        inc a                   ; D = k/2 + k/8 + 1
        call SETMASKD
        pop af
        call BUILDLUT
        ld ix,PARTS
ex1:    ld b,(ix+0)
        ld a,b
        inc a
        ret z
        ld a,(ix+5)
        srl a
        add a,28                ; vida: 28..59 fotogramas
        ld hl,V_TICK
        cp (hl)
        jr c,ex_next            ; ya murio
        ld a,b
        sub 32
        add a,a
        add a,(ix+3)
        sub 32                  ; vx = 2*(x-32) + (rx-32)
        add a,128
        ld l,a
        ld h,LUTH
        ld a,(hl)
        add a,b
        ld b,a
        ld c,(ix+1)
        ld a,c
        sub 24
        add a,a
        add a,(ix+4)
        sub 24                  ; vy = 2*(y-24) + (ry-24)
        add a,128
        ld l,a
        ld a,(hl)
        add a,c
        ld c,a
        ld e,(ix+2)
        ld a,(V_TICK)
        cp 30
        jr c,ex2
        ld e,14                 ; ya enfriandose: gris
ex2:    call PLOT
ex_next:
        ld de,6
        add ix,de
        jr ex1

; age (1..) en A, particula en IX: color de brillo y dibuja
glowplot:
        cp 10
        jr nc,gp_f
        ld e,a
        ld d,0
        ld hl,GLOW
        add hl,de
        ld e,(hl)
        jr gp_p
gp_f:   ld e,(ix+2)
gp_p:   ld b,(ix+0)
        ld c,(ix+1)
        jp PLOTF

; ---------------------------------------------------------------------------
;  Efecto 4: bandas que se deslizan en sentidos opuestos
; ---------------------------------------------------------------------------
R_SLIDE:
        ld ix,PARTS
sl1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(V_TICK)
        add a,a
        ld d,a
        ld a,(ix+1)
        add a,30
        sub d
        jr nc,sl2
        xor a
sl2:    ld d,a                  ; desplazamiento que le queda
        bit 1,(ix+1)
        ld a,(ix+0)
        jr z,sl3
        sub d                   ; banda hacia la derecha
        jr sl4
sl3:    add a,d                 ; banda hacia la izquierda
sl4:    ld b,a
        ld c,(ix+1)
        ld e,(ix+2)
        call PLOT
        ld de,6
        add ix,de
        jr sl1

; ---------------------------------------------------------------------------
;  Efecto 5: onda que se va amortiguando
; ---------------------------------------------------------------------------
R_WAVE:
        ld a,(V_TICK)
        ld c,a
        ld a,40
        sub c
        jr nc,wv0
        xor a
wv0:    push af
        call SETMASKD           ; amplitud <= k filas
        pop af
        call BUILDLUT
        ld ix,PARTS
wv1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(V_TICK)
        ld e,a
        add a,e
        add a,e                 ; 3*t
        add a,(ix+0)
        add a,(ix+0)            ; + 2*x
        and 63
        ld e,a
        ld d,0
        ld hl,SINT
        add hl,de
        ld a,(hl)
        add a,128
        ld l,a
        ld h,LUTH
        ld a,(hl)
        add a,(ix+1)
        ld c,a
        ld b,(ix+0)
        ld e,(ix+2)
        call PLOT
        ld de,6
        add ix,de
        jr wv1

; ---------------------------------------------------------------------------
;  Efecto 6: expansion radial (rombo) desde el centro con borde brillante
; ---------------------------------------------------------------------------
R_EXPAND:
        ld ix,PARTS
ep1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+0)
        sub 32
        jr nc,ep2
        neg
ep2:    ld d,a
        ld a,(ix+1)
        sub 24
        jr nc,ep3
        neg
ep3:    add a,d
        ld d,a                  ; distancia al centro
        ld a,(V_TICK)
        add a,a
        sub d
        jr c,ep_next
        jr z,ep_next
        call glowplot
ep_next:
        ld de,6
        add ix,de
        jr ep1

; ---------------------------------------------------------------------------
;  Efecto 7: subida - como la lluvia pero desde abajo
; ---------------------------------------------------------------------------
R_RISE:
        ld a,(V_TICK)
        cp 60
        jr c,ri0
        ld a,60
ri0:    add a,a
        ld (V_TMP),a
        ld c,a
        ld a,87
        sub c
        jr nc,rix
        xor a
rix:    call SETMASKD
        ld ix,PARTS
ri1:    ld a,(ix+0)
        inc a
        ret z
        ld b,(ix+0)
        ld a,(ix+5)
        add a,24
        ld hl,V_TMP
        sub (hl)
        jr nc,ri2
        xor a
ri2:    ld d,a
        ld a,(ix+1)
        add a,d
        ld c,a                  ; y = ty + resto
        ld e,(ix+2)
        ld a,d
        or a
        jr z,ri3
        ld e,14                 ; subiendo = gris
ri3:    call PLOT
        ld de,6
        add ix,de
        jr ri1

; ---------------------------------------------------------------------------
;  Salida: caida con gravedad escalonada
; ---------------------------------------------------------------------------
R_FALL:
        ld a,(V_TICK)
        cp 63
        jr c,fx0
        ld a,63
fx0:    ld e,a
        ld d,0
        ld hl,QUAD
        add hl,de
        ld a,(hl)
        call SETMASKD           ; caida maxima = QUAD[t]
        ld ix,PARTS
fa1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+5)
        srl a
        ld d,a
        ld a,(V_TICK)
        sub d
        jr nc,fa2
        xor a
fa2:    cp 63
        jr c,fa3
        ld a,63
fa3:    ld e,a
        ld d,0
        ld hl,QUAD
        add hl,de
        ld a,(hl)
        add a,(ix+1)
        ld c,a
        ld b,(ix+0)
        ld e,(ix+2)
        call PLOT
        ld de,6
        add ix,de
        jr fa1

; ---------------------------------------------------------------------------
;  Salida: disolucion con destello blanco al apagarse cada pixel
; ---------------------------------------------------------------------------
R_DISSOLVE:
        ld ix,PARTS
di1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+5)
        add a,4
        ld hl,V_TICK
        cp (hl)
        jr c,di_next            ; ya se apago
        ld a,(ix+5)
        cp (hl)
        ld e,(ix+2)
        jr nc,di2
        ld e,15
di2:    ld b,(ix+0)
        ld c,(ix+1)
        call PLOTF
di_next:
        ld de,6
        add ix,de
        jr di1

; ---------------------------------------------------------------------------
;  Maquina de escribir (efecto "print" de ttfx): la primera linea se escribe abajo,
;  el retorno de carro la sube, se escribe la segunda abajo y todo sube a su sitio.
; ---------------------------------------------------------------------------
; Medidas del texto (una vez): reparto en lineas, anchos, tiempos
SCANX:
        ld a,255
        ld (V_TH),a
        ld a,(V_N1)
        or a
        jr z,sx0
        ld a,(V_N2)
        or a
        jr z,sx0
        ld a,24                 ; dos lineas: la 2 empieza en y=26
        ld (V_TH),a
sx0:    ld a,255
        ld (V_XMIN1),a
        ld (V_XMIN2),a
        xor a
        ld (V_XMAX1),a
        ld (V_XMAX2),a
        ld ix,PARTS
sx1:    ld a,(ix+0)
        inc a
        jr z,sx4
        ld b,(ix+0)
        ld a,(ix+1)
        ld hl,V_TH
        cp (hl)
        ld hl,V_XMIN1
        jr c,sx2
        ld hl,V_XMIN2
sx2:    call UPDX
        ld de,6
        add ix,de
        jr sx1
sx4:    ld a,(V_XMAX1)
        ld hl,V_XMIN1
        call WIDTHF
        ld (V_W1),a
        ld a,(V_XMAX2)
        ld hl,V_XMIN2
        call WIDTHF
        ld (V_W2),a
        ld a,(V_TH)
        cp 24
        ld a,7                  ; retorno de carro: 5 filas de la linea 2 + 2 de separacion
        jr z,sx5
        xor a
sx5:    ld (V_F),a
        ld a,(V_W1)
        srl a
        inc a                   ; 2 columnas por tick
        ld (V_TA),a
        ld hl,V_F
        add a,(hl)
        ld (V_TB),a
        ld a,(V_W2)
        srl a
        inc a
        ld hl,V_TB
        add a,(hl)
        ld (V_TC),a
        ld a,(V_N1)
        or a
        jr z,sx6
        ld a,(V_Y1)
        ld (V_YT1),a
        ld a,7
        ld (V_H1),a
        ld a,(V_N2)
        or a
        jr z,sx7
        ld a,(V_Y2)
        add a,4
        jr sx8
sx7:    ld a,(V_Y1)
        add a,6
        jr sx8
sx6:    ld a,(V_Y2)             ; solo blanco
        ld (V_YT1),a
        ld a,5
        ld (V_H1),a
        ld a,(V_Y2)
        add a,4
sx8:    ld (V_YBOT),a
        ld a,(V_YT1)
        ld hl,V_H1
        add a,(hl)
        dec a                   ; ultima fila de la primera linea
        ld b,a
        ld a,47
        sub b
        ld (V_OYT),a            ; lo que hay que subirla para dejarla en su sitio
        ld a,(V_TC)
        ld hl,V_OYT
        add a,(hl)
        ld hl,V_F
        sub (hl)
        ld (V_TYLEN),a
        ret

; HL -> (min,max): actualiza con B
UPDX:   ld a,b
        cp (hl)
        jr nc,ux1
        ld (hl),b
ux1:    inc hl
        ld a,(hl)
        cp b
        jr nc,ux2
        ld (hl),b
ux2:    ret

; A = max, (HL) = min -> A = max-min+1 (0 si la linea esta vacia)
WIDTHF: sub (hl)
        jr c,wf0
        inc a
        ret
wf0:    xor a
        ret

R_TYPE:
        ld a,(V_TICK)
        ld b,a                  ; B = tick
        ld hl,V_TA
        sub (hl)
        jr c,ty_u0              ; escribiendo la linea 1: no sube
        ld hl,V_F
        cp (hl)
        jr c,ty_us              ; retorno de carro: u = t-TA
        ld a,b
        ld hl,V_TC
        sub (hl)
        jr c,ty_uF              ; escribiendo la linea 2
        ld hl,V_F
        add a,(hl)              ; subida final
        ld hl,V_OYT
        cp (hl)
        jr c,ty_us
        ld a,(hl)
        jr ty_us
ty_uF:  ld a,(V_F)
        jr ty_us
ty_u0:  xor a
ty_us:  ld (V_U),a
        ld c,a
        ld a,(V_OYT)
        sub c
        ld (V_OY),a
        ; columnas escritas de cada linea
        ld a,b
        ld hl,V_TA
        cp (hl)
        jr c,h1
        ld a,(hl)
h1:     add a,a
        ld (V_HC1),a
        ld a,b
        ld hl,V_TB
        sub (hl)
        jr nc,h2
        xor a
        jr h3
h2:     ld c,a
        ld a,(V_TC)
        sub (hl)
        ld d,a
        ld a,c
        cp d
        jr c,h3
        ld a,d
h3:     add a,a
        ld (V_HC2),a
        ; franjas que ocupa el texto en este fotograma
        ld a,(V_YT1)
        ld hl,V_OY
        add a,(hl)
        rrca
        rrca
        rrca
        and 1Fh
        ld e,a
        ld d,0
        ld hl,LOMASK
        add hl,de
        ld c,(hl)
        ld a,(V_YBOT)
        ld hl,V_OY
        add a,(hl)
        cp 48
        jr c,m1
        ld a,47
m1:     rrca
        rrca
        rrca
        and 1Fh
        ld e,a
        ld hl,HIMASK
        add hl,de
        ld a,(hl)
        and c
        ld (V_MASK),a
        ; pixeles ya escritos
        ld ix,PARTS
tp1:    ld a,(ix+0)
        inc a
        jr z,tp_head
        ld a,(ix+1)
        ld hl,V_TH
        cp (hl)
        jr nc,tp_c2
        ld a,(ix+0)
        ld hl,V_XMIN1
        sub (hl)
        ld hl,V_HC1
        cp (hl)
        jr nc,tp_next
        jr tp_pl
tp_c2:  ld a,(ix+0)
        ld hl,V_XMIN2
        sub (hl)
        ld hl,V_HC2
        cp (hl)
        jr nc,tp_next
tp_pl:  ld a,(ix+1)
        ld hl,V_OY
        add a,(hl)
        ld c,a
        ld b,(ix+0)
        ld e,(ix+2)
        call PLOTF
tp_next:
        ld de,6
        add ix,de
        jr tp1
        ; cabezal de impresion: barra blanca en la columna que se va a escribir
tp_head:
        ld a,(V_TICK)
        ld hl,V_TA
        cp (hl)
        jr nc,tp_h2
        ld a,(V_HC1)
        ld hl,V_W1
        cp (hl)
        ret nc
        ld hl,V_XMIN1
        add a,(hl)
        ld b,a
        ld a,(V_YT1)
        ld hl,V_OY
        add a,(hl)
        ld c,a
        ld a,(V_H1)
        jr BAR
tp_h2:  ld a,(V_TICK)
        ld hl,V_TB
        cp (hl)
        ret c
        ld hl,V_TC
        cp (hl)
        ret nc
        ld a,(V_HC2)
        ld hl,V_W2
        cp (hl)
        ret nc
        ld hl,V_XMIN2
        add a,(hl)
        ld b,a
        ld a,(V_Y2)
        ld hl,V_OY
        add a,(hl)
        ld c,a
        ld a,5
BAR:    push af
        push bc
        ld e,15
        call PLOTF
        pop bc
        pop af
        inc c
        dec a
        jr nz,BAR
        ret

; ---------------------------------------------------------------------------
;  Tablas
; ---------------------------------------------------------------------------
DISP:   dw R_DECRYPT,R_RAIN,R_CONVERGE,R_SWEEP,R_SLIDE,R_WAVE,R_EXPAND,R_RISE,R_TYPE
TLEN:   db 80,56,72,46,46,56,36,56,0
ODISP:  dw R_EXPLODE,R_FALL,R_DISSOLVE
OLEN:   db 64,66,70
; franjas de 8 lineas que toca cada efecto (bit g = lineas 8g..8g+7; el texto cabe en las franjas 2 y 3)
EMASK:  db 0Ch,3Fh,3Fh,0Ch,0Ch,3Fh,0Ch,3Fh,3Fh
OMASK:  db 3Fh,3Fh,0Ch
GREENS: db 12,3,2,15
GLOW:   db 0,15,15,11,11,7,7,5,5,4

        include "data.inc"

        ds 4000h+4000h-$        ; relleno hasta 16 KB
