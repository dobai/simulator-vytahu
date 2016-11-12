$MOD51
$DEBUG

$include (lift.inc)

; hodiny oscilatora v emulatore treba dat na ext a nastavit 11.0592MHz
TIMERCONST      equ     250     ; udaj pre nastavenie casovaca pre potreby seriovej komunikacie
                                ; hodnota 250 znamena prenosovu rychlost 4800 baud pri oscilatore 11.0592MHz
                                ; nastavenie terminalu je 4800 8-N-1, no flow control
                           
STOPDELAY       equ     48      ; pocet cyklov expiracie casovaca T0 po zastaveni - zodpoveda 3 sekundam 
STOPDPKDELAY    equ     32      ; pocet cyklov expiracie casovaca T0 po prvom vyprsani (2 sekundy), ak je zapnuty spinac DPK

;osetrenie vektorov preruseni
        org     0000h           ; adresa odkial startuje program po resete
        ljmp    START           ; skok na zaciatok kodu programu

;        org     0003h           ; prerusenie INT0/STOP#
;        ljmp    INT_STOP        ; obsluha stlacenia tlacitka STOP
			
        org     000Bh           ; v tejto casti pamati je vektor prerusenia
        ljmp    INT_TIMER0      ; pre citac T0

;        org     0023h           ; prerusenie seriovej linky
;        ljmp    INT_SERIAL      ; obsluha prerusenia seriovej linky

        org     0033h           ; od tejto adresy sa zacina kod programu

START:  
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

        clr     TR1                 ; zastavi sa citac T1
        clr     TR0                 ; a tiez citac T0
        mov     SCON,#01010010b     ; nastavenie registra SCON
                                    ; mod 1 (8b UART), SM2=0 (jednoprocesorovy system)
                                    ; REN=1, 0, 0, TI=1 (vysielaci register je prazdny)
                                    ; RI=0 (prijimaci register - nebol prijaty znak)
        mov     TCON,#00000001b     ; INT0 je citlive na zostupnu hranu
        mov     TMOD,#00100001b     ; nastavenie TMOD registra
                                    ; T1: mod 2 - po preteceni sa TL nastavi na hodnotu TH
                                    ; GATE=0 (programove riadenie casovaca)
                                    ; C/T#=0 interne hodiny/12
                                    ; T0: mod 1 - 16 bitove pocitadlo
                                    ; GATE=0 (programove riadenie casovaca)
                                    ; C/T#=0 interne hodiny/12
        mov     PCON,#00000000b     ; najvyssi bit musi byt 0, aby sa nezdvojnasobila prenosova rychlost seriovej linky
        mov     TL1,#TIMERCONST     ; inicializacia casovaca T1
        mov     TH1,#TIMERCONST     ; 
        mov     TL0, #00h           ; inicializacia casovaca T0 - 57600 = 0e100h
        mov     TH0, #0e1h

        setb    TR1                 ; aktivacia T1 => spustenie seriovej linky

;        setb    EX0                 ; prerusenie INT0  - ostava zakazane, signal STOP osetrime priamo v hlavnej slucke
;        setb    ES                  ; prerusenie seriovej linky teraz nevyuzivame
        setb    ET0                 ; povolime prerusenia od casovaca T0
        setb    EA                  ; spust cely prerusovaci mechanizmus
        
        mov     DPTR, #STR_INIT         ; vypis info 
        lcall   DISPSTR                 ; o inicializacii

        ;kalibracia vytahu podla dolnej porovnavacej clonky
        lcall   READPORTS                   ; precitaj, co je na portoch
        jnb     SKRD, CALIBEND              ; ak sme na dolnej porovnavacej clonke, tak koniec
        setb    DOWN                        ; inak pod dole
        setb    FAST                        ; a rychlo
        lcall   WRITEPORTS                  ; zapis informaciu 
CALIBLOOP:
        lcall   TIME1MS
        lcall   READPORTS                   ; pozri sa, ci uz sme dole
        jb      SKRD, CALIBLOOP             ; ak este nie, tak opakuj

CALIBEND:
        mov     CTRLREG, #0                 ; vynuluj riadiaci register
        mov     POSITION, #0                ; pozicia 0 - prve poschodie
        mov     INPORTBold, #00011100b      ; vsetky clonky pasivne okrem MB1
        mov     OUTPORTBold, #10h           ; FLED1 je zapnute
        mov     C, DOORCLSD
        mov     DOORCLSDold, C              ; uchovaj prvotny priznak zatvorenia dveri
        mov     OUTPORTA, #0                ; vynuluj vsetky
        mov     OUTPORTB, #0                ; vystupne
        mov     OUTPORTC, #0                ; registre
        
        setb    FAST                        ; zo zaciatku pojdeme rychlo
        setb    CANGO                       ; hybat sa mozeme

        jb      DOORCLSD, CALIB_DPK         ; ak dvere su zavrete, tak preskoc
        clr     CANGO                       ; v opacnom pripade sa nemozeme hybat
        clr     FAST                        ; a zastav
        
CALIB_DPK:
        jnb     DPK, CALIBDONE              ; ak je hned na zaciatku kriticky zatazena kabina, tak budeme stat
        clr     CANGO                       ; nemozeme sa hybat; najblizsie sa bude dat az po uplynuti casovaca alebo po otvoreni a zatvoreni dveri
        mov     STOPTIMER, #STOPDELAY       ; nastav casovac, po uplynuti ktoreho sa zas budeme moct hybat
        setb    TR0                         ; a spust ho
CALIBDONE:        
        lcall   WRITEPORTS                  ; zapis info na porty (ak sa kalibroval vytah, tak zastavi)
        mov     DPTR, #STR_CALIB
        lcall   DISPSTR                     ; a zobraz info o uspesnom ukonceni kalibracie
  
MAIN:
        call    TIME1MS                 ; daj si pauzu
        call    READPORTS               ; precitaj nove udaje 

        ; a tu zacina zabava - treba spracovat, co sa nacitalo
        mov     A, INPORTC              ; nastav na vystupoch privolavacov to iste ako na vstupoch
        anl     A, #00111111b
        orl     OUTPORTC, A
        mov     A, INPORTA
        anl     A, #00011110b
        orl     OUTPORTA, A
        call    WRITEPORTS              ; aktualizuj signalizaciu na ovladacom paneli
        
        jb      STOPNOT, MAIN_STOPBNEND ; ak tlacitko STOP nie je stlacene, tak pokracuj
        lcall   STOP_RESET              ; v opacnom pripade stojime
        ljmp    MAIN_DOORCHK
        
MAIN_STOPBNEND:
        ; zisti najvyssie a najnizsie poschodie, na ktore je privolany vytah
        mov     HIGHEST, #0
        mov     C, PKI2
        orl     C, PI2U
        orl     C, PI2D
        jnc     $+5
        mov     HIGHEST, #2
        mov     C, PKI3
        orl     C, PI3U
        orl     cccf, PI3D
        jnc     $+5
        mov     HIGHEST, #4
        mov     C, PKI4
        orl     C, PI4
        jnc     $+5
        mov     HIGHEST, #5
        mov     LOWEST, #5
        mov     C, PKI3
        orl     C, PI3U
        orl     C, PI3D
        jnc     $+5
        mov     LOWEST, #4
        mov     C, PKI2
        orl     C, PI2U
        orl     C, PI2D
        jnc     $+5
        mov     LOWEST, #2
        mov     C, PKI1
        orl     C, PI1
        jnc     $+5
        mov     LOWEST, #0

        ; teraz zistime, ci bol vytah privolavany na ine poschodie, ako prave stojime
        clr     C
        mov     A, HIGHEST
        subb    A, LOWEST
        cjne    A, #0, MAIN_POSITION    ; ak sa najvyssie a najnizsie poschodia nerovnaju, tak tu sme skoncili
        mov     A, HIGHEST
        subb    A, POSITION
        cjne    A, #0, MAIN_POSITION    ; ak momentalne jedine privolavane poschodie nie je to, na ktorom sme, tak pokracuj
        mov     C, UP
        orl     C, DOWN
        jc      MAIN_POSITION           ; ak sa este hybeme, tak pokracuj
        anl     OUTPORTA, #11100001b    ; je privolavane poschodie, na ktorom stojime - takze volbu zrusime a skoncime
        mov     INPORTA, #0
        anl     OUTPORTC, #11000000b
        mov     INPORTC, #0
        call    WRITEPORTS              ; aktualizuj signalizaciu na ovladacom paneli
        ljmp    MAIN_DOORCHK            ; a chod az na kontrolu dveri

MAIN_POSITION:
        ; teraz prebehne kontrola pozicie vytahu - ta sa odvija od stavu spomalovacej clonky
        jb      MB2,$+8                 ; ak je spomalovacia clonka vypnuta
        clr     MB2old
        ljmp    MAIN_POSEND
        jnb     MB2old, $+6             ; a bola zapnuta pri minulom citani
        ljmp    MAIN_POSEND

        jnb     DPK, $+7                ; najprv skontrolujeme podlahovy spinac DPK - kriticke zatazenie
        setb    SLOW                    ; ak je kriticke zatazenie, tak budeme stat, teda zapni pomaly pohyb
        clr     FAST                    ; a vypni rychly                                                                        

        jb      DOWN, MAIN_POS0         ; zmenime polohu
        mov     A, POSITION
        add     A, #2                   ; inkrementuj poziciu, ak ideme hore
        mov     POSITION, A
        
MAIN_POS0:
        dec     POSITION                ; dekrementuj poziciu, ak ideme dole
        setb    MB2old                  ; nastav flag
        mov     A, #(bmFLED1 or bmFLED2 or bmFLED3 or bmFLED4)
        cpl     A                       
        anl     OUTPORTB, A             ; zhasneme vsetky indikatory polohy
        mov     A, POSITION
        
        cjne    A, #0, MAIN_POS1
        setb    FLED1                   ; pozicia 0 - prve poschodie
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        ljmp    MAIN_POSEND
        
MAIN_POS1:
        cjne    A, #1, MAIN_POS2
        setb    FLED1
        setb    FLED2                   ; pozicia 1 - medzi prvym a druhym poschodim
        ljmp    MAIN_POSEND
        
MAIN_POS2:
        cjne    A, #2, MAIN_POS3
        setb    FLED2                   ; pozicia 2 - druhe poschodie
        jnb     UPold, MAIN_POS2D       ; ak nejdeme hore, tak preskoc
        mov     A, HIGHEST
        cjne    A, #2, MAIN_POS2UDPZK   ; ak je toto poschodie najvyssie
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        sjmp    MAIN_POS2UDPZKEND
MAIN_POS2UDPZK:
        jb      PKI2, MAIN_POS2UDPZKEND ; ak je privolany zvnutra kabiny, tak moze zastavit - pokracuj v testovani
        mov     C, PI2U                 ; v opacnom pripade sa pozri, ci nebol privolany zvonku
        anl     C, DPZK                 ; pocas plneho zatazenia
        jnc     MAIN_POS2UDPZKEND       ; nie? tak pokracuj v standardnom testovani
        ljmp    MAIN_POSEND             ; inak sme tu skoncili - rychlosti nechaj povodne
MAIN_POS2UDPZKEND:        
        mov     C, PKI2                 ; zistime, ci sa neblizime k cielovej stanici zdola
        orl     C, PI2U
        anl     C, UPold
        jnc     $+6                     ; ak sa blizime
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        ljmp    MAIN_POSEND
MAIN_POS2D:
        mov     A, LOWEST
        cjne    A, #2, MAIN_POS2DDPZK   ; ak je toto poschodie najnizsie
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        sjmp    MAIN_POS2DDPZKEND
MAIN_POS2DDPZK:
        jb      PKI2, MAIN_POS2DDPZKEND ; ak je privolany zvnutra kabiny, tak moze zastavit - pokracuj v testovani
        mov     C, PI2D                 ; v opacnom pripade sa pozri, ci nebol privolany zvonku
        anl     C, DPZK                 ; pocas plneho zatazenia
        jnc     MAIN_POS2DDPZKEND       ; nie? tak pokracuj v standardnom testovani
        ljmp    MAIN_POSEND             ; inak sme tu skoncili - rychlosti nechaj povodne
MAIN_POS2DDPZKEND:        
        mov     C, PKI2                 ; zistime, ci sa neblizime k cielovej stanici zhora
        orl     C, PI2D
        anl     C, DOWNold
        jnc     $+6                     ; ak sa blizime
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        ljmp    MAIN_POSEND
        
MAIN_POS3:
        cjne    A, #3, MAIN_POS4
        setb    FLED2
        setb    FLED3                   ; pozicia 3 - medzi druhym a tretim poschodim
        ljmp    MAIN_POSEND
        
MAIN_POS4:
        cjne    A, #4, MAIN_POS5
        setb    FLED3                   ; pozicia 4 - tretie poschodie
        jnb     UPold, MAIN_POS4D       ; ak nejdeme hore, tak preskoc
        mov     A, HIGHEST
        cjne    A, #4, MAIN_POS4UDPZK   ; ak je toto poschodie najvyssie
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        sjmp    MAIN_POS4UDPZKEND
MAIN_POS4UDPZK:
        jb      PKI3, MAIN_POS4UDPZKEND ; ak je privolany zvnutra kabiny, tak moze zastavit - pokracuj v testovani
        mov     C, PI3U                 ; v opacnom pripade sa pozri, ci nebol privolany zvonku
        anl     C, DPZK                 ; pocas plneho zatazenia
        jnc     MAIN_POS4UDPZKEND       ; nie? tak pokracuj v standardnom testovani
        ljmp    MAIN_POSEND             ; inak sme tu skoncili - rychlosti nechaj povodne
MAIN_POS4UDPZKEND:        
        mov     C, PKI3                 ; zistime, ci sa neblizime k cielovej stanici zdola
        orl     C, PI3U
        anl     C, UPold
        jnc     $+6                     ; ak sa blizime
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        ljmp    MAIN_POSEND
MAIN_POS4D:
        mov     A, LOWEST
        cjne    A, #4, MAIN_POS4DDPZK   ; ak je toto poschodie najnizsie
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        sjmp    MAIN_POS4DDPZKEND
MAIN_POS4DDPZK:
        jb      PKI3, MAIN_POS4DDPZKEND ; ak je privolany zvnutra kabiny, tak moze zastavit - pokracuj v testovani
        mov     C, PI3D                 ; v opacnom pripade sa pozri, ci nebol privolany zvonku
        anl     C, DPZK                 ; pocas plneho zatazenia
        jnc     MAIN_POS4DDPZKEND       ; nie? tak pokracuj v standardnom testovani
        ljmp    MAIN_POSEND             ; inak sme tu skoncili - rychlosti nechaj povodne
MAIN_POS4DDPZKEND:        
        mov     C, PKI3                 ; zistime, ci sa neblizime k cielovej stanici zhora
        orl     C, PI3D
        anl     C, DOWNold
        jnc     $+6                     ; ak sa blizime
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
        ljmp    MAIN_POSEND
        
MAIN_POS5:
        cjne    A, #5, MAIN_POS6
        setb    FLED3
        setb    FLED4                   ; pozicia 5 - medzi tretim a stvrtym poschodim
        ljmp    MAIN_POSEND
        
MAIN_POS6:
        setb    FLED4                   ; pozicia 6 - stvrte poschodie
        setb    SLOW                    ; tak zapni pomaly pohyb
        clr     FAST
MAIN_POSEND:

MAIN_MOVE:
        ; tu vybavime pohyb vytahu
        jnb     CANGO, MAIN_STOP
        mov     C, UPold                ; najprv skus zapisat stare hodnoty smeru pohybu
        mov     UP, C
        mov     C, DOWNold
        mov     DOWN, C
        orl     C, UPold
        jc      MAIN_STOP               ; ano, bol nejaky stary udaj o tom, kde sme sa hybali, takze tu sme skoncili
        clr     C
        mov     A, HIGHEST
        cjne    A, #0, $+5              ; ak najvyssia poloha je prve poschodie
        sjmp    MAIN_MOVE1              ; tak preskoc
        setb    UP
        subb    A, POSITION
        jnc     $+6
        setb    DOWN
        clr     UP
MAIN_MOVE1:
        clr     C
        mov     A, LOWEST
        cjne    A, #5, $+5              ; ak najnizsia poloha je stvrte poschodie
        sjmp    MAIN_MOVE2              ; tak preskoc
        setb    UP
        subb    A, POSITION
        jnc     $+6
        setb    DOWN
        clr     UP
MAIN_MOVE2:
        mov     C, UP
        mov     UPold, C
        mov     C, DOWN
        mov     DOWNold, C
                    
MAIN_STOP:
        ; teraz zistime, ci chceme na danom poschodi zastavit - toto sa odvija od stavu zastavovacej clonky
        mov     C, UP                       ; toto ma zmysel len ak sa vytah hybe
        orl     C, DOWN
        jc      $+5                 
        ljmp    MAIN_DOORCHK                ; ak sa nehybe, tak preskoc
        jnb     MB1, $+8                    ; ak je zastavovacia clonka zapnuta
        setb    MB1old
        ljmp    MAIN_DOORCHK
        jb      MB1old, $+6                 ; a nebola zapnuta pri minulom citani
        ljmp    MAIN_DOORCHK
        clr     MB1old                      ; tak zistime, ci v danom poschodi chceme zastavit
        jnb     DPK, $+6                    ; najprv skontrolujeme podlahovy spinac DPK - kriticke zatazenie
        ljmp    MAIN_POSSTOP                ; ak je zapnuty, tak v tomto poschodi stojime
        mov     A, POSITION
        cjne    A, #0, MAIN_POSS2           ; sme na prvom?
        mov     C, PI1
        orl     C, PKI1
        jc      $+5
        ljmp    MAIN_DOORCHK                ; tu nechceme stat?
        clr     DOWNold                     ; a uz sa dalej nebudeme hybat smerom dole
        ljmp    MAIN_POSSTOP
MAIN_POSS2:
        cjne    A, #2, MAIN_POSS3           ; sme na druhom?
        jb      DOWN, MAIN_POSS2D           ; ak vytah ide dole, tak skoc
        mov     A, HIGHEST
        cjne    A, #2, $+8                  ; ak je toto poschodie najvyssie
        clr     UPold                       ; uz dalej nepojdeme hore
        ljmp    MAIN_POSSTOP
        jnb     DPZK, $+9                   ; ak nie je plne zatazenie kabiny, tak moze zastavit
        jnb     PI2U, $+6                   ; ak nebol privolany zvonku, tak tiez moze zastavit
        ljmp    MAIN_DOORCHK                ; vytah je plne zatazeny a privolany zvonku, takze nestojime!
        mov     C, PKI2                     ; zistime, ci sa neblizime k cielovej stanici zdola
        orl     C, PI2U
        jc      $+5
        ljmp    MAIN_DOORCHK                ; chceme tu stat?
        ljmp    MAIN_POSSTOP
MAIN_POSS2D:
        mov     A, LOWEST                   ; je to momentalne najnizsie poschodie?
        cjne    A, #2, $+8
        clr     DOWNold                     ; uz dalej nepojdeme dole
        ljmp    MAIN_POSSTOP
        jnb     DPZK, $+9                   ; ak nie je plne zatazenie kabiny, tak moze zastavit
        jnb     PI2D, $+6                   ; ak nebol privolany zvonku, tak tiez moze zastavit
        ljmp    MAIN_DOORCHK                ; vytah je plne zatazeny a privolany zvonku, takze nestojime!
        mov     C, PI2D                     ; vytah ide dole, tak zober udaje z tlacidla pre smer dole
        orl     C, PKI2
        jc      $+5
        ljmp    MAIN_DOORCHK                ; chceme tu stat?
        ljmp    MAIN_POSSTOP
MAIN_POSS3:
        cjne    A, #4, MAIN_POSS4           ; sme na tretom?
        jb      DOWN, MAIN_POSS3D           ; vytah ide dole?
        mov     A, HIGHEST                  ; je to momentalne najvyssie poschodie?
        cjne    A, #4, $+8
        clr     UPold                       ; uz dalej nepojdeme hore
        ljmp    MAIN_POSSTOP
        jnb     DPZK, $+9                   ; ak nie je plne zatazenie kabiny, tak moze zastavit
        jnb     PI3U, $+6                   ; ak nebol privolany zvonku, tak tiez moze zastavit
        ljmp    MAIN_DOORCHK                ; vytah je plne zatazeny a privolany zvonku, takze nestojime!
        mov     C, PI3U                     ; ano, tak zober udaje z tlacidla pre smer hore
        orl     C, PKI3
        jc      $+5
        ljmp    MAIN_DOORCHK                ; chceme tu stat?
        ljmp    MAIN_POSSTOP
MAIN_POSS3D:
        mov     A, LOWEST                   ; je to momentalne najnizsie poschodie?
        cjne    A, #4, $+8
        clr     DOWNold                     ; uz dalej nepojdeme dole
        ljmp    MAIN_POSSTOP
        jnb     DPZK, $+9                   ; ak nie je plne zatazenie kabiny, tak moze zastavit
        jnb     PI3D, $+6                   ; ak nebol privolany zvonku, tak tiez moze zastavit
        ljmp    MAIN_DOORCHK                ; vytah je plne zatazeny a privolany zvonku, takze nestojime!
        mov     C, PI3D                     ; vytah ide dole, tak zober udaje z tlacidla pre smer dole
        orl     C, PKI3
        jc      $+5
        ljmp    MAIN_DOORCHK                ; chceme tu stat?
        sjmp    MAIN_POSSTOP
MAIN_POSS4:
        cjne    A, #6, MAIN_DOORCHK         ; sme na stvrtom?
        mov     C, PI4
        orl     C, PKI4
        jc      $+5
        ljmp    MAIN_DOORCHK                ; chceme tu stat?
        clr     UPold                       ; a uz sa dalej nebudeme hybat smerom hore
        
MAIN_POSSTOP:                               ; stojime 
        anl     OUTPORTB, #not(bmUP or bmDOWN or bmSLOW)    ; zastav motor - UP=DOWN=SLOW=0
        setb    FAST                        ; najblizsie sa zas budeme hybat rychlo
        clr     LEDU                        ; zhasni indikacne diody
        clr     LEDD
        
        clr     CANGO                       ; nemozeme sa hybat; najblizsie sa bude dat az po uplynuti casovaca alebo po otvoreni a zatvoreni dveri
        mov     STOPTIMER, #STOPDELAY       ; nastav casovac, po uplynuti ktoreho sa zas budeme moct hybat
        setb    TR0                         ; a spust ho

        mov     A, POSITION                 ; nakoniec treba zrusit volbu v danom poschodi
        cjne    A, #0, MAIN_POSSTOP2        ; pozicia 0 - prve poschodie
        clr     PKO1
        clr     PO1
        sjmp    MAIN_POSSTOPEND
MAIN_POSSTOP2:
        cjne    A, #2, MAIN_POSSTOP4        ; pozicia 2 - druhe poschodie
        clr     PKO2
        clr     PO2D
        clr     PO2U
        sjmp    MAIN_POSSTOPEND
MAIN_POSSTOP4:
        cjne    A, #4, MAIN_POSSTOP6        ; pozicia 4 - tretie poschodie
        clr     PKO3
        clr     PO3D
        clr     PO3U
        sjmp    MAIN_POSSTOPEND
MAIN_POSSTOP6:
        clr     PKO4                        ; pozicia 6 - stvrte poschodie
        clr     PO4
        clr     UPold                       ; hore uz nepojdeme
MAIN_POSSTOPEND:
        lcall   WRITEPORTS                  ; toto je nutne na updatnutie informacie v privolavaci, inak ho automaticky znovu "stlaci"
        
MAIN_DOORCHK:
        ; kontrola stavu dveri
        jb      DOORCLSD, MAIN_DOORCLSD     ; ak dvere su zavrete, tak preskoc
        jnb     DOORCLSDold, MAIN_DOOREND   ; ak aj v minulom kroku boli otvorene, tak preskoc
        clr     DOORCLSDold                 ; inak nastav flag, ze sa dvere otvorili
        clr     CANGO                       ; v opacnom pripade nemozeme ist dalej
        mov     C, FAST                     ; uloz udaje o poslednom pohybe
        mov     FASTold, C
        mov     C, SLOW
        mov     SLOWold, C
        clr     FAST                        ; a zastav
        clr     SLOW
        sjmp    MAIN_DOOREND
MAIN_DOORCLSD:
        jb      DOORCLSDold, MAIN_DOOREND   ; ak boli zavrete aj v minulom kroku tak preskoc
        setb    DOORCLSDold                 ; inak nastav flag
        jb      DPK, $+5                    ; ak je vytah kriticky zatazeny, tak nepovolime opatovne rozbehnutie
        setb    CANGO                       ; nie je kriticky zatazeny => mozeme sa znovu hybat
        mov     C, FASTold                  ; a obnov udaj pre rychlost pohybu
        mov     FAST, C
        mov     C, SLOWold
        mov     SLOW, C
MAIN_DOOREND:

        ; ak sa vytah hybe, alebo je zatazeny, tak rozsviet svetlo
        clr     KS
        mov     C, DP
        orl     C, DPZK
        orl     C, DPK
        orl     C, UP
        orl     C, DOWN
        jnc     MAIN_LIGHTOFF           ; ak sa vytah nehybe a je prazdny tak preskoc
        mov     A, OUTPORTB
        anl     A, #0f0h                ; zober len data o polohe
        cjne    A, #0, $+7              ; ak nemame udaj o polohe,
        mov     A, OUTPORTBold          ;   tak zober 
        orl     OUTPORTB, A             ;   zalozny udaj
        mov     OUTPORTBold, OUTPORTB   ; kedze sa hybeme, tak odzalohuj poschodie, 
        anl     OUTPORTBold, #0f0h      ;   na ktorom momentalne sme
        setb    KS                      ; a rozsviet svetlo
        sjmp    MAIN_DIRLEDS
        
MAIN_LIGHTOFF:                          ; v tomto pripade nebudeme svietit ani ukazovat polohu vytahu
        anl     OUTPORTB, #0fh          ; a vynuluj informaciu vo vystupnom registri
        
MAIN_DIRLEDS:
        ; a este zistime, ci sa vytah hybe a podla toho nastavime indikator smeru pohybu
        mov     C, UP
        orl     C, DOWN
        jnc     LEDUD_END
        mov     C, FAST
        orl     C, SLOW
        jnc     LEDUD_END
        jb      UP, $+7
        setb    LEDD
        sjmp    LEDUD_END
        setb    LEDU
LEDUD_END:
        
        ljmp    MAIN            ; nekonecna slucka


; rutina time delay 1 ms pre oscilator s frekvenciou 11.0592 MHz
; 1 instrukcia 2 takty? => 11.0592/2 = pocet instrukcii potrebnych na 1 sekundu
; 11.0592MHz/2000 = zdrzanie 1 ms
TIME1MS:
        mov     R3,#0FFh        ; prva cast slucky pre time delay
TIME1:  djnz    R3,TIME1        ; prvy cyklus
        nop                     ; jeden prazdny takt
        mov     R3,#0CBh        ; druha cast slucky pre time delay
TIME2:  djnz    R3,TIME2        ; druhy cyklus
        ret                     ; koniec


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
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
; BYTEOUT
; rutina pre vyslanie byte po seriovej linke
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BYTEOUT:
        mov     SBUF, A         ; a zacne sa vysielat novy byte
        jnb     TI, $           ; pockame, kym sa neodvysiela
        clr     TI              ; uz je odoslany, tak mozeme priznak zmazat
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; BYTEIN
; rutina pre prijem byte zo seriovej linky
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BYTEIN: 
        jnb     RI, $           ; caka sa pokym nepride cely udaj
        mov     A, SBUF         ; udaj sa presunie do A
        clr     RI              ; a zhodi sa flag RI
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DISPSTR
; posle na seriovu linku retazec na adrese DPTR
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DISPSTR:
        clr     A
        movc    A, @A+DPTR
        jz      DSPS_END
        mov     SBUF, A
        jnb     TI, $
        clr     TI
        inc     DPTR
        sjmp    DISPSTR
DSPS_END:
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; STOP_RESET
; tato rutina reinicializuje system po stlaceni tlacitka STOP
; vola sa z obsluhy prerusenia INT0 a z obsluhy serioveho portu
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
STOP_RESET:
        mov     INPORTA, #0             ; vynuluj vstupne registre
        mov     INPORTB, #0
        mov     INPORTC, #0

        mov     OUTPORTA, #0            ; vynuluj
        mov     OUTPORTB, #0            ; data 
        mov     OUTPORTC, #0            ; vo vystupnych registroch
        clr     UPold
        clr     DOWNold
        setb    FAST
        clr     SLOW

        clr     TR0                     ; zastav casovac
        setb    CANGO
        jnb     DPK, STOP_CANGO         ; ak je hned na zaciatku kriticky zatazena kabina, tak budeme stat
        clr     CANGO                   ; nemozeme sa hybat; najblizsie sa bude dat az po uplynuti casovaca alebo po otvoreni a zatvoreni dveri
        mov     STOPTIMER, #STOPDELAY   ; nastav casovac, po uplynuti ktoreho sa zas budeme moct hybat
        setb    TR0                     ; a spust ho
STOP_CANGO:

        lcall   WRITEPORTS              ; zapis novu informaciu
        lcall   READPORTS               ; precitaj hned nove data, aby sme mali aktualne info
        
        mov     DPTR, #STR_STOP
        lcall   DISPSTR                 ; a daj echo o tom, ze stlacenie tlacidla STOP bolo osetrene
        ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; OBSLUHY PRERUSENI                                                           ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Obsluha prerusenia casovaca T0
; Zabezpecuje obnovenie signalu CANGO po vyprsani casoveho limitu
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
INT_TIMER0:
        clr     EA
;        clr     ET0
;        clr     EX0
;        clr     ES
        push    ACC
        push    PSW
        push    IE
        
        jnb     CANGO, INT_TIMER0_MAIN      ; ak stale nejaka ina udalost nepovolila pohyb vytahu, tak pokracuj v cakani
        clr     TR0                         ; ak uz je pohyb povoleny, tak zastav citac
        sjmp    INT_TIMER0_END              ; a koniec
        
INT_TIMER0_MAIN:
        dec     STOPTIMER                   ; dekrementuj hodnotu citaca
        mov     A, STOPTIMER
        cjne    A, #0, INT_TIMER0_END       ; pozri, ci nie je nula
        jnb     DPK, INT_TIMER0_STOP        ; ak nie je zapnute kriticke zatazenie, tak mozeme obnovit pohyb
        mov     STOPTIMER, #STOPDPKDELAY    ; ak je DPK zapnuty, tak obnov pocitadlo casovaca
        sjmp    INT_TIMER0_END
                
INT_TIMER0_STOP:
        clr     TR0                         ; zastav casovac
        setb    FAST                        ; po vyprsani casovaca urcite pojdeme rychlo
        clr     SLOW
        setb    CANGO                       ; a povol znovu pohyb

INT_TIMER0_END:        
        pop     IE
        pop     PSW
        pop     ACC
;        setb    ET0
;        setb    EX0
;        setb    ES
        setb    EA
		reti

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

STR_INIT:   db  0dh, 0ah, 'Riadiaci system je inicializovany.', 0dh, 0ah, 00h
STR_STOP:   db  'Riadiaci system je reinicializovany po stlaceni tlacidla STOP.', 0dh, 0ah, 00h
STR_CALIB:  db  'Kalibracia vytahu je ukoncena.', 0dh, 0ah, 00h

        DSEG
        org     40h
STACK:  DS      10h

end
