$MOD51
$DEBUG

$include (lift.inc)
FLOORREQ        data    36h

; hodiny oscilatora v emulatore treba dat na ext a nastavit 11.0592MHz
TIMERCONST      equ     250     ; udaj pre nastavenie casovaca pre potreby seriovej komunikacie
                                ; hodnota 250 znamena prenosovu rychlost 4800 baud pri oscilatore 11.0592MHz
                                ; nastavenie terminalu je 4800 8-N-1, no flow control
;osetrenie vektorov preruseni
        org     0000h           ; adresa odkial startuje program po resete
        ljmp    START           ; skok na zaciatok kodu programu
              
        org     0033h           ; od tejto adresy sa zacina kod programu
START:
RESET:  
        ; riadiace signaly do pasivnej urovne
        setb    WRNOT
        setb    RDNOT
        mov     STOPTIMER, #0
        mov     SP, #STACK

        ; pockame si na inicializaciu obvodov 8255  
        mov     R1, #0 
        mov     R2, #01h             ;Povodne #0ffh <<EMULATOR>>
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

        ; pociatocna inicializacia - vynuluj vstupne registre a rozsviet vsetky diody 
        mov     INPORTA, #0
        mov     INPORTB, #01eh      ; vsetky clonky pasivne
        mov     INPORTC, #0
        mov     OUTPORTA, #(bmPKO1 or bmPKO2 or bmPKO3 or bmPKO4)
        mov     OUTPORTB, #(bmFLED1 or bmFLED2 or bmFLED3 or bmFLED4)
        mov     OUTPORTC, #(bmPO1 or bmPO2D or bmPO2U or bmPO3D or bmPO3U or bmPO4 or bmLEDD or bmLEDU)
        setb    KS
        call    WRITEPORTS          ; zapis novu informaciu
;;;;;;;;

        mov     OUTPORTA, #0
        mov     OUTPORTB, #0
        mov     OUTPORTC, #0
        call    WRITEPORTS          ; zapis novu informaciu
        
        call    WAITFORTIMER
        
        mov     INPORTA, #0
        mov     INPORTB, #0         
        mov     INPORTC, #0
        call    READPORTS           ; prvotne nacitanie udajov

CALIB:
        ;kalibracia vytahu podla dolnej porovnavacej clonky
        lcall   READPORTS                   ; precitaj, co je na portoch
        jnb     SKRD, CALIBEND              ; ak sme na dolnej porovnavacej clonke, tak koniec
        setb    DOWN                        ; inak pod dole
        setb    FAST                        ; a rychlo
        lcall   WRITEPORTS                  ; zapis informaciu 
CALIBLOOP:
        lcall   READPORTS                   ; 
        jnb     SKRD, CALIBEND              ; ak sme dole, konci
        ;jnb     MB2, CALIBEND               ; ak sme na poschodi, konci
        jmp     CALIBLOOP
CALIBEND:
        mov     FLOORREQ, #0                                
        clr     FAST                        ; stojime
        clr     DOWN                        ;
        setb    FLED1
        lcall   WRITEPORTS                  ; zapis informaciu
MAIN:

;            |  7    |  6    |  5    |  4    |  3    |  2    |  1    |  0    |
; ****************************************************************************
; INPORTA >  |       |       |DOORCLS| PKI4  | PKI3  | PKI2  | PKI1  |STOPNOT|
; ----------------------------------------------------------------------------
; INPORTB >  | DPK   | DPZK  | DP    | SKRD  | SKRH  | MB2   | MB1   |       |
; ----------------------------------------------------------------------------
; INPORTC >  |       |       | PI4   | PI3D  | PI3U  | PI2D  | PI2U  | PI1   |
; ****************************************************************************
; OUTPORTA > |       |       |       | PKO4  | PKO3  | PKO2  | PKO1  | KS    |
; ----------------------------------------------------------------------------
; OUTPORTB > | FLED4 | FLED3 | FLED2 | FLED1 | SLOW  | FAST  | DOWN  | UP    |
; ----------------------------------------------------------------------------
; OUTPORTC > | LEDU  | LEDD  | PO4   | PO3D  | PO3U  | PO2D  | PO2U  | PO1   |
; ****************************************************************************
; POSITION
; ****************************************************************************


FLOOR1:
        lcall   WAITFORTIMER
F1S:    lcall   READPORTS
        mov     A, INPORTA
        anl     A, #00011100b
        clr     PKO1
        lcall   WRITEPORTS
        jz      F1S  
        setb    UP                        ; inak pod dole
        setb    FAST                        ; a rychlo
        lcall   WRITEPORTS                  ; zapis informaciu
        jmp     UP1
UP1:
        lcall   READPORTS
        jb      MB2, UP1
        lcall   READPORTS
        jnb     MB2, $-3                
        setb    LEDD
        lcall   WRITEPORTS
        jmp     UP1_MB2
UP1_MB2:
        lcall   READPORTS
        jb      MB2, UP1_MB2              
        setb    LEDU
        lcall   WRITEPORTS
        jmp     UP1_MB1        
UP1_MB1:
        lcall   READPORTS
        jb      MB1, UP1_MB1 
        clr     LEDU
        clr     LEDD
        lcall   WRITEPORTS
        jmp     FLOOR2

FLOOR2:
        clr     UP                        ; inak pod dole
        clr     FAST                        ; a rychlo
        clr     FLED1     
        setb    FLED2     
        clr     FLED3     
        clr     FLED4     
        lcall   WRITEPORTS                  ; zapis informaciu
        jmp     ENDPROG
UP2:

UP2_MB1:

UP2_MB2:

DOWN2_MB1:

DOWN2_MB2:
     
     
HIGHER:
        lcall   READPORTS
        jb      MB1, HIGHER
        clr     UP                        ; inak pod dole
        clr     FAST                      ; a rychlo
        lcall   WRITEPORTS                ; zapis informaciu              
ENDPROG:
        ;----------------------------breakpoint
BP:     clr     P3.3
        setb    EX1
        nop
        ;----------------------------
        setb    KS
        call    WRITEPORTS                ; zapis novu informaciu
        ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WAITFORTIMER
; Pocka na stlacenie tlacidla na 1. poschodi  - signal PO1 (v buducnosti to 
; bude timer)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WAITFORTIMER:
        lcall   READPORTS                   ; 
        jnb     PI2D, WAITFORTIMER           ; ak nebolo stlacene tlacidlo PO1, cakaj 
        ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; READPORTS
; precita nove hodnoty na portoch
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READPORTS:
        mov     p2, #i8255INA       ; citaj data z portu A
        mov     p0, #(bmSTOP or bmPKI1 or bmPKI2 or bmPKI3 or bmPKI4 or bmDOORCLSD)
        clr     RDNOT
        nop
        nop
        nop
        nop
        mov     INPORTA, p0         ; uloz informaciu z datovej zbernice 
        setb    RDNOT
        
        mov     p2, #i8255INB       ; citaj data z portu B
        mov     p0, #(bmMB1I or bmMB2I or bmSKRHI or bmSKRHD or bmDPI or bmDPKI or bmDPZKI)
        clr     RDNOT
        nop
        nop
        nop
        nop
        mov     INPORTB, p0         ; uloz informaciu z datovej zbernice 
        setb    RDNOT

        mov     p2, #i8255INC       ; citaj data z portu C
        mov     p0, #(bmPI1 or bmPI2D or bmPI2U or bmPI3D or bmPI3U or bmPI4)
        clr     RDNOT
        nop
        nop
        nop
        nop
        mov     INPORTC, p0         ; uloz informaciu z datovej zbernice 
        setb    RDNOT
        
        
        mov     A, INPORTA
        anl     A, #00011110b
        orl     OUTPORTA, A
        call    WRITEPORTS              ; aktualizuj signalizaciu na ovladacom paneli
        
        ret
        
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

STR_INIT:   db  0dh, 0ah, 'Riadiaci system je inicializovany.', 0dh, 0ah, 00h
STR_STOP:   db  'Riadiaci system je reinicializovany po stlaceni tlacidla STOP.', 0dh, 0ah, 00h
STR_CALIB:  db  'Kalibracia vytahu je ukoncena.', 0dh, 0ah, 00h

        DSEG
        org     40h
STACK:  DS      10h

end