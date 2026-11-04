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
V_TBUF  equ 0CA40h          ; copia normalizada del texto (16 bytes)
V_N1    equ 0CA50h
V_N2    equ 0CA51h
V_S1    equ 0CA52h
V_S2    equ 0CA53h
V_Y0    equ 0CA54h
V_S     equ 0CA55h
V_N     equ 0CA56h
V_GAP   equ 0CA57h
V_STEP  equ 0CA58h
V_X     equ 0CA59h
V_I     equ 0CA5Ah
V_TONE  equ 0CA5Bh
V_ROW   equ 0CA5Ch
V_BITS  equ 0CA5Dh
V_COL   equ 0CA5Eh
V_PX    equ 0CA5Fh
V_PY    equ 0CA60h
V_C     equ 0CA61h
V_DX    equ 0CA62h
V_DY    equ 0CA63h
V_LP    equ 0CA64h          ; word
V_GPTR  equ 0CA66h          ; word
V_TCOL  equ 0CA68h          ; word
V_OUT   equ 0CA6Ah          ; word
V_CNT   equ 0CA6Ch          ; word

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

MAIN:
        call rnd8
        and 7
        ld hl,V_LAST
        cp (hl)
        jr z,MAIN               ; no repetir el efecto anterior
        ld (hl),a
        ld e,a
        ld d,0
        ld hl,TLEN
        add hl,de
        ld a,(hl)               ; longitud de la fase de construccion
        push af
        ld a,e
        ld hl,DISP
        call getfn              ; HL = rutina de render
        pop af
        call RUN                ; construir el logo

        ld hl,R_HOLD
        ld a,70
        call RUN                ; mantener con destello

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
        ld a,e
        ld hl,ODISP
        call getfn
        pop af
        call RUN                ; deshacer

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
        xor a
        ld (V_TICK),a
run1:
        call CLEAR
        ld hl,(V_RFN)
        call callhl
        call BLIT
        call PACE
        call CHSNS
        jp nz,EXIT              ; hay tecla en el buffer
        ld a,(V_TICK)
        inc a
        ld (V_TICK),a
        ld hl,V_RLEN
        cp (hl)
        jr c,run1
        ret

callhl: jp (hl)

EXIT:
        call KILBUF
        xor a
        call CHGMOD             ; vuelve a screen 0
        pop hl                  ; descarta el retorno de RUN
        ret                     ; vuelve al BIOS (arranque normal)


; ---------------------------------------------------------------------------
;  GENTEXT: lee TXTAREA (2 lineas x 8 caracteres) y genera las particulas en PARTS.
;  Escala 3x (1-3 letras), 2x (4-5) o 1x (6-8), centrado en 64x48.
; ---------------------------------------------------------------------------
GENTEXT:
        ; copia a mayusculas
        ld hl,TXTAREA
        ld de,V_TBUF
        ld b,16
gt1:    ld a,(hl)
        inc hl
        cp 'a'
        jr c,gt2
        cp 'z'+1
        jr nc,gt2
        and 0DFh
gt2:    ld (de),a
        inc de
        djnz gt1
        ; longitudes sin espacios/ceros finales
        ld hl,V_TBUF
        call TRIMLEN
        ld (V_N1),a
        ld hl,V_TBUF+8
        call TRIMLEN
        ld (V_N2),a
        ld a,(V_N1)
        or a
        jr nz,gt4
        ; linea 1 vacia: subir la 2 (o poner MSX si no hay nada)
        ld a,(V_N2)
        or a
        jr z,gt3
        ld hl,V_TBUF+8
        ld de,V_TBUF
        ld bc,8
        ldir
        ld a,(V_N2)
        ld (V_N1),a
        xor a
        ld (V_N2),a
        jr gt4
gt3:    ld hl,DEFTXT
        ld de,V_TBUF
        ld bc,3
        ldir
        ld a,3
        ld (V_N1),a
gt4:    ; escalas
        ld a,(V_N1)
        call SCALEOF
        ld (V_S1),a
        ld a,(V_N2)
        call SCALEOF
        ld (V_S2),a
        ; alto total = 7*s1 (+ 3 + 7*s2)
        ld a,(V_S1)
        call MUL7
        ld b,a
        ld a,(V_S2)
        or a
        jr z,gt5
        call MUL7
        add a,3
        add a,b
        ld b,a
gt5:    ld a,48
        sub b
        srl a
        ld (V_Y0),a             ; arriba del texto
        ; inicio de la salida
        ld hl,PARTS
        ld (V_OUT),hl
        ld (hl),255
        ld hl,0
        ld (V_CNT),hl
        xor a
        ld (V_TONE),a
        ; linea 1
        ld hl,V_TBUF
        ld (V_LP),hl
        ld a,(V_N1)
        ld (V_N),a
        ld a,(V_S1)
        ld (V_S),a
        call EMITLINE
        ; linea 2
        ld a,(V_N2)
        or a
        ret z
        ld a,(V_S1)
        call MUL7
        add a,3
        ld hl,V_Y0
        add a,(hl)
        ld (V_Y0),a
        ld hl,V_TBUF+8
        ld (V_LP),hl
        ld a,(V_N2)
        ld (V_N),a
        ld a,(V_S2)
        ld (V_S),a
        jp EMITLINE

DEFTXT: db "MSX"

; HL = inicio de linea de 8 -> A = longitud sin espacios/ceros finales
TRIMLEN:
        ld b,8
        ld de,7
        add hl,de
tl1:    ld a,(hl)
        cp ' '
        jr z,tl2
        or a
        jr nz,tl3
tl2:    dec hl
        djnz tl1
tl3:    ld a,b
        ret

; A = numero de letras -> A = escala (0 si no hay linea)
SCALEOF:
        or a
        ret z
        cp 4
        jr nc,sc1
        ld a,3
        ret
sc1:    cp 6
        jr nc,sc2
        ld a,2
        ret
sc2:    ld a,1
        ret

; A = s -> A = 7*s
MUL7:   ld c,a
        add a,a
        add a,a
        add a,a
        sub c
        ret

; Emite la linea de V_LP (V_N letras) con escala V_S empezando en la fila V_Y0
EMITLINE:
        ld a,(V_S)
        cp 2
        jr nc,el0
        ld a,2
el0:    ld (V_GAP),a
        ld a,(V_S)
        ld b,a
        add a,a
        add a,a
        add a,b                 ; 5*s
        ld hl,V_GAP
        add a,(hl)
        ld (V_STEP),a           ; avance por letra
        ld a,(V_N)
        ld (V_I),a
        ld b,a
        xor a
el1:    ld hl,V_STEP
        add a,(hl)
        djnz el1
        ld hl,V_GAP
        sub (hl)                ; ancho total
        ld b,a
        ld a,64
        sub b
        srl a
        ld (V_X),a
el2:    ld hl,(V_LP)
        ld a,(hl)
        inc hl
        ld (V_LP),hl
        call GLYPHIDX
        jr c,el3                ; espacio o desconocido
        ld (V_GPTR),hl
        ld a,(V_TONE)
        ld e,a
        add a,a
        add a,a
        add a,a
        sub e                   ; 7*tono
        ld e,a
        ld d,0
        ld hl,TONES
        add hl,de
        ld (V_TCOL),hl
        ld a,(V_TONE)
        inc a
        cp 6
        jr c,el4
        xor a
el4:    ld (V_TONE),a
        call EMITGLYPH
el3:    ld a,(V_X)
        ld hl,V_STEP
        add a,(hl)
        ld (V_X),a
        ld hl,V_I
        dec (hl)
        jr nz,el2
        ret

; A = caracter -> HL = direccion del glifo (NC) ; C si es espacio/desconocido
GLYPHIDX:
        ld hl,CHARS
        ld bc,45
        cpir
        jr nz,gi_sp
        ld a,44
        sub c                   ; indice (B = 0)
        cp 36
        jr z,gi_sp
        ld h,0
        ld l,a
        add hl,hl
        add hl,hl
        add hl,hl               ; 8*idx
        ld e,a
        ld d,0
        or a
        sbc hl,de               ; 7*idx
        ld de,FONT
        add hl,de
        or a
        ret
gi_sp:  scf
        ret

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
        ld hl,(V_TCOL)
        add hl,de
        ld a,(hl)
        ld (V_COL),a
        ld a,(V_X)
        ld (V_PX),a
        ld a,5
        ld (V_C),a
gg2:    ld a,(V_BITS)
        bit 4,a
        call nz,BLOCK
        ld a,(V_BITS)
        add a,a
        ld (V_BITS),a
        ld a,(V_S)
        ld hl,V_PX
        add a,(hl)
        ld (hl),a
        ld hl,V_C
        dec (hl)
        jr nz,gg2
        ld a,(V_S)
        ld hl,V_PY
        add a,(hl)
        ld (hl),a
        ld hl,V_ROW
        inc (hl)
        ld a,(hl)
        cp 7
        jr c,gg1
        ret

; bloque s x s en (V_PX,V_PY) con color V_COL
BLOCK:  ld a,(V_S)
        ld (V_DY),a
bk1:    ld a,(V_S)
        ld (V_DX),a
bk2:    ld a,(V_S)
        ld hl,V_DY
        sub (hl)
        ld hl,V_PY
        add a,(hl)
        ld c,a
        ld a,(V_S)
        ld hl,V_DX
        sub (hl)
        ld hl,V_PX
        add a,(hl)
        ld b,a
        ld a,(V_COL)
        ld e,a
        call EMIT
        ld hl,V_DX
        dec (hl)
        jr nz,bk2
        ld hl,V_DY
        dec (hl)
        jr nz,bk1
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

CLEAR:  di
        ld (V_SPS),sp
        ld sp,FB+1536
        ld hl,0
        ld b,192
cl1:    push hl
        push hl
        push hl
        push hl
        djnz cl1
        ld sp,(V_SPS)
        ei
        ret

BLIT:   di
        ld hl,0
        call SETWRT
        ld hl,FB
        ld c,98h
        ld b,0
        otir
        ld b,0
        otir
        ld b,0
        otir
        ld b,0
        otir
        ld b,0
        otir
        ld b,0
        otir
        ei
        ret

PACE:   halt
        ld a,(JIFFY)
        ld hl,V_LASTJ
        sub (hl)
        cp 2
        jr c,PACE
        ld a,(JIFFY)
        ld (V_LASTJ),a
        ret

; B = x (0..63), C = y (0..47), E = color (0..15). Fuera de pantalla: no hace nada.
PLOT:   ld a,b
        cp 64
        ret nc
        ld a,c
        cp 48
        ret nc
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

R_NONE: ret

; ---------------------------------------------------------------------------
;  Efecto 0: "decrypt" - ruido verde que se fija en el color final
; ---------------------------------------------------------------------------
R_DECRYPT:
        ld ix,PARTS
dc1:    ld a,(ix+0)
        inc a
        ret z
        ld b,(ix+0)
        ld c,(ix+1)
        ld a,(ix+5)
        add a,10
        ld d,a                  ; instante en que se fija
        ld a,(V_TICK)
        cp d
        jr nc,dc_final
        call rnd8
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
        call PLOT
        ld de,6
        add ix,de
        jr dc1

; ---------------------------------------------------------------------------
;  Efecto 1: lluvia - cada pixel cae a su sitio
; ---------------------------------------------------------------------------
R_RAIN:
        ld a,(V_TICK)
        cp 60
        jr c,rn0
        ld a,60
rn0:    add a,a
        ld (V_TMP),a            ; 2*t
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
cv0:    call BUILDLUT
        ld ix,PARTS
cv1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+3)
        sub (ix+0)
        add a,128
        ld l,a
        ld h,LUTH
        ld a,(hl)
        add a,(ix+0)
        ld b,a                  ; x
        ld a,(ix+4)
        sub (ix+1)
        add a,128
        ld l,a
        ld a,(hl)
        add a,(ix+1)
        ld c,a                  ; y
        ld e,(ix+2)
        call PLOT
        ld de,6
        add ix,de
        jr cv1

; ---------------------------------------------------------------------------
;  Efecto 3: barrido diagonal con brillo en el borde
; ---------------------------------------------------------------------------
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
        and 31
        ld e,(ix+2)
        cp 3
        jr nc,hd2
        ld e,15
hd2:    ld b,(ix+0)
        ld c,(ix+1)
        call PLOT
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
ex0:    call BUILDLUT
        ld ix,PARTS
ex1:    ld a,(ix+0)
        inc a
        ret z
        ld a,(ix+5)
        srl a
        add a,28                ; vida: 28..59 fotogramas
        ld hl,V_TICK
        cp (hl)
        jr c,ex_next            ; ya murio
        ld a,(ix+0)
        sub 32
        add a,a
        add a,(ix+3)
        sub 32                  ; vx = 2*(x-32) + (rx-32)
        add a,128
        ld l,a
        ld h,LUTH
        ld a,(hl)
        add a,(ix+0)
        ld b,a
        ld a,(ix+1)
        sub 24
        add a,a
        add a,(ix+4)
        sub 24                  ; vy = 2*(y-24) + (ry-24)
        add a,128
        ld l,a
        ld a,(hl)
        add a,(ix+1)
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
        jp PLOT

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
wv0:    call BUILDLUT
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
        call PLOT
di_next:
        ld de,6
        add ix,de
        jr di1

; ---------------------------------------------------------------------------
;  Tablas
; ---------------------------------------------------------------------------
DISP:   dw R_DECRYPT,R_RAIN,R_CONVERGE,R_SWEEP,R_SLIDE,R_WAVE,R_EXPAND,R_RISE
TLEN:   db 80,56,72,46,46,56,36,56
ODISP:  dw R_EXPLODE,R_FALL,R_DISSOLVE
OLEN:   db 64,66,70
GREENS: db 12,3,2,15
GLOW:   db 0,15,15,11,11,7,7,5,5,4

        include "data.inc"

        ds 4000h+4000h-$        ; relleno hasta 16 KB
