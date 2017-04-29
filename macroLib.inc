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
        ENDIF
        IF (D2val <> -1)
            mov		D2, #D2val     ;; Nastavenie priznaku <D2>
        ENDIF
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
;   Signalizacia polohy kabiny
;-------------------------------------------------------------------------------
;     Signalizuje polohu kabiny na signalizacnom paneli. 
;     Smerove sipky budu signalizovat zastavenie kabiny,
;     Poloha kabiny zavisi o parametra "POLOHA" 
;     Vykonane zmeny sa zapisu na porty     
;
POLOHA_LED  MACRO  POLOHA
        orl     OUTPORTC, #(bmLEDU or bmLEDD)
        anl     OUTPORTB, #((not bmFLED1) and(not bmFLED2) and(not bmFLED3) and(not bmFLED4))          
        setb    FLED&POLOHA
        lcall   WRITEPORTS
ENDM