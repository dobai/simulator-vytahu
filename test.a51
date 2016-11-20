;pokus - zistenie najvyssieho (a najnizsieho) poschodia

$MOD51
$DEBUG

NAJNIZSIE  MACRO   PRIVOLAVACE
        mov     A, PRIVOLAVACE  ; INPORTC - vektor "privolavace zo sachty"               
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

NAJVYSSIE  MACRO   PRIVOLAVACE
        mov     A, PRIVOLAVACE  ; INPORTC - vektor "privolavace zo sachty"               
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

VYSSIE_KABINA  MACRO POSCH, PRIVOLAVACE
        mov     A, PRIVOLAVACE
        anl     A, #00011110b
        clr     C
        rrc     A
;LL1    
        mov     R0, #&POSCH
        clr     C
        rrc     A
        djnz    R0, $-2;LL1
ENDM

NIZSIE_KABINA  MACRO POSCH, PRIVOLAVACE
        mov     A, #5
        clr     C
        subb    A, #&POSCH
        mov     R0, A
        mov     A, PRIVOLAVACE
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

LCJNE   MACRO   OP1, OP2, NAVESTIE
        cjne    OP1, OP2, $+6
        jmp     $+6
        ljmp    NAVESTIE
        nop
ENDM

_BP_    MACRO 
        clr     P3.3
        setb    EX1
        nop
        nop
ENDM


        org     0033h           ; od tejto adresy sa zacina kod programu
                                ; testovacie hodnoty
                                
                                
        nop
        nop
        nop
        LCJNE A, #2, LL1
        nop
        nop
        nop                         
                                
        VYSSIE_KABINA 2, #10000000b
        _BP_
        VYSSIE_KABINA 1, #10100010b
        _BP_
        VYSSIE_KABINA 1, #10000100b
        _BP_
        VYSSIE_KABINA 2, #10001001b
        _BP_
        VYSSIE_KABINA 3, #10010100b
        _BP_
        VYSSIE_KABINA 3, #01000110b
        _BP_
        
        NIZSIE_KABINA 3, #10000000b
        _BP_
        NIZSIE_KABINA 2, #10100010b
        _BP_
        NIZSIE_KABINA 2, #10000100b
        _BP_
        NIZSIE_KABINA 4, #10001001b
        _BP_
        NIZSIE_KABINA 2, #10011110b
        _BP_
        NIZSIE_KABINA 1, #01010110b
LL1:        _BP_

        
        end