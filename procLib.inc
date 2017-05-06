;*******************************************************************************
; Obsluha prerusenia casovaca 2 (Pretecenie coasovaca zaberie 50ms)
;-------------------------------------------------------------------------------
;
;     Po kazdom preteceni sa dekrementuje register <T2_C> 
;     Ked register dosiahne hodnotu 0, pocitaclo sa zastavi 
;     a nastavi sa priznak <T2_F>
; 
;     Priklad implementacie oneskorenia 3 sekundy:
;
;	      	 mov		 T2_C, #60				 ;3 sekundy
;		       clr 	   T2_F;, #0				 ;vynulovat priznak pretecenia
;		       setb	   TR2						   ;spustit casovac
;		       jnb		 T2_F, $					 ;pockame, kym prejdu 3 sec. 
;
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;        
INT_TIMER2:
		    clr     TF2
        push    ACC					      ; zaloha pouzivanych registrov        
		   
        mov     A, T2_C				    ;
        jz      INT_TIMER2_MAIN		; Ak je hodnota T2_C nula, zastavi sa poitadlo a nastavi sa priznak T2_F   
		    dec		  A                 ; dekrementovanie registra T2_C 
        mov		  T2_C, A           ;(vyhradene pre pocitadlo)
		    
        sjmp    INT_TIMER2_END		;
INT_TIMER2_MAIN:
		    clr		  TR2					      ; zastavime pocitadlo
        mov     T2_C, #0			    ; Resetujeme pocitadlo
		    setb 	  T2_F      			  ; nastavime priznak pretecenia 
INT_TIMER2_END:     
        pop     ACC					
	reti 
        
        
;*******************************************************************************
;   Vypis znaku na seriovu linku
;-------------------------------------------------------------------------------
;     Vypise jeden znak v <A> na seriovu linku.   
;
PRINTCHAR:
    jnb     TI, $ 
    clr     TI
;_1: JBC   TRE, _2
;    JMP   _1
;_2:  
		mov     SBUF, A
    ;setb    EA
    ret
    
;*******************************************************************************
;   Nacitanie znaku zo seriovej linky
;-------------------------------------------------------------------------------
;     Vypise jeden znak v <A> na seriovu linku.   
;    
READCHAR:
		jnb     RI, $
    clr     RI
    mov     A, SBUF
    ret


    
		