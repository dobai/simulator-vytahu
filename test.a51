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

_BP_    MACRO 
        clr     P3.3
        setb    EX1
        nop
        nop
ENDM


        org     0033h           ; od tejto adresy sa zacina kod programu
                                ; testovacie hodnoty
        NAJNIZSIE #10000000b
        _BP_
        NAJNIZSIE #10100010b
        _BP_
        NAJNIZSIE #10000100b
        _BP_
        NAJNIZSIE #10001001b
        _BP_
        NAJNIZSIE #10000000b
        _BP_
        NAJNIZSIE #01010110b
        _BP_

        
        end