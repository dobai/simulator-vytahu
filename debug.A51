; TODO: 
; OK - Dorob nulovanie volieb v sachte 
; Dorob 3UP a 2 DOWN (tam kde stojis vzdy)
; Asi by bolo dobre premenovat PI1, PO1 a PI4 PO4 na alternativy s koncovkami U a D
; Poriadne otestuj !!! 
; Umozni stlacat tlacidla aj ked bezi delay

;Prerusenia pojdu, ale treba dat sakra pozor na zalohovanie veci!!!

;uvision debug: 
;MODE COM5 4800, 0, 8, 1
;assign COM5 < SIN > SOUT
;
;X:000000H


$MOD51
$DEBUG

$include (lift.inc)
$include (macroLib.inc)
                   

; Definicie registrov pre Keil uVision
T2CON  DATA  0C8H  ;TIMER 2 CONTROL
T2MOD  DATA  0C9H  ;TIMER 2 MODE
RCAP2L DATA  0CAH  ;TIMER 2 CAPTURE REGISTER - LOW BYTE
RCAP2H DATA  0CBH  ;TIMER 2 CAPTURE REGISTER - HIGH BYTE
TR2    BIT   0CAH  ;T2CON.2 - TIMER 2 ON/OFF CONTROL
ET2    BIT   0ADH  ;IE.5 - TIMER 2 INTERRUPT ENABLE
TF2    BIT   0CFH  ;T2CON.7 - TIMER 2 OVERFLOW FLAG
WDTRST DATA  0A6H  ;Watchdog timer


COUNT    SET    0

;*******************************************************************************
;   Oznacenie poruchoveho poschodia 
;-------------------------------------------------------------------------------
;     nastavi dane poschodie ako poruchove ak je TESTBIT rovny 0    
;
SET_FLOOR_ERR   MACRO   TESTBIT, FLOORBIT, NAVESTIE, POSCH, LABEL    ;; nastavi dane poschodie ako poruchove ak je TESTBIT rovny 0 
																	 ;;   FLOORBIT:   ERRF1, .. ERRF4, ERRF12, ERRF23, ERRF34
																	 ;;   TESTBIT:    MB1, MB2
        ;INCREMENT SUFFIX  FOR  NEXT LABEL             
        COUNT    SET    COUNT+1                   
        
        jb      TESTBIT, ENDD&LABEL
        jnb     PKI&POSCH, $+7
        clr     FAST
        setb    SLOW
        setb    STOPPED         
        setb    FLOORBIT&_U
        setb    FLOORBIT&_D
        inc     FLOORBIT&_C
		clr     PKO&POSCH				;; vynulovanie volby poschodia na ktorom stojim
        clr     PO&POSCH&U            
        clr     PO&POSCH&D		
		lcall   WRITEPORTS
        ljmp    NAVESTIE
ENDD&LABEL:
        nop
ENDM

;*******************************************************************************
;   Odstranenie oznacenia poruchoveho poschodia 
;-------------------------------------------------------------------------------
;     nastavi dane poschodie ako poruchove ak je TESTBIT rovny 0    
;
CLR_FLOOR_ERR   MACRO   FLOORBIT,   ;; nastavi dane poschodie ako bezporuchove           
        clr    FLOORBIT&_U
        clr    FLOORBIT&_D
        nop
ENDM

;*******************************************************************************
;   Osetrenie zakmitov clonky
;-------------------------------------------------------------------------------
;        
;
ZAKMITC MACRO   TYPCLONKY
        lcall   TIME10MS        ; pockame 10 ms kym sa hodnota ustali (ze som na clonke)
        lcall   READPORTS       ; Uz sme z tej clonky prec?
        jnb     TYPCLONKY, $-3  ; 
        lcall   TIME10MS        ; pockame 10 ms  kym sa hodnota ustali (ze sme z nej naozaj zliezli)
ENDM

ZASTAV  MACRO  C_POSCH, SMER
                                        ;; Chceme tu zastavit? - je toto poschodie zvolene? 
        clr     C                       ;; | Idem robit cachre-machre s Carry bitom
        mov     A, #0h                  ;; | Aj Acc potrebujem prazdny
        orl     C, PI&C_POSCH&SMER      ;; | Mam v tomto smere stlacene tlacidlo v sachte?
        anl     C, /DPZK                ;; | a mam plne zatazenu kabinu? (lebo ak ano tak ani za boha nestojim)
        orl     C, PKI&C_POSCH          ;; | Mam v tomto smere stlacene tlacidlo v kabine? 
        anl     C, /ERRF&C_POSCH&_&SMER ;; | a mam v tomto smere poruchu na tomto poschodi (Ak ano, tak nema zmysel stat)
        orl     C, DPK                  ;; | a mam pretazenu kabinu? (Ak ano tak stojim urcite)
        orl     C, STOPPED              ;; | a bolo stlacene tlacidlo STOP? (Ak ano tak stojim urcite)
        addc    A, #0h                  ;; Ak mi v predchadzajucich krokoch vyslo, ze mam stat, tak stojim nezavisle na tlacidlach kabiny
ENDM

NAJNIZSIE  MACRO
        mov     A, INPORTC      ; INPORTC - vektor "privolavace zo sachty"               
        rlc     A               ; SHIFT LEFT - shiftnem si tak, aby som mal kazde poschodie dvojicu bitov | X  4 | 3U 3D | 2U 2D | 1  X | 
        anl     A, #01111110b   ; Vynulujem nedefinovane bity

        ;ANLB    ACC.1, ERRF1_D  ; maskujem chybne poschodia
        ANLB    ACC.2, ERRF2_D  ; |
        ANLB    ACC.3, ERRF2_D  ; |
        ANLB    ACC.4, ERRF3_D  ; |
        ;ANLB    ACC.5, ERRF3_D  ; |

        mov     R0, #05         ; Budem opakovat max. 4x (ale chcem mat index o jeden viac, aby som mal na konci rovno cislo poschodia)
 ; LL1: 
        jz      $+8;LL2         ; Ak mam 0 - ziadne dalsie poschodia ne su pritomne, skocim na LL2
        clr     C               ; Inak shiftnem o 2
        rlc     A               ;
        clr     C               ;
        rlc     A               ;
        djnz    R0, $-6         ; ...a pokracujem v zistovani
; LL2:
        mov     A, R0           ; vysledne (najnizsie zvolene) poschodie je index v R0
ENDM

NAJVYSSIE  MACRO
        mov     A, INPORTC      ; INPORTC - vektor "privolavace zo sachty"               
        rlc     A               ; SHIFT LEFT - shiftnem si tak, aby som mal kazde poschodie dvojicu bitov | X  4 | 3U 3D | 2U 2D | 1  X | 
        anl     A, #01111110b   ; Vynulujem nedefinovane bity
        
        ;ANLB    ACC.2, ERRF2_U  ; maskujem chybne poschodia
        ANLB    ACC.3, ERRF2_U  ; |
        ANLB    ACC.4, ERRF3_U  ; |
        ANLB    ACC.5, ERRF3_U  ; |
        ;ANLB    ACC.6, ERRF4_U  ; |
        
        mov     R0, #05         ; Budem opakovat max. 4x (ale chcem mat index o jeden viac, aby som mal na konci rovno cislo poschodia)
 ; LL1: 
        jz      $+8;LL2         ; Ak mam 0 - ziadne dalsie poschodia ne su pritomne, skocim na LL2
        clr     C               ; Inak shiftnem o 2
        rrc     A               ;
        clr     C               ;
        rrc     A               ;
        djnz    R0, $-6         ; ...a pokracujem v zistovani
; LL2:
        mov     A, #5           ; vysledne (najnizsie zvolene) poschodie je index v R0
        clr     C               ;
        subb    A, R0           ;
ENDM

VYSSIE_KABINA  MACRO  POSCH
        mov     A, INPORTA
        anl     A, #00011110b
        mov     B, ERRFLOOR_U   ; maskujem chybne poschodia
        anl     B, #00001100b   ; na krajne poschodia dovolim ist
        xrl     B, #0FFH
        anl     A, B
        clr     C
        rrc     A
;LL1    
        mov     R0, #&POSCH
        clr     C
        rrc     A
        djnz    R0, $-2;LL1
ENDM

NIZSIE_KABINA  MACRO  POSCH
        mov     A, #5
        clr     C
        subb    A, #&POSCH
        mov     R0, A
        mov     A, INPORTA
        anl     A, #00011110b
        mov     B, ERRFLOOR_D   ; maskujem chybne poschodia
        anl     B, #00001100b   ; na krajne poschodia dovolim ist
        xrl     B, #0FFH
        anl     A, B
        clr     C
        rlc     A
        clr     C
        rlc     A
        clr     C
        rlc     A
;LL1   
        clr     C
        rlc     A
        djnz    R0, $-2;LL1
ENDM



; hodiny oscilatora v emulatore treba dat na ext a nastavit 11.0592MHz (11.052900)
TIMERCONST      equ     250     ; udaj pre nastavenie casovaca pre potreby seriovej komunikacie
                                ; hodnota 250 znamena prenosovu rychlost 4800 baud pri oscilatore 11.0592MHz
                                ; nastavenie terminalu je 4800 8-N-1, no flow control
TIMER0CONST     equ     20      ; pouziva sa pri Timer0, ktory sluzi na rozblikanie LEDiek pri poruche. Hodnota 20 je 1 sekunda (1=50ms)
;osetrenie vektorov preruseni
        org     0000h           ; adresa odkial startuje program po resete
        ljmp    START           ; skok na zaciatok kodu programu
        
        org     000Bh           ; v tejto casti pamati je vektor prerusenia
        ljmp    INT_TIMER0      ; pre casovac T0
        
        org 	  0023h           ; v tejto casti pamati je vektor prerusenia
		    ljmp	  SERIAL_INT		  ; seriovej linky 
    
        org		  002Bh           ; v tejto casti pamati je vektor prerusenia
		    ljmp    INT_TIMER2      ; pre casovac T2   
              
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
        
        ; nastavenie preruseni 
        clr     TR1                 ; zastavi sa citac T1
        mov     SCON,#01010010b     ; nastavenie registra SCON                                                                           <<<<<<<<<   01010010b
                                    ; mod 1 (8b UART), SM2=0 (jednoprocesorovy system)
                                    ; REN=1, 0, 0, TI=1 (vysielaci register je prazdny)
                                    ; RI=0 (prijimaci register - nebol prijaty znak)
        ;mov     TCON,#00000001b     ; INT0 je citlive na zostupnu hranu				 <<< 
        mov     TMOD,#00100001b     ; nastavenie TMOD registra
                                    ; T1: mod 1 - 16 bitove pocitadlo
                                    ; GATE=0 (programove riadenie casovaca)
                                    ; C/T#=0 interne hodiny/12
                                    ; T0: mod 1 - 16 bitove pocitadlo
                                    ; GATE=0 (programove riadenie casovaca)
                                    ; C/T#=0 interne hodiny/12
        mov     PCON,#01000000b     ; najvyssi bit musi byt 0, aby sa nezdvojnasobila prenosova rychlost seriovej linky                   <<<<<<<<   00000000b
        mov     TL1, #000h          ; inicializacia casovaca T1
        mov     TH1, #0FAh          ; 
        mov     TL0, #000h          ; inicializacia casovaca T0 - 57600 = 0e100h		 <<<
        mov     TH0, #04Ch					;                                        				 <<<
		    mov		  T2CON,  #0			    ; Auto-reload mod
		    mov		  RCAP2L, #0h;		    ; 4C00h = 19456,  Timer Clk=11,0592/12*1 = 0,9216 MHz
		    mov		  RCAP2H, #4Ch;		    ; (50ms)
		    setb	  ET2					        ; Enable Timer2 interrupt
        
        
        
        setb    TR0                 ;                                        				 <<<
        clr     ET0
        setb    TR1                 ; aktivacia T1 => spustenie seriovej linky
        
        clr     TI
        clr     RI
        setb    TRE
        setb	  ES			; enable serial interrupt	
		    mov		  MSG_PTR_REC, #0h
		    clr		  S_RI
        

        ; pociatocna inicializacia - vynuluj vstupne registre a rozsviet vsetky diody 
        mov     INPORTA, #0
        mov     INPORTB, #01eh      ; vsetky clonky pasivne
        mov     INPORTC, #0
        mov     OUTPORTA, #(bmPKO1 or bmPKO2 or bmPKO3 or bmPKO4)
        mov     OUTPORTB, #(bmFLED1 or bmFLED2 or bmFLED3 or bmFLED4)
        mov     OUTPORTC, #(bmPO1 or bmPO2D or bmPO2U or bmPO3D or bmPO3U or bmPO4 or bmLEDD or bmLEDU)
        setb    KS
        clr     STOPPED
        call    WRITEPORTS          ; zapis novu informaciu

        mov     OUTPORTA, #0
        mov     OUTPORTB, #0
        mov     OUTPORTC, #0
        call    WRITEPORTS          ; zapis novu informaciu
        
        ;----------------------------------------------------
        ;mov     DPTR, #STR_RESET    ; vypis info 
        ;lcall   DISPSTRNOWDT        ; o zapnuti watchdog timera
        
        ;TIMER2  200
        ;jnb		  T2_F, $			        ; Uz presiel cas?
        
        ;clr     DOWN                ; ZASTAVIME KABINU
        ;clr     FAST                ; a rychlo
        ;clr     SLOW                ;                           
        ;clr     UP                  ;
        ;lcall   WRITEPORTS          ; zapis informaciu 
        ;mov     DPTR, #STR_WDT      ; vypis info 
        ;lcall   DISPSTRNOWDT        ; o zapnuti watchdog timera
        ;mov     WDTRST, #01Eh
        ;mov     WDTRST, #0E1h
        
        ;----------------------------------------------------

        mov     INPORTA, #0
        mov     INPORTB, #0         
        mov     INPORTC, #0
        call    READPORTS           ; prvotne nacitanie udajov
        
        mov     ERRFLOOR_U, #0h     ; vynuluj chybovy register
        mov     ERRFLOOR_D, #0h      

        
        mov     DPTR, #STR_INIT         ; vypis info 
        lcall   DISPSTR                 ; o inicializacii
        
               
CALIB:
        ;kalibracia vytahu podla dolnej porovnavacej clonky
        ;setb    TR0
        lcall   READPORTS                   ; precitaj, co je na portoch
        jnb     SKRD, CALIBEND              ; ak sme na dolnej porovnavacej clonke, tak koniec
        setb    DOWN                        ; inak pod dole
        setb    FAST                        ; a rychlo
        clr     SLOW                        ;
        clr     UP                
        lcall   WRITEPORTS                  ; zapis informaciu 
CALIBLOOP:
        lcall   READPORTS                   ; 
        jnb     SKRD, CALIBEND              ; ak sme dole, konci
        jmp     CALIBLOOP
CALIBEND:                              
        clr     FAST                        ; zastavime v tomto smere
        clr     DOWN                        ;
        setb    SLOW                        ; Este sa pohneme kusocek hore, aby sme si 
        setb    UP                          ; boli isti, ze sme spravne synchronizovani na poschodi
        lcall   WRITEPORTS 
CALIBEND2:
        lcall   READPORTS                   ; 
        jb      MB1, CALIBEND2              ; 
        clr     SLOW                        ; A teraz sme uz naozaj spravne
        clr     UP                          ; 
        setb    FLED1
        lcall   WRITEPORTS                  ; zapis informaciu
        ;clr     TR0
        ;_BP_
        mov     DPTR, #STR_INIT             ; vypis info o kalibracii
        lcall   DISPSTR                     ;
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



        ;mov     R5, #0
        ;mov     R6, #20
        ;setb    ET0;
        

                                                                                          
        ;Inicializacia priznakov (CFCSS)
        mov		G, #30
		    mov		D1, #0
        mov		D2, #0
        mov   DPTR, #STR_CFC_START         ; vypis info 
        lcall DISPSTR         ;
                      


;------------------------------------------------------------------------------- << 1. poschodie >>

FLOOR1:
        ;--------------------------
        CFCSS     29, 3, -1, -1, D1
        ;--------------------------
                POLOHA_LED 1  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        clr     STOPPED
        TIMER2  60              ; (Timer - 3s)
        ROZSVIET_SMER_LED
F1S:    lcall   READPORTS       ; nacitanie dat
        ljnb    MB2, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ljnb    SKRH, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ZRUS_POSCH 1
        
        LCALLB		S_RI, RCV_MESSAGE
        
        jnb		   T2_F, F1S			; Uz presiel minimalny cas na poschodi? Ak nie, nejdeme dalej
        KABINOVE_SVETLO         ; Rozsviet kabinove svetlo a smerovu signalizaciu ak je v kabine osoba
        jb      DPK, F1S        ; Mam pretazenu kabinu? (Ak ano, tak sa nepohnem)
        jnb     DOORCLSD, F1S   ; Su otvorene dvere? Ak ano, tak nejdem dalej.
        JE_VYBRATE_POSCHODIE F1S; Je v kabine osoba, ktora este nevybrala poschodie? Ak ano, nejdeme dalej.
F1C:        
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco viac ako poschodie na ktorom stojim (Kabina)
        mov     B, ERRFLOOR_U   ; | maskujem chybne poschodia
        anl     B, #00001100b   ; | na krajne poschodia dovolim ist
        xrl     B, #0FFH        ; | |
        anl     A, B            ; | |
        anl     A, #00011100b   ; |
        jnz     F1OK            ; ak ano, podme na to
        mov     A, INPORTC      ; zistenie, ci bolo stlacene nieco viac ako poschodie na ktorom stojim (Sachta)
        anl     A, #00111110b   ;
        ;ANLB    ACC.1, ERRF2_U  ; maskujem chybne poschodia (v smere hore)
        ANLB    ACC.2, ERRF2_U  ; |
        ANLB    ACC.3, ERRF3_U  ; |
        ANLB    ACC.4, ERRF3_U  ; |
        ;ANLB    ACC.5, ERRF4_U  ; |
        jnz     F1OK            ; ak ano, podme na to
        jmp     F1S             ; Nemam sa kde hnut, opakujem
F1OK:   SET_UP                  ; rychly pohyb hore
        SET_FAST                ; 
        lcall   WRITEPORTS      ; 
        jmp     UP1             ; prejdi do stavu UP1
        
        
UP1:
        ;--------------------------
        CFCSS     20, 9, 27, -1, -1
        ;--------------------------
                POLOHA_LED 1  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
UP1A:   lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF12, UP2, 2, %COUNT  ; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, UP1A     ;-; mame uz 1. spomalovaciu clonku?
        CLR_FLOOR_ERR   ERRF12
        ZAKMITC MB2             ; Pockame, kym z nej odideme      
        ;setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     UP1_MB2       ;-; a prejdi do stavu UP1_MB2
        
        
UP1_MB2:
        ;--------------------------
        CFCSS     2, 22, 13, -1, -1
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym odideme z poschodia (Clonky MB1)
UP1_MB2A: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        SET_FLOOR_ERR   MB1, ERRF12, UP2, 2, %COUNT
        jb      MB2, UP1_MB2A  ;-; mame uz aj druhu spomalovaciu clonku?  
        CLR_FLOOR_ERR   ERRF12   
        ;setb    LEDU            ; Rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;   
        ZAKMITC MB2             ; Pockame, kym z nej odideme

UP1_MB2_CFC:     
        ;--------------------------
        CFCSS     12, 14, -1, -1, -1
        ;--------------------------
        ZASTAV  2, U            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0) 
        jnz     U1_MB2C       ;-; Ak ano, zastav
        NAJVYSSIE               ; | ..a sme na najvyssom privolanom poschodi? (potom stojime urcite)
        LCJNE   A, #2, UP1_MB1  ; |   ak nie, nezastavujeme 
        VYSSIE_KABINA 2         ; | ..ok, sme na najvyssom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      U1_MB2C         ; |   ak neni zastavujem         
        jmp     UP1_MB1          ; |   inak nezastavim        
U1_MB2C: setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;         
        jmp     UP1_STOP       ;-; a prejdi do stavu UP1_STOP 
        
        
UP1_MB1:
        ;--------------------------
        CFCSS     6, 10, 9, 14, -1
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym z nej odideme
UP1_MB1_C:        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF2, UP2_MB2, 2, %COUNT ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, UP1_MB1_C  ;-; Sme na zastavovacej clonke?
        ljmp    UP2             ; |   inak nezastavim        

UP1_STOP:
        ;--------------------------
        CFCSS     28, 16, 9, 20, -1
        ;--------------------------
UP1_STOP_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF2, UP2_MB2, 2, %COUNT ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, UP1_STOP_C  ;-; Sme na zastavovacej clonke?      
        clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj) 
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR2        ;-; a prejdi do stavu FLOOR2   

;------------------------------------------------------------------------------- << 2. poschodie >>

FLOOR2:
        ;--------------------------
        CFCSS     15, 26, 0, 30, D1
        ;--------------------------
                POLOHA_LED 2  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        clr     STOPPED
        TIMER2  60              ; (Timer - 3s)
        ROZSVIET_SMER_LED
F2S:    lcall   READPORTS     ;-; nacitanie dat
        ljnb    MB2, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ljnb    SKRH, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ljnb    SKRD, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ZRUS_POSCH 2
        jnb		   T2_F, F2S			; Uz presiel minimalny cas na poschodi? Ak nie, nejdeme dalej
        KABINOVE_SVETLO         ; Rozsviet kabinove svetlo a smerovu signalizaciu ak je v kabine osoba
        jb      DPK, F2S        ; Mam pretazenu kabinu? (Ak ano, tak sa nepohnem)
        jnb     DOORCLSD, F2S   ; Su otvorene dvere? Ak ano, tak nejdem dalej.
        JE_VYBRATE_POSCHODIE F2S; Je v kabine osoba, ktora este nevybrala poschodie? Ak ano, nejdeme dalej.
        ;clr     PKO2          ;-; vynulovanie volby poschodia na ktorom stojim
        ;clr     PO2U            ;
        ;clr     PO2D            ;
        ;lcall   WRITEPORTS      ;
        ;jb      DPK, F2S        ; Mam pretazenu kabinu? (Ak ano, tak sa nepohnem)
        ;_BP_
        mov     R0, #ERRFLOOR_U ;   Default predpokladam, ze mam namierene hore (pozeram poruchy poschodia smerom hore)
        mov     R1, #11111000b  ;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) kabina
        mov     R2, #11111000b  ;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) sachta
        jb      UPOld, F2OK     ;   Je to pravda? Naozaj som doteraz isiel hore?
        mov     A, R1           ;       Ak nie, znegujeme masku kabiny
        cpl     A               ;       |
        mov     R1, A           ;       |
        mov     A, R2           ;       A znegujeme aj masku sachty
        cpl     A               ;       |
        mov     R2, A           ;       |  
        mov     A, R0           ;       A budeme pozerat poruchy poschodi smerom DOLE (ERRFLOOR_U+1 = ERRFLOOR_D)
        xrl     A, #01h         ;       | Znegujem posledny bit adresy registra s poruchovymi poschodiami (ERRFLOOR_U na ERRFLOOR_D a naopak)
        mov     R0, A           ;       |  
F2OK:   ; Pohyb v jednom smere (nevieme v ktorom)
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Kabina)
        mov     B, @R0          ;  | Maskujem chybne poschodia
        anl     B, #00001100b   ;  | na krajne poschodia dovolim ist
        xrl     B, #0FFH        ;  |
        anl     A, B            ;  |
        anl     A, #00011010b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R1           ;  | 
        ljnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
                                ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Sachta)
        mov     A, INPORTA      ; Mam v kabine nieco stlacene?
        mov     B, @R0          ;  | Maskujem chybne poschodia
        anl     B, #00001100b   ;  | na krajne poschodia dovolim ist
        xrl     B, #0FFH        ;  | |
        anl     A, B            ;  | |
        anl     A, #00011010b   ;  | Beriem iba bity predstavujuce tlacidla poschodi (kabina) 
        jnz     F2SW            ;  | Ak ano, idem rovno zistovat opacny smer.
        mov     A, INPORTC      ; Mam stlacene nieco v sachte (mojim smerom)?    
        anl     A, #00111001b   ;  | Beriem iba bity predstavujuce tlacidla privolavacov
        anl     A, R2           ;  |   
        mov     B, @R0          ;  | Maskujem chybne poschodia (v smere hore)   ???   
        ;ANLB    ACC.0, B.1      ;  | 
        ANLB    ACC.1, B.2      ;  | 
        ANLB    ACC.2, B.2      ;  |
        ANLB    ACC.3, B.3      ;  |
        ANLB    ACC.4, B.3      ;  |
        ;ANLB    ACC.5, B.4      ;  |
        jnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
        ; Pohyb v opacnom smere (nevieme v ktorom)
F2SW:   mov     A, R0           ;  Znegujem posledny bit adresy registra s poruchovymi poschodiami (ERRFLOOR_U na ERRFLOOR_D a naopak)
        xrl     A, #01h         ;  |
        mov     R0, A           ;  |
        cpl     UPOld           ;  Znegujem stary posun
        cpl     DOWNOld         ;  |
        mov     A, R1           ;  Znegujeme masky
        cpl     A               ;  |
        mov     R1, A           ;  |
        mov     A, R2           ;  |
        cpl     A               ;  |
        mov     R2, A           ;  |               
        mov     A, INPORTA      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Kabina)
        mov     B, @R0          ;  | Maskujem chybne poschodia
        anl     B, #00001100b   ;  | na krajne poschodia dovolim ist
        xrl     B, #0FFH        ;  | |
        anl     A, B            ;  | |
        anl     A, #00011010b   ;  | Beriem iba bity predstavujuce tlacidla poschodi   
        anl     A, R1           ;  | 
        jnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
        mov     A, INPORTC      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Sachta)
        anl     A, #00111001b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R2           ;  | 
        mov     B, @R0          ;  | Maskujem chybne poschodia (v smere hore)   ???   
        ;ANLB    ACC.0, B.1      ;  | 
        ANLB    ACC.1, B.2      ;  | 
        ANLB    ACC.2, B.2      ;  |
        ANLB    ACC.3, B.3      ;  |
        ANLB    ACC.4, B.3      ;  |
        ;ANLB    ACC.5, B.4      ;  |
        jnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
        jmp     F2S           ;-; nemame sa kde hybat, tak opakujeme zistovanie
F2:     jb      UPOld, F2UP     ;   
        jmp     F2DOWN          ;
F2UP:   SET_UP                  ; rychly pohyb hore
        SET_FAST                ; 
        lcall   WRITEPORTS      ;   
        jmp     UP2           ;-; prejdi do stavu UP2    
F2DOWN: SET_DOWN                  ; rychly pohyb dole
        SET_FAST                ; 
        lcall   WRITEPORTS      ; 
        jmp     DOWN2         ;-; prejdi do stavu DOWN2    
        
            
UP2:
        ;--------------------------
        CFCSS     8, 7, 18, 0, D1
        ;--------------------------
                POLOHA_LED 2  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
UP2A:   lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF23, UP3, 3, %COUNT  ; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, UP2A     ;-; mame uz 1. spomalovaciu clonku?
        CLR_FLOOR_ERR   ERRF23
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        ;setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     UP2_MB2       ;-; a prejdi do stavu UP2_MB2
        
        
UP2_MB2:
        ;--------------------------
        CFCSS     18, 26, 8, -1, D2
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym odideme z predchadzajucej clonky       
UP2_MB2A: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF23, UP3, 3, %COUNT ; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, UP2_MB2A  ;-; mame uz aj druhu spomalovaciu clonku?   
        CLR_FLOOR_ERR   ERRF23       
        ;setb    LEDU            ; Rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        
UP2_MB2_CFC:     
        ;--------------------------
        CFCSS     1, 19, -1, -1, -1
        ;--------------------------        
        ZASTAV  3, U            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0)
        jnz     U2_MB2C       ;-; Ak ano, zastav
        NAJVYSSIE               ; | ..a sme na najvyssom privolanom poschodi z kabiny? (potom stojime urcite)
        LCJNE   A, #3, UP2_MB1  ; |   ak nie, nezastavujeme  
        VYSSIE_KABINA 3         ; | ..ok, sme na najvyssom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      U2_MB2C         ; |   ak neni zastavujem  
        ljmp    UP2_MB1         ; |   inak nezastavim
U2_MB2C: setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     UP2_STOP       ;-; a prejdi do stavu UP2_STOP 
      
UP2_MB1:
        ;--------------------------
        CFCSS     26, 27, 0, 17, -1
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym z nej odideme
UP2_MB1_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF3, UP3_MB2, 3, %COUNT  ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, UP2_MB1_C  ;-; Sme na zastavovacej clonke?
        ljmp    UP3             ; 


UP2_STOP:
        ;--------------------------
        CFCSS     4, 5, 9, 15, -1
        ;--------------------------
UP2_STOP_C:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF3, UP3_MB2, 3, %COUNT ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, UP2_STOP_C  ;-; Sme na zastavovacej clonke?     
        clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj)
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR3        ;-; a prejdi do stavu FLOO
        
DOWN2:
        ;--------------------------
        CFCSS     24, 9, 6, 9, D2
        ;--------------------------
                POLOHA_LED 2  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
DOWN2_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF12, DOWN2ERR, 1, %COUNT ; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jmp     DOWN2ERR_CONTINUE
DOWN2ERR:
        clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     FLOOR1        ;-; a prejdi do stavu FLOOR1 
DOWN2ERR_CONTINUE:
        jb      MB2, DOWN2_C    ;-; mame uz 1. spomalovaciu clonku?
        CLR_FLOOR_ERR   ERRF12
        ZAKMITC MB2             ; Pockame, kym z nej odideme      
        ;setb    LEDU            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     DOWN2_MB2     ;-; a prejdi do stavu DOWN2_MB2


DOWN2_MB2:
        ;--------------------------
        CFCSS     31, 14, 1, -1, D2
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym odideme z predchadzajucej clonky       
DOWN2_MB2A:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF12, DOWN2_MB2ERR, 1, %COUNT ; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jmp     DOWN2_MB2ERR_CONTINUE
DOWN2_MB2ERR:
        clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     FLOOR1        ;-; a prejdi do stavu FLOOR1 
DOWN2_MB2ERR_CONTINUE:
        jb      MB2, DOWN2_MB2A ;-; mame uz aj druhu spomalovaciu clonku?    
        CLR_FLOOR_ERR   ERRF12      
        ;setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
;        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
;        anl     A, #00000010b ;-;
;        jz      DOWN2_MB1     ;-;       Ak nie, chod do stavu DOWN2_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     DOWN2_MB1     ;-; a prejdi do stavu DOWN2_MB1
DOWN2_MB1:    
        ;--------------------------
        CFCSS     14, 17, 16, -1, -1
        ;--------------------------
DOWN2_MB1_C: lcall   READPORTS       ; nacitanie dat
        jnb     MB1, D2_MB1C  ;-; Sme na zastavovacej clonke? (tu zastavujeme v kazdom pripade)
        jb      SKRD, DOWN2_MB1_C   ; Sme na hornej porovnavacej clonke? (tu zastavujeme v kazdom pripade)
        setb    ERRF1_D
        inc     ERRF1_C
;        jmp     DOWN2_MB1_C       ; Ak sme nechytili ani jednu clonku, opakujeme
D2_MB1C: clr     STOPPED         ; Priznak STOPPED vynulujem, uz som ho osetril
        clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR1        ;-; a prejdi do stavu FLOOR2      


;------------------------------------------------------------------------------- << 3. poschodie >>

FLOOR3:
        ;--------------------------
        CFCSS     10, 7, 16, 19, D1
        ;--------------------------
                POLOHA_LED 3  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        clr     STOPPED
        TIMER2  60              ; (Timer - 3s)
        ROZSVIET_SMER_LED
F3S:    lcall   READPORTS     ;-; nacitanie dat
        ljnb    MB2, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ljnb    SKRH, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ljnb    SKRD, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ZRUS_POSCH 3
        jnb		   T2_F, F3S			; Uz presiel minimalny cas na poschodi? Ak nie, nejdeme dalej
        KABINOVE_SVETLO         ; Rozsviet kabinove svetlo a smerovu signalizaciu ak je v kabine osoba
        jb      DPK, F3S        ; Mam pretazenu kabinu? (Ak ano, tak sa nepohnem)
        jnb     DOORCLSD, F3S   ; Su otvorene dvere? Ak ano, tak nejdem dalej.
        JE_VYBRATE_POSCHODIE F3S; Je v kabine osoba, ktora este nevybrala poschodie? Ak ano, nejdeme dalej.          
        ;clr     PKO3          ;-; vynulovanie volby poschodia na ktorom stojim
        ;clr     PO3U            ;
        ;clr     PO3D            ;
        ;lcall   WRITEPORTS      ;
        ;jb      DPK, F3S        ; Mam pretazenu kabinu? (Ak ano, tak sa nepohnem)
        mov     R0, #ERRFLOOR_U ; Default predpokladam, ze mam namierene hore (pozeram poruchy poschodia smerom hore)
        mov     R1, #11110000b;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) kabina
        mov     R2, #11100000b;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) sachta
        jb      UPOld, F3OK     ;   Je to pravda? Naozaj som doteraz isiel hore?
        mov     A, R1           ;       Ak nie, znegujeme masku kabiny
        cpl     A               ;       |
        mov     R1, A           ;       |
        mov     A, R2           ;       A znegujeme aj masku sachty
        cpl     A               ;       |
        mov     R2, A           ;       |     
        mov     A, R0           ;       A budeme pozerat poruchy poschodi smerom DOLE (ERRFLOOR_U+1 = ERRFLOOR_D)
        xrl     A, #01h         ;       | Znegujem posledny bit adresy registra s poruchovymi poschodiami (ERRFLOOR_U na ERRFLOOR_D a naopak)
        mov     R0, A           ;       |    
F3OK:   ; Pohyb v jednom smere (nevieme v ktorom)
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Kabina)
        mov     B, @R0          ;  | Maskujem chybne poschodia
        anl     B, #00001100b   ;  | na krajne poschodia dovolim ist 
        xrl     B, #0FFH        ;  | |
        anl     A, B            ;  | |
        anl     A, #00010110b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R1           ;  | 
        ljnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
                                ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Sachta)
        mov     A, INPORTA      ; Mam v kabine nieco stlacene?
        mov     B, @R0          ;  | Maskujem chybne poschodia
        anl     B, #00001100b   ;  | na krajne poschodia dovolim ist
        xrl     B, #0FFH        ;  | |
        anl     A, B            ;  | |
        anl     A, #00010110b   ;  | Beriem iba bity predstavujuce tlacidla poschodi (kabina)
        jnz     F3SW            ;  | Ak ano, idem rovno zistovat opacny smer.
        mov     A, INPORTC      ; Mam stlacene nieco v sachte (mojim smerom)?    
        anl     A, #00100111b   ;  | Beriem iba bity predstavujuce tlacidla privolavacov
        anl     A, R2           ;  |   
        mov     B, @R0          ;  | Maskujem chybne poschodia (v smere hore)   ???   
        ;ANLB    ACC.0, B.1      ;  | 
        ANLB    ACC.1, B.2      ;  | 
        ANLB    ACC.2, B.2      ;  |
        ANLB    ACC.3, B.3      ;  |
        ANLB    ACC.4, B.3      ;  |
        ;ANLB    ACC.5, B.4      ;  |
        jnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
        ; Pohyb v opacnom smere (nevieme v ktorom)
F3SW:   mov     A, R0           ;  Znegujem posledny bit adresy registra s poruchovymi poschodiami (ERRFLOOR_U na ERRFLOOR_D a naopak)
        xrl     A, #01h         ;  |
        mov     R0, A           ;  |
        cpl     UPOld           ;  Znegujem stary posun
        cpl     DOWNOld         ;  |
        mov     A, R1           ;  Znegujeme masky
        cpl     A               ;  |
        mov     R1, A           ;  |
        mov     A, R2           ;  |
        cpl     A               ;  |
        mov     R2, A           ;  |               
        mov     A, INPORTA      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Kabina)
        mov     B, @R0          ;  | Maskujem chybne poschodia
        anl     B, #00001100b   ;  | na krajne poschodia dovolim ist
        xrl     B, #0FFH        ;  | |
        anl     A, B            ;  | |
        anl     A, #00010110b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R1           ;  | 
        jnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
        mov     A, INPORTC      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Sachta)
        anl     A, #00100111b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R2           ;  | 
        mov     B, @R0          ;  | Maskujem chybne poschodia (v smere hore)   ???   
        ;ANLB    ACC.0, B.1      ;  | 
        ANLB    ACC.1, B.2      ;  | 
        ANLB    ACC.2, B.2      ;  |
        ANLB    ACC.3, B.3      ;  |
        ANLB    ACC.4, B.3      ;  |
        ;ANLB    ACC.5, B.4      ;  |
        jnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
        jmp     F3S           ;-; nemame sa kde hybat, tak opakujeme zistovanie
F3:     jb      UPOld, F3UP     ;   
        jmp     F3DOWN          ;
F3UP:   SET_UP                  ; rychly pohyb hore
        SET_FAST                ; 
        lcall   WRITEPORTS      ; 
        jmp     UP3           ;-; prejdi do stavu UP2    
F3DOWN: SET_DOWN                  ; rychly pohyb dole
        SET_FAST                ; 
        lcall   WRITEPORTS      ; 
        jmp     DOWN3         ;-; prejdi do stavu UP2    
     
     
UP3:
        ;--------------------------
        CFCSS     11, 17, 14, 0, D1
        ;--------------------------
                POLOHA_LED 3  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
UP3A:   lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF34, UP3ERR, 4, %COUNT  ; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jmp     UP3ERR_CONTINUE
UP3ERR:
        clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj)
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ;
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     FLOOR4        ;-; a prejdi do stavu FLOOR4 
UP3ERR_CONTINUE:
        jb      MB2, UP3A     ;-; mame uz 1. spomalovaciu clonku?
        CLR_FLOOR_ERR   ERRF34
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        ;setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     UP3_MB2       ;-; a prejdi do stavu UP3_MB2

UP3_MB2:
        ;--------------------------
        CFCSS     3, 8, 6, -1, D2
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym odideme z predchadzajucej clonky       
UP3_MB2A:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF34, UP3_MB2ERR, 4, %COUNT ; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jmp     UP3_MB2ERR_CONTINUE
UP3_MB2ERR:
        clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj)
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ;
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     FLOOR4        ;-; a prejdi do stavu FLOOR4
UP3_MB2ERR_CONTINUE:
        jb      MB2, UP3_MB2A  ;-; mame uz aj druhu spomalovaciu clonku?    
        CLR_FLOOR_ERR   ERRF34      
        ;setb    LEDU            ; Rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme 
;        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
;        anl     A, #00010000b ;-;
;        jz      UP3_MB1       ;-;       Ak nie, chod do stavu UP3_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     UP3_MB1       ;-; a prejdi do stavu UP3_MB1 


UP3_MB1:
        ;--------------------------
        CFCSS     5, 6, 0, -1, -1
        ;--------------------------
        ZAKMITC MB2
UP3_MB1_C: lcall   READPORTS    ; nacitanie dat
        jnb     MB1, U3_MB1C    ; Sme na zastavovacej clonke? (tu zastavujeme v kazdom pripade)
        jb      SKRH, UP3_MB1_C ; Sme na hornej porovnavacej clonke? (tu zastavujeme v kazdom pripade) 
        setb    ERRF4_U
        inc     ERRF4_C
;        jmp     U3_MB1C 
;U3_NE:  jnb     MB1, U3_MB1C    ; Sme na zastavovacej clonke? (tu zastavujeme v kazdom pripade)
;        jmp     UP3_MB1_C       ; Ak sme nechytili ani jednu clonku, opakujeme. 
U3_MB1C: clr     STOPPED        ; Priznak STOPPED vynulujem, uz som ho osetril
        clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj)
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR4        ;-; a prejdi do stavu FLOOR4   


DOWN3:
        ;--------------------------
        CFCSS     27, 2, 22, 10, D2
        ;--------------------------
                POLOHA_LED 3  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
DOWN3A: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF23, DOWN2, 2, %COUNT  ; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN3A   ;-; mame uz 1. spomalovaciu clonku?
        CLR_FLOOR_ERR   ERRF23
        ZAKMITC MB2             ; Pockame, kym z nej odideme   
        ;setb    LEDU            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     DOWN3_MB2     ;-; a prejdi do stavu DOWN3_MB2


DOWN3_MB2:
        ;--------------------------
        CFCSS     9, 4, -1, 24, D1
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym odideme z predchadzajucej clonky       
DOWN3_MB2A:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF23, DOWN2, 2, %COUNT ; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN3_MB2A ;-; mame uz aj druhu spomalovaciu clonku?    
        CLR_FLOOR_ERR   ERRF23      
        ;setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
;        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
;        anl     A, #00000100b ;-;
;        jz      DOWN3_MB1     ;-;       Ak nie, chod do stavu DOWN3_MB1
DOWN3_MB2_CFC:
        ;--------------------------
        CFCSS     16, 25, -1, -1, -1
        ;--------------------------
        ZASTAV  2, D            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0)
        jnz     D3_MB2C         ; Ak ano, zastav
        NAJNIZSIE               ; | ..a sme na najnizsom privolanom poschodi z kabiny? (potom stojime urcite)
        LCJNE   A, #2, DOWN3_MB1; |   ak nie, nezastavujeme  
        NIZSIE_KABINA 2         ; | ..ok, sme na najnizsom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      D3_MB2C         ; |   ak neni zastavujem                  
        ljmp    DOWN3_MB1       ;-; |        
D3_MB2C: setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     DOWN3_STOP     ;-; a prejdi do stavu DOWN3_STOP


DOWN3_MB1:    
        ;--------------------------
        CFCSS     17, 1, -1, 0, -1
        ;--------------------------
DOWN3_MB1_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF2, DOWN2_MB2, 2, %COUNT  ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, DOWN3_MB1_C;-; Sme na zastavovacej clonke?
;        CLR_FLOOR_ERR   ERRF2
;        ZASTAV  2, D            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0)
;        clr     STOPPED         ; Priznak STOPPED vynulujem, uz som ho osetril
;        jnz     D3_MB1C         ; Ak ano, zastav
;        NAJNIZSIE               ; | ..a sme na najnizsom privolanom poschodi z kabiny? (potom stojime urcite)
;        LCJNE   A, #2, DOWN2    ; |   ak nie, nezastavujeme  
;        NIZSIE_KABINA 2         ; | ..ok, sme na najnizsom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
;        jz      D3_MB1C         ; |   ak neni zastavujem                  
        ljmp    DOWN2         ;-; |        
;D3_MB1C: clr     DOWN            ; zastav motor
;        setb    DOWNOld         ;       (a zalohuj)
;        clr     UPOld           ;       (a zalohuj)
;        clr     FAST            ; 
;        lcall   WRITEPORTS      ; 
;        jmp     FLOOR2        ;-; a prejdi do stavu FLOOR2 
DOWN3_STOP: 
        ;--------------------------
        CFCSS     21, 5, 0, 4, -1
        ;--------------------------
DOWN3_STOP_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF2, DOWN2_MB2, 2, %COUNT ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, DOWN3_STOP_C;-; Sme na zastavovacej clonke?  
;        CLR_FLOOR_ERR   ERRF2     
        clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR2        ;-; a prejdi do stavu FLOOR2         

        
;------------------------------------------------------------------------------- << 4. poschodie >>

FLOOR4:
        ;--------------------------
        CFCSS     19, 22, -1, -1, D1
        ;--------------------------
                POLOHA_LED 4  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        clr     STOPPED
        TIMER2  60              ; (Timer - 3s)
        ROZSVIET_SMER_LED
F4S:    lcall   READPORTS     ;-; nacitanie dat
        ljnb    MB2, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ljnb    SKRD, ERRFLOOR   ; chyba, kabina sa pohla, ked sa nemala!
        ZRUS_POSCH 4
        jnb		   T2_F, F4S			; Uz presiel minimalny cas na poschodi? Ak nie, nejdeme dalej
        KABINOVE_SVETLO         ; Rozsviet kabinove svetlo a smerovu signalizaciu ak je v kabine osoba
        jb      DPK, F4S        ; Mam pretazenu kabinu? (Ak ano, tak sa nepohnem)
        jnb     DOORCLSD, F4S   ; Su otvorene dvere? Ak ano, tak nejdem dalej.
        JE_VYBRATE_POSCHODIE F4S; Je v kabine osoba, ktora este nevybrala poschodie? Ak ano, nejdeme dalej.
        ;clr     PKO4          ;-; vynulovanie volby poschodia na ktorom stojim
        ;clr     PO4            ;
        ;lcall   WRITEPORTS      ;
        ;jb      DPK, F4S        ; Mam pretazenu kabinu? (Ak ano, tak sa nepohnem)
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco menej ako poschodie na ktorom stojim (Kabina)
        mov     B, ERRFLOOR_D   ; | maskujem chybne poschodia
        anl     B, #00001100b   ;  | na krajne poschodia dovolim ist
        xrl     B, #0FFH        ; | |
        anl     A, B            ; | |
        anl     A, #00001110b ;-;
        jnz     F4OK          ;-; ak ano, ideme na to
        mov     A, INPORTC      ; zistenie, ci bolo stlacene nieco menej ako poschodie na ktorom stojim (Sachta)
        anl     A, #00011111b ;-;
        ;ANLB    ACC.0, ERRF1_D  ; maskujem chybne poschodia (v smere hore)
        ANLB    ACC.1, ERRF2_D  ; |
        ANLB    ACC.2, ERRF2_D  ; |
        ANLB    ACC.3, ERRF3_D  ; |
        ;ANLB    ACC.4, ERRF3_D  ; |
        jnz     F4OK          ;-; ak ano, ideme na to
        jmp     F4S             ; Nemam sa kde hnut, opakujem
F4OK:   SET_DOWN                  ; rychly pohyb dole
        SET_FAST                ; 
        lcall   WRITEPORTS      ; 
        jmp     DOWN4         ;-; prejdi do stavu DOWN4 


DOWN4:
        ;--------------------------
        CFCSS     22, 5, -1, 15, -1
        ;--------------------------
                POLOHA_LED 4  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
DOWN4_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF34, DOWN3, 3, %COUNT    ; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN4_C    ;-; mame uz 1. spomalovaciu clonku?
        CLR_FLOOR_ERR   ERRF34
        ZAKMITC MB2             ; Pockame, kym z nej odideme      
        ;setb    LEDU            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     DOWN4_MB2     ;-; a prejdi do stavu DOWN4_MB2
        
        
DOWN4_MB2:
        ;--------------------------
        CFCSS     23, 1, -1, 14, -1
        ;--------------------------
        ZAKMITC MB2             ; Pockame, kym odideme z predchadzajucej clonky       
DOWN4_MB2A:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB1, ERRF34, DOWN3, 3, %COUNT    ; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN4_MB2A ;-; mame uz aj druhu spomalovaciu clonku?   
        CLR_FLOOR_ERR   ERRF34       
        ;setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
;        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
;        anl     A, #00001000b ;-;
;        jz      DOWN4_MB1     ;-;       Ak nie, chod do stavu DOWN4_MB1
DOWN4_MB2_CFC:
        ;--------------------------
        CFCSS     7, 16, -1, -1, -1
        ;--------------------------
        ZASTAV  3, D            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0) 
        jnz     D4_MB2C       ;-; Ak ano, zastav
        NAJNIZSIE               ; | ..a sme na najnizsom privolanom poschodi z kabiny? (potom stojime urcite)
        LCJNE   A, #3, DOWN4_MB1; |   ak nie, nezastavujeme  
        NIZSIE_KABINA 3         ; | ..ok, sme na najnizsom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      D4_MB2C         ; |   ak neni zastavujem          
        ljmp    DOWN4_MB1       ;-; |       
D4_MB2C: setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     DOWN4_STOP     ;-; a prejdi do stavu DOWN4_STOP
        
        
DOWN4_MB1:    
        ;--------------------------
        CFCSS     25, 30, 20, 0, -1
        ;--------------------------
DOWN4_MB1_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF3, DOWN3_MB2, 3, %COUNT  ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, DOWN4_MB1_C ;-; Sme na zastavovacej clonke?
;        CLR_FLOOR_ERR   ERRF3
;        ZASTAV  3, D            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0)
;        clr     STOPPED         ; Priznak STOPPED vynulujem, uz som ho osetril 
;        jnz     D4_MB1C       ;-; Ak ano, zastav
;        NAJNIZSIE               ; | ..a sme na najnizsom privolanom poschodi z kabiny? (potom stojime urcite)
;        LCJNE   A, #3, DOWN3    ; |   ak nie, nezastavujeme  
;        NIZSIE_KABINA 3         ; | ..ok, sme na najnizsom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
;        jz      D4_MB1C         ; |   ak neni zastavujem          
        ljmp    DOWN3         ;-; |       
;D4_MB1C: clr     DOWN            ; zastav motor
;        setb    DOWNOld         ;       (a zalohuj)
;        clr     UPOld           ;       (a zalohuj)
;        clr     FAST            ; 
;        lcall   WRITEPORTS      ; 
;        jmp     FLOOR3        ;-; a prejdi do stavu FLOOR3 

                
DOWN4_STOP:    
        ;--------------------------
        CFCSS     13, 10, 0, -1, -1
        ;--------------------------
DOWN4_STOP_C: lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        SET_FLOOR_ERR   MB2, ERRF3, DOWN3_MB2, 3, %COUNT  ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, DOWN4_STOP_C ;-; Sme na zastavovacej clonke?
;        CLR_FLOOR_ERR   ERRF3
        clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR3        ;-; a prejdi do stavu FLOOR3                   
  
  
  

        
ERR_SKRD:    
        clr     DOWN            ; zastav motor
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        mov     DPTR, #STR_ERR_SKRD         ; vypis info o neocakavanom nacitani synchronizacnej clonky
        lcall   DISPSTR         ;
        ; Nastavenie spravneho priznaku G a D     
        mov     G, #30          ;
        mov     D1, #0           ;
        mov     D2, #0           ;
        ljmp    FLOOR1    
        
ERR_SKRH: 
        clr     FAST            ; zastav motor
        clr     SLOW            ; 
        lcall   WRITEPORTS      ; 
        mov     DPTR, #STR_ERR_SKRH         ; vypis info o neocakavanom nacitani synchronizacnej clonky
        lcall   DISPSTR         ;
        ; Nastavenie spravneho priznaku G a D     
        mov     G, #5           ;
        mov     D1, #0           ;
        mov     D2, #0           ;
        ljmp    FLOOR4 
        
ERRFLOOR:
        clr     FAST            ; zastav motor
        clr     SLOW            ; 
        lcall   WRITEPORTS      ; 
        mov     DPTR, #STR_ERR_FLOOR         ; vypis info o neocakavanom pohnuti sa kabiny z poschodia
        lcall   DISPSTR         ;
        ; rozblikaj vsetky LEDky
        ; pockaj kym vsetci vystupia
        ; pockaj este 3 sakundy
        TIMER2  60
        jnb		  T2_F, $			; 
        ;zresetuj
        ljmp     START
        

           
CFCERR:
        clr     UP              ; zastav motor
        clr     DOWN            ; 
        clr     FAST            ; 
        clr     SLOW            ; 
        lcall   WRITEPORTS      ; 
        mov     DPTR, #STR_ERR_CFC         ; vypis info o zisteni chyby toku programu
        lcall   DISPSTR         ;
                
ENDPROG:
        TIMER2  20
        jnb     T2_F, $
        setb    KS
        call    WRITEPORTS     
        TIMER2  20
        jnb     T2_F, $
        clr     KS
        call    WRITEPORTS
        jmp     ENDPROG 

        ret
        
        
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INT_TIMER0
; Obsluha prerusenia timera 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
INT_TIMER0:
        push    PSW
        push    ACC
        push    B
        push    P0
        push    P1
        push    P2
        push    P3
        ;push    OUTPORTC
        
        mov     A, T0_C ;R5
        dec     T0_C    ;R5
        jz      INT_TIMER0_MAIN    
        sjmp    INT_TIMER0_END
INT_TIMER0_MAIN:
        mov     A, #TIMER0CONST;R6
        mov     T0_C, A ;R5, A
        mov     A, ERRFLOOR_U
        orl     A, ERRFLOOR_D
        anl     A, #00011110b
        rl      A
        rl      A
        rl      A    
        xrl     OUTPORTB, A     
                      
        clr    EA
        mov     p0, OUTPORTB 
        mov     p2, #i8255OUTB
        clr     WRNOT
        nop
        nop
        nop
        nop
        setb    WRNOT
        setb    EA
     
INT_TIMER0_END:
        ;pop     OUTPORTC
        pop     P3
        pop     P2
        pop     P1
        pop     P0 
        pop     B       
        pop     ACC
        pop     PSW
	reti 
        
;INT_TIMER0:
;        push    ACC
;        mov     A, R7  
;        dec     R7               
;        jnz     INT_TIMER0_END     
;        mov     R7, #20h
;        jb      LEDU, INT_TIMER0_CLEAR       
;        setb    LEDU
;        setb    LEDD
;        jmp     INT_TIMER0_WRITE
;INT_TIMER0_CLEAR:        
;        ;clr     LEDU
;        ;clr     LEDD
;INT_TIMER0_WRITE: 
;        lcall   WRITEPORTS
;INT_TIMER0_END: 
;        setb    LEDU
;        lcall   WRITEPORTS       
;        pop     ACC
;        reti
        
        
; rutina time delay 1 ms pre oscilator s frekvenciou 11.0592 MHz
; 1 instrukcia 2 takty? => 11.0592/2 = pocet instrukcii potrebnych na 1 sekundu
; 11.0592MHz/2000 = zdrzanie 1 ms
TIME10MS:
        push    PSW
        push    1 ;R1
        push    2 ;R2

;        mov     R1,#063h        ; 2
;                                ; *** 100x
;TIME0:  mov     R2,#0FFh        ; 2 
;TIME1:  djnz    R2,TIME1        ; 256*2   
;        mov     R2,#0FFh        ; 2       
;TIME2:  djnz    R2,TIME2        ; 256*2 
;        mov     R2,#024h        ; 2       
;TIME3:  djnz    R2,TIME3        ; 36*2
;        nop                     ; 1
;        djnz    R1,TIME0        ; 2
;                                ; ***
;        mov     R1,#02Ah        ; 2 
;TIME4:  djnz    R1,TIME4        ; 43*2

        TIMER2  1
TIME:   ;mov     WDTRST, #01Eh
        ;mov     WDTRST, #0E1h
        jnb     TR2, TIMEEND 
        jnb		  T2_F, TIME					 ;pockame, kym prejde 50-100 ms. 
TIMEEND:          
        pop     2 ;R2
        pop     1 ;R1
        pop     PSW
        ret                     ; koniec
        
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; STOP
; osetri stlacenie tlacidla STOP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
STOP:
        push    PSW
        push    ACC
        
        
        setb    STOPPED
        clr     FAST
        clr     SLOW
        mov     A, #11100001b
        anl     OUTPORTA, A 
        push    OUTPORTC     ; ulozenie stavu smerovej signalizacie
        setb    LEDU
        setb    LEDD
        lcall   WRITEPORTS
        
        ;lcall   WAITFORTIMER
        TIMER2  40
STOPC:  lcall   READPORTS1
        mov     A, INPORTA
        anl     A, #00011110b
        jz      STOPC
        jnb     T2_F, STOPC 
             
             
        clr     LEDU        
        clr     LEDD     
        pop     ACC         ; obnovenie stavu smerovej signalizacie  
        anl     A, 0C0h
        orl     OUTPORTC, A
        
        setb    SLOW
        lcall   WRITEPORTS
        
        
        pop    ACC
        pop    PSW
        ret        
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; READPORTS1
; precita nove hodnoty na portoch
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READPORTS1:
        push    PSW
        clr     EA                  ;Treba zakazat prerusenia
        
        ;mov     WDTRST, #01Eh
        ;mov     WDTRST, #0E1h
        
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
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        setb    EA                 ;znovu spustime prerusenia .
        pop     PSW
        ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; READPORTS
; precita nove hodnoty na portoch
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
READPORTS:
        push    PSW
        push    ACC

        clr     EA                  ;Treba zakazat prerusenia
        
        ;mov     WDTRST, #01Eh
        ;mov     WDTRST, #0E1h
        
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
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        setb    EA                 ;znovu spustime prerusenia
        
        
        
        
        jnb     DPK, READPORTS_C1
        clr     FAST
        setb    SLOW
READPORTS_C1:         
        jb      STOPNOT, READPORTS_C
        lcall   STOP
READPORTS_C:        
        mov     A, INPORTA
        anl     A, #00011110b
        orl     OUTPORTA, A
        call    WRITEPORTS              ; aktualizuj signalizaciu na ovladacom paneli
        mov     A, INPORTC
        anl     A, #00111111b
        orl     OUTPORTC, A
        call    WRITEPORTS              ; aktualizuj signalizaciu na ovladacom paneli
        
        pop    ACC
        pop    PSW
        ret
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WRITEPORTS
; spravi zalohu vystupnych registrov a posle data von
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WRITEPORTS:
        push    PSW
        clr     EA                  ;Treba zakazat prerusenia
        
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
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        setb     EA                  ;Treba zakazat prerusenia
        pop     PSW
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DISPSTR
; posle na seriovu linku retazec na adrese DPTR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DISPSTR:
        push    PSW
        push    ACC
        push    DPH
        push    DPL
DSPS_LOOP: 
        ;mov     WDTRST, #01Eh
        ;mov     WDTRST, #0E1h          
        clr     A
        movc    A, @A+DPTR
        jz      DSPS_END
        ;jnb     TI, $ 
        ;clr     TI
        ;mov     SBUF, A
        
        lcall   PRINTCHAR
        inc     DPTR
        sjmp    DSPS_LOOP
DSPS_END:
        pop     DPL
        pop     DPH
        pop     ACC
        pop     PSW
        ret
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DISPSTR - no wdt
; posle na seriovu linku retazec na adrese DPTR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DISPSTRNOWDT:
        push    PSW
        push    ACC
        push    DPH
        push    DPL
DSPSNWDT_LOOP:           
        clr     A
        movc    A, @A+DPTR
        jz      DSPSNWDT_END
        ;jnb     TI, $ 
        ;clr     TI
        ;mov     SBUF, A
        lcall   PRINTCHAR
        inc     DPTR
        sjmp    DSPSNWDT_LOOP
DSPSNWDT_END:
        pop     DPL
        pop     DPH
        pop     ACC
        pop     PSW
        ret
                                     
                                     
        $include (procLib.inc)     
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

STR_INIT:         db  0dh, 0ah, 'Riadiaci system je inicializovany.', 0dh, 0ah, 00h
STR_WDT:          db  0dh, 0ah, 'Zapinam WDT...', 0dh, 0ah, 00h
STR_RESET:          db  0dh, 0ah, 'Cakam 10 sekund...', 0dh, 0ah, 00h
STR_STOP:         db  'Riadiaci system je reinicializovany po stlaceni tlacidla STOP.', 0dh, 0ah, 00h
STR_CALIB:        db  'Kalibracia vytahu je ukoncena.', 0dh, 0ah, 00h
STR_ERR_1SPOM_C:  db  'Chyba! Vypadla spomalovacia clonka!', 0dh, 0ah, 00h
STR_ERR_2SPOM_C:  db  'Chyba! Vypadli dve spomalovacie clonky!', 0dh, 0ah, 00h
STR_ERR_ZAST_C:   db  'Chyba! Vypadla zastavovacia clonka!', 0dh, 0ah, 00h
STR_ERR_SKRH:     db  'Chyba! Neocakavane nacitanie hornej spomalovacej clonky!', 0dh, 0ah, 00h
STR_ERR_SKRD:     db  'Chyba! Neocakavane nacitanie dolnej spomalovacej clonky!', 0dh, 0ah, 00h
STR_ERR_FLOOR:     db  'Chyba! Neocakavane pohnutie kabyny z poschodia!', 0dh, 0ah, 00h
STR_CFC_START:    db  'Spustam KTP...', 0dh, 0ah, 00h
STR_ERR_CFC:      db  'Doslo k zmene KTP!', 0dh, 0ah, 00h

COM_KEEPALIVE:    db  000h, 00h, 7Eh, 00h
COM_BUSY:		      db  0FDh, 89h, 7Eh, 00h
COM_ACK:		      db  0FEh, 6Bh, 7Eh, 00h
COM_NACK:		      db  0FFh, 35h, 7Eh, 00h


        DSEG
        org     50h            ;Pozor!
STACK:  DS      10h

end