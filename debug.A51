; TODO: 
; OK - Dorob nulovanie volieb v sachte 
; Dorob 3UP a 2 DOWN (tam kde stojis vzdy)
; Asi by bolo dobre premenovat PI1, PO1 a PI4 PO4 na alternativy s koncovkami U a D
; Poriadne otestuj !!! 
; Umo+zni stlacat tlacidla aj ked bezi delay


$MOD51
$DEBUG

$include (lift.inc)

_BP_    MACRO 
        clr     P3.3
        setb    EX1
        nop
        nop
ENDM

LJZ     MACRO   NAVESTIE
        jnz     $+5
        ljmp    NAVESTIE
        nop
ENDM

LJNZ    MACRO   NAVESTIE
        jz      $+5
        ljmp    NAVESTIE
        nop
ENDM

LJB     MACRO   TESTBIT, NAVESTIE
        jnb     TESTBIT, $+6
        ljmp    NAVESTIE
        nop
ENDM

LJNB    MACRO   TESTBIT, NAVESTIE
        jb      TESTBIT, $+6
        ljmp    NAVESTIE
        nop
ENDM

CJE     MACRO   OP1, OP2, NAVESTIE
        cjne    OP1, OP2, $+7
        jmp    NAVESTIE
        nop
ENDM

LCJNE   MACRO   OP1, OP2, NAVESTIE
        cjne    OP1, OP2, $+6
        jmp     $+6
        ljmp    NAVESTIE
        nop
ENDM

ZAKMITC MACRO   TYPCLONKY
        lcall   TIME10MS        ; pockame 10 ms kym sa hodnota ustali (xe som na clonke)
        lcall   READPORTS       ; Uz sme z tej clonky prec?
        jnb     TYPCLONKY, $-3  ; 
        lcall   TIME10MS        ; pockame 10 ms  kym sa hodnota ustali (ze sme z nej naozaj zliezli)
ENDM

ZASTAV  MACRO  C_POSCH, SMER
                                        ; Chceme tu zastavit? - je toto poschodie zvolene? 
        clr     C                       ; | Idem robit cachre-machre s Carry bitom
        mov     A, #0h                  ; | Aj Acc potrebujem prazdny
        orl     C, PKI&C_POSCH          ; | Mam v tomto smere stlacene tlacidlo v kabine?
        orl     C, PI&C_POSCH&SMER      ; | Mam v tomto smere stlacene tlacidlo v sachte?
        anl     C, /DPZK                ; | a mam plne zatazenu kabinu? (lebo ak ano tak ani za boha nestojim) 
        orl     C, DPK                  ; | a mam pretazenu kabinu? (Ak ano tak stojim urcite)
        ;mov     A, bmSmerPI1U
        addc    A, #0h                  ; Ak mi v predchadzajucich krokoch vyslo, ze mam stat, tak stojim nezavisle na tlacidlach kabiny
ENDM

NAJNIZSIE  MACRO
        mov     A, INPORTC      ; INPORTC - vektor "privolavace zo sachty"               
        rlc     A               ; SHIFT LEFT - shiftnem si tak, aby som mal kazde poschodie dvojicu bitov | X  4 | 3U 3D | 2U 2D | 1  X | 
        anl     A, #01111110b   ; Vynulujem nedefinovane bity
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

POLOHA_LED  MACRO  POLOHA
        clr     LEDU            
        clr     LEDD 
        clr     FLED1             
        clr     FLED2                
        clr     FLED3           
        clr     FLED4           
        setb    FLED&POLOHA
        lcall   WRITEPORTS
ENDM

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
        clr     SLOW                        ;
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
;        _BP_
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


;------------------------------------------------------------------------------- << 1. poschodie >>

FLOOR1:
                POLOHA_LED 1  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        lcall   WAITFORTIMER    ; simulacia TIMERu
F1S:    lcall   READPORTS     ;-; nacitanie dat
        clr     PKO1          ;-; vynulovanie volby poschodia na ktorom stojim
        clr     PO1             ;
        lcall   WRITEPORTS      ;
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco viac ako poschodie na ktorom stojim (Kabina)
        anl     A, #00011100b ;-;
        jnz     F1OK          ;-; ak ano, podme na to
        mov     A, INPORTC      ; zistenie, ci bolo stlacene nieco viac ako poschodie na ktorom stojim (Sachta)
        anl     A, #00111110b ;-;
        jnz     F1OK          ;-; ak ano, podme na to
        jmp     F1S             ; Nemam sa kde hnut, opakujem
F1OK:   setb    UP              ; rychly pohyb hore
        setb    FAST            ; 
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     UP1           ;-; prejdi do stavu UP1
UP1:
                POLOHA_LED 1  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
UP1A:   lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB1, ERR_2SPOM_C; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, UP1A     ;-; mame uz 1. spomalovaciu clonku?
        ZAKMITC MB2             ; Pockame, kym z nej odideme      
        setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     UP1_MB2       ;-; a prejdi do stavu UP1_MB2
UP1_MB2:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB1, ERR_1SPOM_C; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, UP1_MB2  ;-; mame uz aj druhu spomalovaciu clonku?     
        setb    LEDU            ; Rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;   
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
        anl     A, #00000100b ;-;
        jz      UP1_MB1       ;-;       Ak nie, chod do stavu UP1_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;         
        jmp     UP1_MB1       ;-; a prejdi do stavu UP1_MB1 
UP1_MB1:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB2, ERR_ZAST_C ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, UP1_MB1  ;-; Sme na zastavovacej clonke?
        
        ZASTAV  2, U            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0) 
        jnz     U1_MB1C       ;-; Ak ano, zastav
        NAJVYSSIE               ; | ..a sme na najvyssom privolanom poschodi? (potom stojime urcite)
        LCJNE   A, #2, UP2      ; |   ak nie, nezastavujeme 
        VYSSIE_KABINA 2         ; | ..ok, sme na najvyssom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      U1_MB1C         ; |   ak neni zastavujem         
        ljmp    UP2             ; |   inak nezastavim        
U1_MB1C:clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj) 
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR2        ;-; a prejdi do stavu FLOOR2

;------------------------------------------------------------------------------- << 2. poschodie >>

FLOOR2:
                POLOHA_LED 2  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        lcall   WAITFORTIMER    ; simulacia TIMERu
F2S:    lcall   READPORTS     ;-; nacitanie dat
        clr     PKO2          ;-; vynulovanie volby poschodia na ktorom stojim
        clr     PO2U            ;
        clr     PO2D            ;
        lcall   WRITEPORTS      ;
        ;_BP_
        mov     R1, #11111000b;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) kabina
        mov     R2, #11111000b;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) sachta
        jb      UPOld, F2OK     ;   Je to pravda? Naozaj som doteraz isiel hore?
        mov     A, R1           ;       Ak nie, znegujeme masku kabiny
        cpl     A               ;       |
        mov     R1, A           ;       |
        mov     A, R2           ;       A znegujeme aj masku sachty
        cpl     A               ;       |
        mov     R2, A           ;       |
F2OK:   ; Pohyb v jednom smere (nevieme v ktorom)
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Kabina)
        anl     A, #00011010b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R1           ;  | 
        jnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
                                ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Sachta)
        mov     A, INPORTA      ; Mam v kabine nieco stlacene?
        anl     A, #00011010b   ;  | Beriem iba bity predstavujuce tlacidla poschodi (kabina)
        jnz     F2SW            ;  | Ak ano, idem rovno zistovat opacny smer.
        mov     A, INPORTC      ; Mam stlacene nieco v sachte (mojim smerom)?    
        anl     A, #00111001b   ;  | Beriem iba bity predstavujuce tlacidla privolavacov
        anl     A, R2           ;  |   
        jnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
        ; Pohyb v opacnom smere (nevieme v ktorom)
F2SW:   cpl     UPOld           ;  Znegujem stary posun
        cpl     DOWNOld         ;  |
        mov     A, R1           ;  Znegujeme masky
        cpl     A               ;  |
        mov     R1, A           ;  |
        mov     A, R2           ;  |
        cpl     A               ;  |
        mov     R2, A           ;  |               
        mov     A, INPORTA      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Kabina)
        anl     A, #00011010b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R1           ;  | 
        jnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
        mov     A, INPORTC      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Sachta)
        anl     A, #00111001b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R2           ;  | 
        jnz     F2              ; nasli sme poschodie v tomto smere, mozme ist
        jmp     F2S           ;-; nemame sa kde hybat, tak opakujeme zistovanie
F2:     jb      UPOld, F2UP     ;   
        jmp     F2DOWN          ;
F2UP:   setb    UP              ; rychly pohyb hore
        setb    FAST            ; 
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     UP2           ;-; prejdi do stavu UP2    
F2DOWN: setb    DOWN            ; rychly pohyb hore
        setb    FAST            ; 
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     DOWN2         ;-; prejdi do stavu DOWN2    
        
            
UP2:
                POLOHA_LED 2  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
UP2A:   lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB1, ERR_2SPOM_C; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, UP2A     ;-; mame uz 1. spomalovaciu clonku?
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     UP2_MB2       ;-; a prejdi do stavu UP2_MB2
UP2_MB2:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB1, ERR_1SPOM_C; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, UP2_MB2  ;-; mame uz aj druhu spomalovaciu clonku?          
        setb    LEDU            ; Rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
        anl     A, #00001000b ;-;
        jz      UP2_MB1       ;-;       Ak nie, chod do stavu UP2_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     UP2_MB1       ;-; a prejdi do stavu UP2_MB1 
UP2_MB1:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB2, ERR_ZAST_C ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, UP2_MB1  ;-; Sme na zastavovacej clonke?
        
        ZASTAV  3, U            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0)
        jnz     U2_MB1C       ;-; Ak ano, zastav
        NAJVYSSIE               ; | ..a sme na najvyssom privolanom poschodi z kabiny? (potom stojime urcite)
        LCJNE   A, #3, UP3      ; |   ak nie, nezastavujeme  
        VYSSIE_KABINA 3         ; | ..ok, sme na najvyssom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      U2_MB1C         ; |   ak neni zastavujem  
        ljmp    UP3             ; |   inak nezastavim
U2_MB1C:clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj)
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR3        ;-; a prejdi do stavu FLOOR3
DOWN2:
                POLOHA_LED 2  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB1, ERR_2SPOM_C; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN2    ;-; mame uz 1. spomalovaciu clonku?
        ZAKMITC MB2             ; Pockame, kym z nej odideme      
        setb    LEDU            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     DOWN2_MB2     ;-; a prejdi do stavu DOWN2_MB2
DOWN2_MB2:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB1, ERR_1SPOM_C; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN2_MB2;-; mame uz aj druhu spomalovaciu clonku?          
        setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
        anl     A, #00000010b ;-;
        jz      DOWN2_MB1     ;-;       Ak nie, chod do stavu DOWN2_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     DOWN2_MB1     ;-; a prejdi do stavu DOWN2_MB1
DOWN2_MB1:    
        lcall   READPORTS       ; nacitanie dat
        jnb     SKRD, D2_MB1C   ; Sme na hornej porovnavacej clonke? (tu zastavujeme v kazdom pripade)
        jnb     MB1, D2_MB1C  ;-; Sme na zastavovacej clonke? (tu zastavujeme v kazdom pripade)
        jmp     DOWN2_MB1       ; Ak sme nechytili ani jednu clonku, opakujeme
D2_MB1C:clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR1        ;-; a prejdi do stavu FLOOR2      


;------------------------------------------------------------------------------- << 3. poschodie >>

FLOOR3:
                POLOHA_LED 3  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        lcall   WAITFORTIMER    ; simulacia TIMERu
F3S:    lcall   READPORTS     ;-; nacitanie dat
        clr     PKO3          ;-; vynulovanie volby poschodia na ktorom stojim
        clr     PO3U            ;
        clr     PO3D            ;
        lcall   WRITEPORTS      ;
       ;_BP_
        mov     R1, #11110000b;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) kabina
        mov     R2, #11100000b;-; Default predpokladam, ze mam namierene hore (na 3. a 4.) sachta
        jb      UPOld, F3OK     ;   Je to pravda? Naozaj som doteraz isiel hore?
        mov     A, R1           ;       Ak nie, znegujeme masku kabiny
        cpl     A               ;       |
        mov     R1, A           ;       |
        mov     A, R2           ;       A znegujeme aj masku sachty
        cpl     A               ;       |
        mov     R2, A           ;       |        
F3OK:   ; Pohyb v jednom smere (nevieme v ktorom)
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Kabina)
        anl     A, #00010110b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R1           ;  | 
        jnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
                                ; zistenie, ci bolo stlacene nieco viac (menej) ako poschodie na ktorom stojim (Sachta)
        mov     A, INPORTA      ; Mam v kabine nieco stlacene?
        anl     A, #00010110b   ;  | Beriem iba bity predstavujuce tlacidla poschodi (kabina)
        jnz     F3SW            ;  | Ak ano, idem rovno zistovat opacny smer.
        mov     A, INPORTC      ; Mam stlacene nieco v sachte (mojim smerom)?    
        anl     A, #00100111b   ;  | Beriem iba bity predstavujuce tlacidla privolavacov
        anl     A, R2           ;  |   
        jnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
        ; Pohyb v opacnom smere (nevieme v ktorom)
F3SW:   cpl     UPOld           ;  Znegujem stary posun
        cpl     DOWNOld         ;  |
        mov     A, R1           ;  Znegujeme masky
        cpl     A               ;  |
        mov     R1, A           ;  |
        mov     A, R2           ;  |
        cpl     A               ;  |
        mov     R2, A           ;  |               
        mov     A, INPORTA      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Kabina)
        anl     A, #00010110b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R1           ;  | 
        jnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
        mov     A, INPORTC      ; zistenie, cibolo stlacene nieco viac ako poschodie na ktorom stojim (Sachta)
        anl     A, #00100111b   ;  | Beriem iba bity predstavujuce tlacidla poschodi
        anl     A, R2           ;  | 
        jnz     F3              ; nasli sme poschodie v tomto smere, mozme ist
        jmp     F3S           ;-; nemame sa kde hybat, tak opakujeme zistovanie
F3:     jb      UPOld, F3UP     ;   
        jmp     F3DOWN          ;
F3UP:   setb    UP              ; rychly pohyb hore
        setb    FAST            ; 
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     UP3           ;-; prejdi do stavu UP2    
F3DOWN: setb    DOWN            ; rychly pohyb hore
        setb    FAST            ; 
        clr     SLOW            ;
        lcall   WRITEPORTS      ; 
        jmp     DOWN3         ;-; prejdi do stavu UP2    
     
     
UP3:
                POLOHA_LED 3  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
UP3A:   lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB1, ERR_2SPOM_C; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, UP3A     ;-; mame uz 1. spomalovaciu clonku?
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     UP3_MB2       ;-; a prejdi do stavu UP3_MB2
UP3_MB2:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRH, ERR_SKRH  ; >>> CHYBA, Horna porovnavacia clonka <<<
        ljnb    MB1, ERR_1SPOM_C; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, UP3_MB2  ;-; mame uz aj druhu spomalovaciu clonku?          
        setb    LEDU            ; Rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme 
        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
        anl     A, #00010000b ;-;
        jz      UP3_MB1       ;-;       Ak nie, chod do stavu UP3_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     UP3_MB1       ;-; a prejdi do stavu UP3_MB1 
UP3_MB1:
        lcall   READPORTS       ; nacitanie dat
        jnb     SKRH, U3_MB1C  ;  Sme na hornej porovnavacej clonke? (tu zastavujeme v kazdom pripade)
        jnb     MB1, U3_MB1C  ;-; Sme na zastavovacej clonke? (tu zastavujeme v kazdom pripade)
        jmp     UP3_MB1         ; Ak sme nechytili ani jednu clonku, opakujeme. 
U3_MB1C:clr     UP              ; zastav motor
        setb    UPOld           ;       (a zalohuj)
        clr     DOWNOld         ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR4        ;-; a prejdi do stavu FLOOR4   
DOWN3:
                POLOHA_LED 3  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB1, ERR_2SPOM_C; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN3    ;-; mame uz 1. spomalovaciu clonku?
        ZAKMITC MB2             ; Pockame, kym z nej odideme   
        setb    LEDU            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     DOWN3_MB2     ;-; a prejdi do stavu DOWN3_MB2
DOWN3_MB2:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB1, ERR_1SPOM_C; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN3_MB2;-; mame uz aj druhu spomalovaciu clonku?          
        setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
        anl     A, #00000100b ;-;
        jz      DOWN3_MB1     ;-;       Ak nie, chod do stavu DOWN3_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     DOWN3_MB1     ;-; a prejdi do stavu DOWN3_MB1
DOWN3_MB1:    
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB2, ERR_ZAST_C ; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, DOWN3_MB1;-; Sme na zastavovacej clonke?
        ZASTAV  2, D            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0)
        jnz     D3_MB1C         ; Ak ano, zastav
        NAJNIZSIE               ; | ..a sme na najnizsom privolanom poschodi z kabiny? (potom stojime urcite)
        LCJNE   A, #2, DOWN2    ; |   ak nie, nezastavujeme  
        NIZSIE_KABINA 2         ; | ..ok, sme na najnizsom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      D3_MB1C         ; |   ak neni zastavujem                  
        ljmp    DOWN2         ;-; |        
D3_MB1C:clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR2        ;-; a prejdi do stavu FLOOR2      
      
        
;------------------------------------------------------------------------------- << 4. poschodie >>

FLOOR4:
                POLOHA_LED 4  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        lcall   WAITFORTIMER    ; simulacia TIMERu
F4S:    lcall   READPORTS     ;-; nacitanie dat
        clr     PKO4          ;-; vynulovanie volby poschodia na ktorom stojim
        clr     PO4            ;
        lcall   WRITEPORTS      ;
        mov     A, INPORTA      ; zistenie, ci bolo stlacene nieco menej ako poschodie na ktorom stojim (Kabina)
        anl     A, #00001110b ;-;
        jnz     F4OK          ;-; ak ano, ideme na to
        mov     A, INPORTC      ; zistenie, ci bolo stlacene nieco menej ako poschodie na ktorom stojim (Sachta)
        anl     A, #00011111b ;-;
        jnz     F4OK          ;-; ak ano, ideme na to
        jmp     F4S             ; Nemam sa kde hnut, opakujem
F4OK:   setb    DOWN            ; rychly pohyb dole
        setb    FAST            ;
        clr     SLOW            ; 
        lcall   WRITEPORTS      ; 
        jmp     DOWN4         ;-; prejdi do stavu DOWN4 
DOWN4:
                POLOHA_LED 4  ;-; Zhasni LEDKY,uz sme na poschodi (aj na paneli "Poloha kabiny", nechaj len aktualne poschodie)
        ZAKMITC MB1             ; Pockame, kym odideme z poschodia (Clonky MB1)
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB1, ERR_2SPOM_C; >>> CHYBA, Vypadli 2 spomalovacie clonky (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN4    ;-; mame uz 1. spomalovaciu clonku?
        ZAKMITC MB2             ; Pockame, kym z nej odideme      
        setb    LEDU            ; Ak ano, rozsviet LEDku, ze mame prvu MB2 mame za sebou
        lcall   WRITEPORTS      ;
        jmp     DOWN4_MB2     ;-; a prejdi do stavu DOWN4_MB2
DOWN4_MB2:
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB1, ERR_1SPOM_C; >>> CHYBA, Vypadla spomalovacia clonka (narazil som na zastavovaciu) <<<
        jb      MB2, DOWN4_MB2;-; mame uz aj druhu spomalovaciu clonku?          
        setb    LEDD            ; Ak ano, rozsviet LEDku, ze mame druhu MB2
        lcall   WRITEPORTS      ;
        ZAKMITC MB2             ; Pockame, kym z nej odideme
        mov     A, INPORTA      ; Chceme tu spomalit? - je najblizsie poschodie zvolene?
        anl     A, #00001000b ;-;
        jz      DOWN4_MB1     ;-;       Ak nie, chod do stavu DOWN4_MB1
        setb    SLOW            ;       Ak ano, spomalme
        clr     FAST            ; 
        lcall   WRITEPORTS      ;
        jmp     DOWN4_MB1     ;-; a prejdi do stavu DOWN4_MB1
DOWN4_MB1:    
        lcall   READPORTS       ; nacitanie dat
        ljnb    SKRD, ERR_SKRD  ; >>> CHYBA, Dolna porovnavacia clonka <<<
        ljnb    MB2, ERR_ZAST_C; >>> CHYBA, Vypadla zastavovacia clonka (narazil som na spomalovaciu) <<<
        jb      MB1, DOWN4_MB1 ;-; Sme na zastavovacej clonke?
        ZASTAV  3, D            ; Ak ano, chceme tu zastavit? - je toto poschodie zvolene? (Vrati do A 1 ak ano, inak 0) 
        jnz     D4_MB1C       ;-; Ak ano, zastav
        NAJNIZSIE               ; | ..a sme na najnizsom privolanom poschodi z kabiny? (potom stojime urcite)
        LCJNE   A, #3, DOWN3    ; |   ak nie, nezastavujeme  
        NIZSIE_KABINA 3         ; | ..ok, sme na najnizsom privolanom poschodi z kabiny ale neni nad nami uz nic v kabine stlacene? 
        jz      D4_MB1C         ; |   ak neni zastavujem          
        ljmp    DOWN3         ;-; |       
D4_MB1C:clr     DOWN            ; zastav motor
        setb    DOWNOld         ;       (a zalohuj)
        clr     UPOld           ;       (a zalohuj)
        clr     FAST            ; 
        lcall   WRITEPORTS      ; 
        jmp     FLOOR3        ;-; a prejdi do stavu FLOOR3                 
                
  
ERR_1SPOM_C: 
        clr     UP              ; zastav motor
        clr     DOWN            ; 
        lcall   WRITEPORTS      ; 
        _BP_
        nop
        nop 
        
ERR_2SPOM_C: 
        clr     UP              ; zastav motor
        clr     DOWN            ; 
        lcall   WRITEPORTS      ; 
        _BP_
        nop
        nop 
        
ERR_ZAST_C: 
        clr     UP              ; zastav motor
        clr     DOWN            ; 
        lcall   WRITEPORTS      ; 
        _BP_
        nop
        nop 
        
ERR_SKRD: 
        clr     UP              ; zastav motor
        clr     DOWN            ; 
        lcall   WRITEPORTS      ; 
        _BP_
        nop
        nop    
        
ERR_SKRH: 
        clr     UP              ; zastav motor
        clr     DOWN            ; 
        lcall   WRITEPORTS      ; 
        _BP_
        nop
        nop             
                
                
ENDPROG:
        setb    KS
        call    WRITEPORTS                ; zapis novu informaciu
        _BP_
        ret
        
; rutina time delay 1 ms pre oscilator s frekvenciou 11.0592 MHz
; 1 instrukcia 2 takty? => 11.0592/2 = pocet instrukcii potrebnych na 1 sekundu
; 11.0592MHz/2000 = zdrzanie 1 ms
TIME10MS:
        mov     R1,#063h        ; 2
                                ; *** 100x
TIME0:  mov     R2,#0FFh        ; 2 
TIME1:  djnz    R2,TIME1        ; 256*2   
        mov     R2,#0FFh        ; 2       
TIME2:  djnz    R2,TIME2        ; 256*2 
        mov     R2,#024h        ; 2       
TIME3:  djnz    R2,TIME3        ; 36*2
        nop                     ; 1
        djnz    R1,TIME0        ; 2
                                ; ***
        mov     R1,#02Ah        ; 2 
TIME4:  djnz    R1,TIME4        ; 43*2  
        ret                     ; koniec
        
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DELAY
; Pocka na stlacenie tlacidla na 1. poschodi  - signal PO1 (v buducnosti to 
; bude timer)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WAITFORTIMER:
        mov     R3, #10h
DEL1:   lcall   TIME10MS
        djnz    R3, DEL1
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WAITFORTIMER
; Pocka na stlacenie tlacidla na 1. poschodi  - signal PO1 (v buducnosti to 
; bude timer)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
WAITFORTIMER2:
        setb    PO3U                        ; rozsvieti indikator cakania (poschodie 4)
        lcall   WRITEPORTS                  ;
WAIT:   lcall   READPORTS                   ; 
        jnb     PI3D, WAITFORTIMER          ; ak nebolo stlacene tlacidlo PO1, cakaj 
        clr     PO3U                         ; zhasne indikator cakania (poschodie 4)
        lcall   WRITEPORTS
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
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        mov     A, INPORTA
        anl     A, #00011110b
        orl     OUTPORTA, A
        call    WRITEPORTS              ; aktualizuj signalizaciu na ovladacom paneli
        mov     A, INPORTC
        anl     A, #00111111b
        orl     OUTPORTC, A
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
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        nop
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

STR_INIT:   db  0dh, 0ah, 'Riadiaci system je inicializovany.', 0dh, 0ah, 00h
STR_STOP:   db  'Riadiaci system je reinicializovany po stlaceni tlacidla STOP.', 0dh, 0ah, 00h
STR_CALIB:  db  'Kalibracia vytahu je ukoncena.', 0dh, 0ah, 00h

        DSEG
        org     40h
STACK:  DS      10h

end