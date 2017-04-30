;*******************************************************************************
;   Sofrverovy breakpoint
;-------------------------------------------------------------------------------
;     Pouzitie pri debugovani pomocou emulatora T-EMU52
;     Pre spravne fungovanie musi byt parameter <Single step interrupt> 
;     nastaveny na hodnotu <INT1>
;
;     Emulator -> Configuration -> Single step interrupt
;
_BP_    MACRO 
        clr     P3.3
        setb    EX1
        nop
ENDM


;*******************************************************************************
;   CFCSS - kontrolne instrukcie
;-------------------------------------------------------------------------------
;     Obsahuje instrukcie, ktore sa pridaju na zaciatok bloku.
;     <s> predstavuje priznak prideleny aktualnemu bloku
;     <d> predstavuje rozdiel (XOR) medzi predchadzajucim a aktualnym blokom
;         (na zaklade tejto hodnoty sa vypocita novya hodnota <G>)
;     <D1> a <D2> predstavuju priznaky pre upravu <G>, ak sa 
;         nachadza v mnozine nasledovnikov aktualneho bloku aj fan-in blok    
;
CFCSS   MACRO   s, d, D1val, D2val, Dx 
        xrl		G,  #d             ;; Vypocitanie novej hodnoty priznaku <G>
        IF (Dx <> -1)
            mov   A,  Dx         ;; Uprava priznaku <G> na zaklade <Dx>
            xrl   G,  A          ;;     (iba pri fan-in vrcholoch)
        ENDIF    
        mov   A,  G              ;; Porovnanie aktualnej hodnoty <G> s priznakkom <s>
        LCJNE A,  #s, CFCERR     ;;     (ak sa priznaky nerovnaju, skoci sa na osetrenie chyby )
        IF (D1val <> -1)
            mov		D1, #D1val     ;; Nastavenie priznaku <D1>
        ELSE
            mov		D1, #32        ;; Nastavenie priznaku <D1> na hodnotu mimo rozsahu 
        ENDIF                    ;; (aby sa predislo maskovaniu pri nepovolenom skoku)
        IF (D2val <> -1)
            mov		D2, #D2val     ;; Nastavenie priznaku <D2>
        ELSE
            mov		D2, #32        ;; Nastavenie priznaku <D2> na hodnotu mimo rozsahu 
        ENDIF                    ;; (aby sa predislo maskovaniu pri nepovolenom skoku)
        SERCHAR   #s             ;; Vypis aktualneho <s> na seriovu linku
ENDM

;*******************************************************************************
;   Vypis znaku na seriovu linku
;-------------------------------------------------------------------------------
;     Vypise jeden znak (prijaty ako parameter CHAR) na seriovu linku.   
;
SERCHAR MACRO CHAR
		mov		  A, CHAR
    jnb     TI, $ 
    clr     TI
		mov     SBUF, A
    
ENDM


;*******************************************************************************
;   Instrukcie pre casovace a pocitadla
;-------------------------------------------------------------------------------
;     Spustenie casovaca s hodnotou <VAL>. Po (<VAL>*50)ms sa nastavi 
;     priznak <T2_F>    
;
TIMER2  MACRO  VAL
	   mov		 T2_C, #VAL				 ;; 3 sekundy
		 clr 	   T2_F      				 ;; vynulovat priznak pretecenia
		 setb	   TR2						   ;; spustit casovac
ENDM




;*******************************************************************************
;   Ekvivalenty podmienenych skokovych instrukcii s dlhym skokom
;-------------------------------------------------------------------------------
;     Nazov makra je tvoreny nazvom skokovej instrukcie a prefixom "L"   
;

; Long jump if zero
LJZ     MACRO   NAVESTIE
        jnz     $+5
        ljmp    NAVESTIE
        nop
ENDM

; Long jump if not zero
LJNZ    MACRO   NAVESTIE
        jz      $+5
        ljmp    NAVESTIE
        nop
ENDM

; Long jump if bit set
LJB     MACRO   TESTBIT, NAVESTIE
        jnb     TESTBIT, $+6
        ljmp    NAVESTIE
        nop
ENDM

; Long jump if bit not set
LJNB    MACRO   TESTBIT, NAVESTIE
        jb      TESTBIT, $+6
        ljmp    NAVESTIE
        nop
ENDM

; Compare & long jump if not equal
LCJNE   MACRO   OP1, OP2, NAVESTIE
        cjne    OP1, OP2, $+6
        jmp     $+6
        ljmp    NAVESTIE
        nop
ENDM

;*******************************************************************************
;   Modifikacie instrukcii x51
;-------------------------------------------------------------------------------
;     Tieto makra obsahuju niektore modifikovane zakladne dostupne instrukcie x51     
;

;Logical and (bit operands)
ANLB   MACRO   BIT1, BIT2
        mov   C, BIT1
        anl   C, /BIT2
        mov   BIT1, C
ENDM

; Compare & long jump if equal
LCJE     MACRO   OP1, OP2, NAVESTIE
        cjne    OP1, OP2, $+7
        jmp    NAVESTIE
        nop
ENDM


;*******************************************************************************
;   Privolavace, signalizácia polohy a smeru kabiny
;-------------------------------------------------------------------------------
;
;   Signalizacia polohy kabiny
;
;     Signalizuje polohu kabiny na signalizacnom paneli.  
;     Poloha kabiny zavisi o parametra "POLOHA" 
;     Vykonane zmeny sa zapisu na porty     
;
POLOHA_LED  MACRO  POLOHA
        anl     OUTPORTB, #((not bmFLED1) and(not bmFLED2) and(not bmFLED3) and(not bmFLED4))          
        setb    FLED&POLOHA
        lcall   WRITEPORTS
ENDM

;   Zrusenie volby vybraneho poschodia
;
;     Zrusi volbu vybraneho poschodia <POSCH>. Volba   
;     sa zrusi v kabine ako aj v oboch smeroch na poschodi.
;
ZRUS_POSCH  MACRO POSCH
        clr     PKO&POSCH       ;; vynulovanie volby poschodia na ktorom stojim
        clr     PO&POSCH&U      ;;
        clr     PO&POSCH&D      ;;
        lcall   WRITEPORTS
ENDM

;   Rozsvietenie kabinoveho svetla a smerovej signalizacie 
;
;     Rozsvieti kabinove svetlo a obe sibky smerovej
;     signalizacie ak sa v kabine nachadza obsluhyschopna
;     osoba. V opacnom pripade svetlo a signalizaciu
;     zhasne.
;
KABINOVE_SVETLO MACRO
        mov      C, DP          ;; Ak je nieko v kabine,
        orl      C, DPZK        ;;
        orl      C, DPK         ;;
        mov      KS, C          ;;   - v kabine zapalime svetlo. Ak nie, bude zhasnute.
        mov      LEDU, C        ;;   - Rozsvietime signalizaciu do oboch smerov. Ak nie, zhasneme.
        mov      LEDD, C        ;;
        lcall   WRITEPORTS      ;;
ENDM

;   Rozsvieti obe smerove LED diody (signalizacia, ze kabina stoji)
;
ROZSVIET_SMER_LED MACRO
        setb    LEDU            ;
        setb    LEDD            ;
        lcall   WRITEPORTS      ;
ENDM

;   Zistenie, ci obsluhyschopna osoba zvolila poschodie
;      
;     Zistenie, či obsluhyschopna osoba v kabine vytahu 
;     stlacila niektoru z volieb poschodi v kabine.
;     V pripade, ze v kabine sa nachadza obsluhyschopna 
;     osoba a volba zatial nebola uskutocnena, skoci sa 
;     na <NAVESTIE>      
;        
JE_VYBRATE_POSCHODIE MACRO NAVESTIE
        mov      C, DP         ;; Ak sa nachadza v kabine osoba, 
        orl      C, DPZK        ;;
        orl      C, DPK         ;;
        jnc      $+8            ;;
        mov      A, INPORTA     ;;
        anl      A, #00011110b  ;; ...a nie je vybrata ziadna volba (v kabine)
        jz       NAVESTIE       ;; skoc na navestie
ENDM


;*******************************************************************************
;   Rychlost a smer pohybu motora
;-------------------------------------------------------------------------------
;
;   Nastavenie smeru pohybu motora - hore
SET_UP MACRO
        setb     UP
        clr      DOWN
        setb     LEDU
        clr      LEDD 
ENDM

;   Nastavenie smeru pohybu motora - dole
SET_DOWN MACRO
        clr     UP
        setb    DOWN
        clr     LEDU
        setb    LEDD 
ENDM

;   Nastavenie rychlosti pohybu motora - rychlo
SET_FAST MACRO
        setb     FAST
        clr      SLOW
        setb     KS      
ENDM

;   Nastavenie smeru pohybu motora - hore
SET_SLOW MACRO
        setb     SLOW
        clr      FAST
        setb     KS
ENDM
 
  