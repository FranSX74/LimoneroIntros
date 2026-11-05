; ---------------------------------------------------------------------------
;  LIMONERO  -  version "limonero": arbol + logo con efecto maquina de escribir (screen 3)
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
BG      equ 0E800h          ; escena estatica (arbol + logo ya fijado), mismo formato que FB
BGH     equ 0E8h
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
; --- efecto maquina de escribir (R_TYPE) y salida por arriba (R_SCROLLUP); SCANX las calcula una vez
V_TH    equ 0CAB0h          ; y >= V_TH => pertenece a la linea 2 (255 = una sola linea)
V_XMIN1 equ 0CAB1h          ; (XMIN, XMAX) deben ir seguidos
V_XMAX1 equ 0CAB2h
V_XMIN2 equ 0CAB3h
V_XMAX2 equ 0CAB4h
V_XB    equ 0CAB5h          ; columna izquierda del bloque de texto
V_P     equ 0CAB6h          ; ticks que tarda el cabezal en recorrer una fila
V_NR    equ 0CAB7h          ; filas de pixeles del bloque (14 con dos lineas)
V_MT    equ 0CAB8h          ; subidas totales hasta quedar centrado (47 - fila superior)
V_TYLEN equ 0CAB9h          ; duracion de la escritura
V_SLEN  equ 0CABAh          ; duracion de la salida por arriba
V_YT1   equ 0CABBh          ; fila superior del bloque
V_YBOT  equ 0CABDh          ; fila inferior del bloque
V_J     equ 0CAC0h          ; fila que se esta imprimiendo
V_M     equ 0CAC1h          ; retornos de carro dados
V_OY    equ 0CAC2h          ; desplazamiento actual = MT - M
V_HC    equ 0CAC3h          ; columnas ya impresas de la fila actual
V_HEAD  equ 0CAC4h          ; 1 = hay cabezal

V_TP    equ 0CAD0h          ; word: siguiente pixel del arbol por dibujar
V_TQ    equ 0CAD2h          ; word: fin de lo que queda del arbol (al deshacer)
V_G     equ 0CAD4h          ; columnas barridas al deshacer
V_TMP2  equ 0CAD5h
LCX     equ 39              ; centro horizontal del logo
WIPELEN equ 44
WIPET2  equ 10              ; tick en que empieza a pintarse la segunda linea
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
        call GENTEXT            ; genera las particulas del logo en RAM
        call SCANX              ; medidas del texto

MAIN:
        call CLRALL
        ld a,3Fh
        ld (V_PREVM),a          ; primer fotograma: volcar todo
        ld a,1
        ld (V_KEEP),a           ; el arbol se dibuja sin limpiar
        ld hl,TREE
        ld (V_TP),hl
        ld a,3Fh
        ld (V_MASK),a
        ld hl,R_GROW
        ld a,TREELEN
        call RUN                ; 1. el arbol sale de izquierda a derecha

        xor a
        ld (V_KEEP),a
        ld hl,R_TYPE
        ld a,(V_TYLEN)
        call RUN                ; 2. maquina de escribir, todo en blanco
        call BAKEW              ; el logo blanco pasa a la escena estatica

        call UNLEMON            ; el limon deja la copa (se dibuja ya como sprite)
        ld a,0Ch
        ld (V_MASK),a
        ld hl,R_LEMON
        ld a,LEMLEN
        call RUN                ; 3. cae un limon sobre LIMONERO

        ld a,1
        ld (V_KEEP),a
        ld a,30h
        ld (V_MASK),a
        ld hl,R_WIPE
        ld a,WIPELEN
        call RUN                ; 4. el logo se pinta de amarillo / color 5

        ld hl,R_HOLD
        ld a,70
        call RUN                ; 5. destellos

        ld hl,TREEEND
        ld (V_TQ),hl
        ld a,3Fh
        ld (V_MASK),a
        ld hl,R_UNDO
        ld a,34
        call RUN                ; 6. todo se borra de derecha a izquierda

        xor a
        ld (V_KEEP),a
        ld (V_MASK),a
        ld hl,R_NONE
        ld a,10
        call RUN                ; pausa en negro
        jp MAIN

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
;  ; ---------------------------------------------------------------------------
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
gt3:    ld a,32                 ; dos lineas: 7 + 2 + 5 = 14 filas, abajo a la derecha
        ld (V_Y1),a
        ld a,41
        ld (V_Y2),a
        ld a,(V_N2)
        or a
        jr nz,gt4
        ld a,38                 ; solo amarillo
        ld (V_Y1),a
gt4:    ld a,(V_N1)
        or a
        jr nz,gt5
        ld a,40                 ; solo blanco
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
        call CENTX
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
        call CENTX
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

; B = ancho -> A = x inicial centrado en LCX (sin pisar el tronco ni salirse por la derecha)
CENTX:  ld a,b
        srl a
        ld c,a
        ld a,LCX
        sub c
        cp 15
        jr nc,cx1
        ld a,15
cx1:    ld c,a
        add a,b
        cp 65
        ld a,c
        ret c
        ld a,64
        sub b
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

PLOTBG: ld a,c                  ; igual que PLOTF pero en la escena estatica BG
        rrca
        rrca
        rrca
        and 1Fh
        add a,BGH
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
        jr nz,pbg_odd
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
pbg_odd:
        ld a,(hl)
        and 0F0h
        or e
        ld (hl),a
        ret

LOMASK: db 63,62,60,56,48,32
HIMASK: db 1,3,7,15,31,63

R_NONE: ret

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
;  Maquina de escribir (efecto "print" de ttfx): se imprime cada fila de pixeles del
;  logo, de arriba abajo, en la ultima fila de la pantalla; tras cada fila, retorno de
;  carro (todo sube una fila). Al final el bloque sube hasta quedar centrado.
; ---------------------------------------------------------------------------
; Medidas del texto (una vez)
SCANX:
        ld a,255
        ld (V_TH),a
        ld a,(V_N1)
        or a
        jr z,sx0
        ld a,(V_N2)
        or a
        jr z,sx0
        ld a,(V_Y1)             ; dos lineas: la 2 empieza 7 filas debajo de la 1
        add a,7
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
sx4:    ld a,(V_XMIN1)          ; xb = min, xmax = max (la linea vacia no estorba: 255 / 0)
        ld hl,V_XMIN2
        cp (hl)
        jr c,sx4a
        ld a,(hl)
sx4a:   ld (V_XB),a
        ld c,a
        ld a,(V_XMAX1)
        ld hl,V_XMAX2
        cp (hl)
        jr nc,sx4b
        ld a,(hl)
sx4b:   sub c
        inc a                   ; ancho del bloque
        add a,7
        srl a
        srl a
        srl a                   ; 8 columnas por tick
        ld (V_P),a
        ld a,(V_N1)
        or a
        jr z,sx6
        ld a,(V_Y1)
        ld (V_YT1),a
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
        add a,4
sx8:    ld (V_YBOT),a
        ld hl,V_YT1
        sub (hl)
        inc a
        ld (V_NR),a             ; filas
        ld a,47
        sub (hl)
        ld (V_MT),a
        ld a,(V_YBOT)
        add a,2
        add a,a
        ld (V_SLEN),a           ; salida: una fila cada 2 ticks
        ; duracion de la escritura = suma de duraciones de fila + subida final
        ld a,(V_NR)
        ld b,a
        ld c,0
        ld d,0
sxl:    ld a,c
        call ROWDUR
        add a,d
        ld d,a
        inc c
        djnz sxl
        ld a,(V_MT)
        add a,d
        ld hl,V_NR
        sub (hl)
        inc a
        ld (V_TYLEN),a
        ret

; A = fila j -> A = ticks que dura (las filas vacias entre las dos lineas pasan de golpe)
ROWDUR: ld hl,V_YT1
        add a,(hl)              ; y de esa fila
        ld hl,V_TH
        cp (hl)
        jr c,rd_n
        ld hl,V_Y2
        cp (hl)
        jr nc,rd_n
        ld a,1
        ret
rd_n:   ld a,(V_P)
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

R_TYPE:
        ld a,(V_TICK)
        ld e,a                  ; E = tick
        ld b,0                  ; B = fila j
        ld d,0                  ; D = tick en que empezo la fila j
rt1:    ld a,(V_NR)
        cp b
        jr z,rt_fin
        ld a,b
        call ROWDUR
        ld c,a
        ld a,e
        sub d
        cp c
        jr c,rt_in              ; el tick cae dentro de la fila j
        ld a,d
        add a,c
        ld d,a
        inc b
        jr rt1
rt_in:  inc a                   ; k+1 tramos de 8 columnas ya impresos
        add a,a
        add a,a
        add a,a
        ld (V_HC),a
        ld a,b
        ld (V_J),a
        ld (V_M),a
        ld a,1
        ld (V_HEAD),a
        jr rt_go
rt_fin: ld a,e
        sub d
        ld c,a
        ld a,(V_NR)
        ld (V_J),a              ; todas las filas impresas
        dec a
        add a,c
        ld hl,V_MT
        cp (hl)
        jr c,rt_f2
        ld a,(hl)
rt_f2:  ld (V_M),a
        xor a
        ld (V_HEAD),a
rt_go:  ld a,(V_MT)
        ld hl,V_M
        sub (hl)
        ld (V_OY),a             ; desplazamiento actual
        ; franjas ocupadas: desde la fila 47-M hasta min(47, YBOT+OY)
        ld a,47
        sub (hl)
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
        ; pixeles: filas anteriores a la actual completas; la actual, hasta el cabezal
        ld ix,PARTS
tp1:    ld a,(ix+0)
        inc a
        jr z,tp_head
        ld a,(ix+1)
        ld hl,V_YT1
        sub (hl)
        ld hl,V_J
        cp (hl)
        jr c,tp_pl              ; fila ya impresa
        jr nz,tp_next           ; fila pendiente
        ld a,(ix+0)
        ld hl,V_XB
        sub (hl)
        ld hl,V_HC
        cp (hl)
        jr nc,tp_next
tp_pl:  ld a,(ix+1)
        ld hl,V_OY
        add a,(hl)
        ld c,a
        ld b,(ix+0)
        ld e,15                 ; todo en blanco
        call PLOTF
tp_next:
        ld de,6
        add ix,de
        jr tp1
tp_head:
        ld a,(V_HEAD)
        or a
        ret z
        ld a,(V_HC)
        ld hl,V_XB
        add a,(hl)
        cp 63
        ret nc
        ld b,a                  ; cabezal: 2 pixeles blancos en la fila inferior
        ld c,47
        ld e,15
        call PLOTF
        inc b
        jp PLOTF

; ---------------------------------------------------------------------------
;  Escena: la copia estatica BG manda; el fotograma = BG + lo que se mueve
; ---------------------------------------------------------------------------
CLRALL: ld hl,FB
        ld de,FB+1
        ld bc,1535
        ld (hl),0
        ldir
        ld hl,BG
        ld de,BG+1
        ld bc,1535
        ld (hl),0
        ldir
        ret

; vuelve a copiar BG -> FB en las franjas marcadas en V_PREVM (borra lo dibujado encima)
CLEAR:  ld a,(V_PREVM)
        ld (V_TMP),a
        ld a,6
        ld (V_TMP2),a
        ld hl,BG
        ld de,FB
cl1:    ld a,(V_TMP)
        srl a
        ld (V_TMP),a
        jr nc,cl2
        ld bc,256
        ldir
        jr cl3
cl2:    inc h
        inc d
cl3:    ld a,(V_TMP2)
        dec a
        ld (V_TMP2),a
        jr nz,cl1
        ret

; logo blanco -> BG
BAKEW:  ld ix,PARTS
bk1:    ld a,(ix+0)
        inc a
        ret z
        ld b,(ix+0)
        ld c,(ix+1)
        ld e,15
        call PLOTBG
        ld de,6
        add ix,de
        jr bk1

; 1. el arbol: sus pixeles salen por orden de clave (izquierda a derecha); se dibujan en FB y BG
R_GROW: ld hl,(V_TP)
gr1:    ld a,(hl)
        inc a
        jr z,gr2
        dec a
        ld c,a
        ld a,(V_TICK)
        cp c
        jr c,gr2                ; aun no le toca
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl
        call PLOTF
        call PLOTBG
        pop hl
        jr gr1
gr2:    ld (V_TP),hl
        ret

; sustituye el limon colgado (cruz de 5 pixeles) por el color de la copa, en BG y en FB
UNLEMON:
        ld hl,LEMOFF
        ld d,5
ul1:    ld a,(hl)
        inc hl
        add a,LEMX
        ld b,a
        ld a,(hl)
        inc hl
        add a,LEMY
        ld c,a
        ld e,LEMBG
        push hl
        push de
        call PLOTBG
        call PLOTF
        pop de
        pop hl
        dec d
        jr nz,ul1
        ret
LEMOFF: db 0,-1, -1,0, 0,0, 1,0, 0,1

; 3. el limon cuelga un momento y cae sobre la palabra
R_LEMON:
        ld a,(V_TICK)
        sub LEMPRE
        jr nc,lm1
        xor a
lm1:    ld e,a
        ld d,0
        ld b,a
        ld hl,0
        inc b
        dec b
        jr z,lm3
lm2:    add hl,de               ; HL = d*d
        djnz lm2
lm3:    ld a,l
        rlca
        rlca
        rlca
        and 7                   ; L >> 5
        ld b,a
        ld a,h
        add a,a
        add a,a
        add a,a                 ; H << 3
        or b                    ; dy = d*d/32
        cp LEMFALL
        ret nc                  ; ha tocado la palabra: desaparece
        add a,LEMY
        ld c,a                  ; fila del centro
        ld b,LEMX
        ld e,10
        call PLOTF
        dec c
        call PLOTF
        inc c
        inc c
        call PLOTF
        dec c
        dec b
        call PLOTF
        inc b
        inc b
        jp PLOTF

; 4. onda de color: LIMONERO se pinta desde el punto de impacto, PRODUCTIONS despues, de izquierda a derecha
R_WIPE: ld ix,PARTS
wp1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+1)
        ld hl,V_TH
        cp (hl)
        jr nc,wp2
        ld a,(ix+0)             ; linea 1: distancia al impacto
        sub LEMX
        jr nc,wp1a
        neg
wp1a:   ld b,a
        ld a,(V_TICK)
        add a,a
        sub b
        jr c,wp_next
        jr wp_pl
wp2:    ld a,(ix+0)             ; linea 2: de izquierda a derecha, retrasada
        ld hl,V_XMIN2
        sub (hl)
        ld b,a
        ld a,(V_TICK)
        sub WIPET2
        jr c,wp_next
        add a,a
        sub b
        jr c,wp_next
wp_pl:  ld b,(ix+0)
        ld c,(ix+1)
        ld e,(ix+2)
        call PLOTF
        call PLOTBG
wp_next:
        ld de,6
        add ix,de
        jr wp1

; 6. se borra todo de derecha a izquierda (G = columnas barridas)
R_UNDO: ld a,(V_TICK)
        add a,a
        ld (V_G),a
        ld ix,PARTS
un1:    ld a,(ix+0)
        inc a
        jr z,un3
        ld a,(V_G)
        add a,(ix+0)
        cp 64
        jr c,un2
        ld b,(ix+0)
        ld c,(ix+1)
        ld e,0
        call PLOTBG
un2:    ld de,6
        add ix,de
        jr un1
un3:    ld hl,(V_TQ)            ; el arbol: desde el final de la lista
        ld de,TREE
        or a
        sbc hl,de
        jr z,un5
        ld hl,(V_TQ)
        dec hl
        dec hl
        dec hl
        dec hl
        ld a,(V_G)
        add a,(hl)
        cp 64
        jr c,un5
        ld (V_TQ),hl
        inc hl
        ld b,(hl)
        inc hl
        ld c,(hl)
        ld e,0
        call PLOTBG
        jr un3
un5:    ld a,3Fh
        ld (V_PREVM),a
        jp CLEAR                ; FB = BG

        include "data.inc"
        include "tree.inc"

        ds 4000h+4000h-$        ; relleno hasta 16 KB
