;Interrupt test

$include (lift.inc)

_BP_    MACRO 
        clr     P3.3
        setb    EX1
        nop
        nop
ENDM

$MOD51
$DEBUG
        org     000Bh           ; v tejto casti pamati je vektor prerusenia
        ljmp    INT_TIMER0      ; pre citac T0

        org     0033h           ; od tejto adresy sa zacina kod programu
                                ; testovacie hodnoty
                              
                              
                ; riadiace signaly do pasivnej urovne 
        setb    WRNOT
        setb    RDNOT
        mov     STOPTIMER, #0
        mov     SP, #STACK

        ; pockame si na inicializaciu obvodov 8255  
        mov     R1, #0 
        mov     R2, #0ffh
        djnz    R1, $
        djnz    R2, $-2
        
        ; teraz ich mozeme nastavit
        mov     p0, #10011011b      ; nastavenie i8255IN - vsetky porty dnu
        mov     p2, #i8255INCW
        clr     WRNOT
        nop
        nop
        nop
        nop
        setb    WRNOT
        mov     p0, #10000000b      ; nastavenie i8255OUT - vsetky porty von
        mov     p2, #i8255OUTCW
        clr     WRNOT
        nop
        nop
        nop
        nop
        setb    WRNOT
        
        _BP_
        setb    FLED2
        setb    FLED3
        clr     LEDU
        clr     LEDD
        lcall   WRITEPORTS
        
        ;clr     TR1                 ; zastavi sa citac T1
        ;clr     TR0                 ; zastavi sa citac T1

        mov     TCON,#00000001b     ; INT0 je citlive na zostupnu hranu
        mov     TMOD,#00010001b     ; nastavenie TMOD registra
                                    ; T1: mod 1 - 16 bitove pocitadlo
                                    ; GATE=0 (programove riadenie casovaca)
                                    ; C/T#=0 interne hodiny/12
                                    ; T0: mod 1 - 16 bitove pocitadlo
                                    ; GATE=0 (programove riadenie casovaca)
                                    ; C/T#=0 interne hodiny/12
        mov     PCON,#00000000b     ; najvyssi bit musi byt 0, aby sa nezdvojnasobila prenosova rychlost seriovej linky
        mov     TL0, #000h           ; inicializacia casovaca T0 - 57600 = 0e100h
        mov     TH0, #0E1h

        ;setb    TR1                 ; aktivacia T1 => spustenie seriovej linky

;        setb    EX0                 ; prerusenie INT0  - ostava zakazane, signal STOP osetrime priamo v hlavnej slucke
;        setb    ES                  ; prerusenie seriovej linky teraz nevyuzivame
        ;setb    TR0                 ; povolime prerusenia od casovaca T0
        ;setb    EA                  ; spust cely prerusovaci mechanizmus                      
                              
                                

        setb    ET0
        setb    EA  
        setb    TR0
        mov     R3, #20
        mov     R5, #30
        mov     A, R3   
                
LOOP:   ;dec     A
        ;jnb     TF0, $
        ;clr     TF0
        ;jz      LOOP 
        ;cpl     LEDU
        ;cpl     LEDD
        ;lcall   WRITEPORTS    
        ;mov     A, R3
        jmp     LOOP                    

INT_TIMER0:
        push    ACC
;        clr     EA
;        _BP_
        mov     A, R5
        dec     R5
        jz      INT_TIMER0_MAIN    
        sjmp    INT_TIMER0_END              ; a koniec
        
INT_TIMER0_MAIN:
        mov     R5, #20
        cpl     LEDU
        cpl     LEDD
        lcall   WRITEPORTS  
        
INT_TIMER0_END:        

;        setb    EA
        pop     ACC
		reti
		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WRITEPORTS
; spravi zalohu vystupnych registrov a posle data von
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WRITEPORTS:
        mov     p0, OUTPORTA        ; teraz postupne posli data najprv na port A,
        mov     p2, #i8255OUTA
        clr     WRNOT
        nop
        nop
        nop
        nop
        setb    WRNOT
        
        mov     p0, OUTPORTB        ; potom port B
        mov     p2, #i8255OUTB
        clr     WRNOT
        nop
        nop
        nop
        nop
        setb    WRNOT

        mov     p0, OUTPORTC        ; a nakoniec port C
        mov     p2, #i8255OUTC
        clr     WRNOT
        nop
        nop
        nop
        nop
        setb    WRNOT
        ret
        
        DSEG
        org     40h
STACK:  DS      10h

        end