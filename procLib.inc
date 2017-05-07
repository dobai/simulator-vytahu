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
    ;jnb     TI, $ 
    ;clr     TI
_1: JBC   TRE, _2
    JMP   _1
_2:  
		mov     SBUF, A
    ;setb    EA
    ret
    
;*******************************************************************************
;   Nacitanie znaku zo seriovej linky
;-------------------------------------------------------------------------------
;     Vypise jeden znak v <A> na seriovu linku.   
;    
;READCHAR:
;		jnb     RI, $
;    clr     RI
;    mov     A, SBUF
;    ret



;*******************************************************************************
;   Obsluha prerusenia seriovej linky
;-------------------------------------------------------------------------------
;     Ide o prerusenie seriovej linky. Ak je k dispozicii znak, 
;     ulozi ho do buffra.
;     V pripade, ze je nacitany znak konca ramca, vynuluje 
;     ukazovatel do buffra a nastavi priznak S_RI   
;  
SERIAL_INT:
		;clr		EA
    push    PSW
		push    ACC
		push    1 ;R1
    
    
		jnb		RI, SERIAL_INT_TI					; Ak neslo o recieve interrupt, ideme na transmit interrupt
		clr		RI
		mov		A, SBUF
		cjne	A, #07Eh, SERIAL_INT_RCV
SERIAL_INT_EOF:		
		mov		MSG_PTR_REC, #0
		setb	S_RI
		jmp		SERIAL_INT_TI
SERIAL_INT_RCV:		
    jb		S_RI, SERIAL_INT_TI 				; ak sme este stale neznulovali priznak prijatej spravy, nenacitavame dalsiu
		push    ACC
		mov		A, #80h
		add		A, MSG_PTR_REC
		mov		R1, A
		pop     ACC
		mov		@R1, A
		inc		MSG_PTR_REC
		;jmp		SERIAL_INT_END
SERIAL_INT_TI:
    jnb    TI, SERIAL_INT_END
    setb  TRE        ;<------------
		clr		TI
SERIAL_INT_END:

		pop     1 ;R1
		pop     ACC
    pop     PSW
		;setb	EA
		reti
    
		
    
    
    
    			
		; nacitanie a odpoved na spravu
RCV_MESSAGE:	
    push    PSW
    push    T2CON
    push    T2_C
    push    T2
    
RCV_MESSAGE1:
	;	Prijatie spravy
		TIMER2	80						; Nastavi sa casovac na 4 sekundy. Ak za tento cas nepride sprava, rutina sa skonci
RCV_LOOP:
		jb		T2_F, RCV_MESSAGE_END	; Caka sa na prijatie spravy spravu - malo by to byt hned, lebo sme sem skocili, ked bolo S_RI rovne jednej, ale ked je NACK, tak skaceme sem (a cakame na resend)
		lcall   READPORTS
    jnb		S_RI, RCV_LOOP	

		
		
	;	Vypocet CRC						; Vypocita sa pre kolko bajtov treba spocitat CRC
		mov     R0, #80H			  	; 	Adresa prveho bajtu prijatej spravy (Count)
		mov		A, @R0					;
		mov		B, #2					;	(Count * 2) + 1, lebo datove bloky su dvojbajtove
		mul		AB						;	 a cisluje sa od 1.
		inc 	A						;	
		mov		MSG_LEN, A				;
		mov		R2, MSG_LEN				; Vypocet CRC:  
		mov     R0, #80H 			  	; 	R2 = dlzka bloku, 
		lcall	CALC_CRCX				;	R0 = adresa zaciatku bloku                                                                                             ;<<<<<<<<<<<<<<<<<<<
		cjne	A, #7Eh, RCV_CONT		; Ak vyslo CRC 0x7E, pripocitame 1
		inc		A						;	(jedna sa totiz o kridlovu znacku)
RCV_CONT:	
	; 	Kontrola spravnosti CRC
		mov		B, A					; Prave vypocitane CRC zalohujeme do B
		mov		A, MSG_LEN				; Nacita sa prijate CRC
		orl		A, #80h					;	80h + MSG_LEN (dlzka spravy) + 1 
		mov		R0, A					;		  	 
		mov		A, @R0					;
		cjne	A, B, NACK				; Porovnanie CRC. Ak sa nezhoduje, posiela sa NACK

	;	Poslanie ACK
ACK:
        mov     DPTR, #COM_ACK        	; Posle sa predpripravena sprava ACK 
        lcall   DISPSTR                 ; a pokracuje sa spracovanim prijatej spravy		
		jmp		PROCESS
		
		
	;	Poslanie NACK
NACK:
    mov     DPTR, #COM_NACK         ; Posle sa predpripravena sprava NACK
    lcall   DISPSTR 			    ; a skoci sa na zaciatok tejto rutiny pre prijatie novej spravy
		clr		S_RI				    ; Prijata sprava bola tym padom spracovana, mozme vynulovat priznak S_RI
		jmp		RCV_MESSAGE1

	; 	Priprava odpovede
PROCESS:
		
		clr		S_RI				    ; Prijata sprava bola tym padom spracovana, mozme vynulovat priznak S_RI
		
		mov		A, #08h
		mov		R0, #0C0h
SLOOP:	mov		@R0, A
		inc		R0
		dec		A
		jnz		SLOOP
		mov		@R0, #0h
		
		;mov     R0, #0C0h          	    ; Odoslanie odpovede
		;lcall	DISPSTRI			    ; z vyrovnavacej pamate urcenej pre odpoved D:0C0h
		
		lcall	SND_MESSAGE				;odoslanie spravy                                                                                                                         <<<<<<<<<<
		
		
RCV_MESSAGE_END:

    pop     T2
    pop     T2_C
    pop     T2CON
    pop     PSW
		ret




;-------ODPOVED---------------------------------------------------------

SND_MESSAGE:
		push    PSW
    push    0 ;R0
    push    1 ;R1
    push    5 ;R5

	; 	Priprava odpovede
		mov		A, #08h
		mov		R0, #0C0h
S2LOOP:	mov		@R0, A
		inc		R0
		dec		A
		jnz		S2LOOP
		mov		@R0, #0h
	; 	Priprava odpovede
		
		
		;Zistenie, o aky typ spravy ide
		mov		MSG_PTR_S, #0C1h
		mov		R0, #0C0h
		mov		@R0, #0
		mov		R0, #80h
		mov 	A,  @R0
		mov		R1, A 
		mov		R0, #81h
		mov 	MSG_PTR_R,  R0
SND_DATA_LOOP:
		mov		A, @R0
		CLCALLE A, #0, MSG00
		CLCALLE A, #1, MSG01
		inc		R0
		inc		R0
		dec		R1
		mov		A, R1
		jnz		SND_DATA_LOOP
		
		;	Vypocet CRC					; Vypocita sa pre kolko bajtov treba spocitat CRC
		mov     R0, #0C0H			  	; 	Adresa prveho bajtu spravy (Count)
		mov		A, @R0					;
		mov		B, #2					;	(Count * 2) + 1, lebo datove bloky su dvojbajtove
		mul		AB						;	 a cisluje sa od 1.
		inc 	A						;	
		mov		MSG_LEN, A				;
		mov		R2, MSG_LEN				; Vypocet CRC:  
		mov     R0, #0C0H 			  	; 	R2 = dlzka bloku, 
		lcall	CALC_CRCX				;	R0 = adresa zaciatku bloku
		cjne	A, #7Eh, SND_CONT		; Ak vyslo CRC 0x7E, pripocitame 1
		inc		A						;	(jedna sa totiz o kridlovu znacku)
SND_CONT:								;
		mov		@R0, A					; Ulozenie CRC8 do buffra
		
		
		
		mov		R5, #5					;max. 5 pokusov o znovuodoslanie spravy
SND:		
		mov     R0, #0C0h          	    ; Odoslanie odpovede
		lcall	DISPMSG			    	; z vyrovnavacej pamate urcenej pre odpoved D:0C0h
		dec		R5						; a zaznamename, ze sme poslali spravu
		
		;clr		S_RI				; Prijata sprava bola tym padom spracovana, mozme vynulovat priznak S_RI
		
		TIMER2	80						; Nastavi sa casovac na 4 sekundy. Ak za tento cas nepride sprava, rutina sa skonci
SND_LOOP:
    lcall   READPORTS
		jb		T2_F, SND_MESSAGE_END	; Caka sa na prijatie spravy spravu - malo by to byt hned, lebo sme sem skocili, ked bolo S_RI rovne jednej, ale ked je NACK, tak skaceme sem (a cakame na resend)
		mov		A, R5
		jz		SND_MESSAGE_END   ; Ak sme uz spravu preposielali 5. krat, koncime
		jnb		S_RI, SND_LOOP	
		
		clr		S_RI					; Prijata sprava bola tym padom spracovana, mozme vynulovat priznak S_RI

		mov		R0, #80h
		mov 	A,  @R0
		cje		A,  #0FEh, SND_MESSAGE_END
		cje		A,  #0FFh, SND

SND_MESSAGE_END:
    mov		MSG_PTR_S, #0C1h

    pop     5 ;R5
    pop     1 ;R1
    pop     0 ;R0
    pop     PSW
		ret


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Sprava 0
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MSG00:
		push    0 ;R0
		push    ACC
		mov		R0, MSG_PTR_S
		mov		@R0, #4h
		inc		R0
		mov		@R0, #00000000b
		
		mov		R0, #0C0h
		inc		@R0
		
		inc		MSG_PTR_S
		inc		MSG_PTR_S
		
		pop     ACC
		pop     0 ;R0
		ret
        
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Sprava 1
; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
MSG01:
		push    0 ;R0
		push    ACC
    push    B
    
		mov		R0, MSG_PTR_S
		mov		@R0, #5h
		inc		R0
    
    mov   A, POSCHODIE                  ; poschodie, na ktorom sa nachadzame
    orl   A, PORUCHA                    ; posledna rozpoznana porucha
    
MSG01_DP:
    jnb   DP, MSG01_DPZK
    orl   A, #08h
MSG01_DPZK:
    jnb   DPZK, MSG01_DPK
    orl   A, #10h
MSG01_DPK:     
    jnb   DPK, MSG01_CONT
    orl   A, #18h
MSG01_CONT:
        
		mov		@R0, A
    mov   PORUCHA, #0 ;porucha 000 - bez poruchy (vynulujem poruchy)
		
		mov		R0, #0C0h
		inc		@R0
		
		inc		MSG_PTR_S
		inc		MSG_PTR_S
		
    pop     B
		pop     ACC
		pop     0 ;R0
		ret



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DISPMSG
; posle na seriovu linku retazec z buff (ROM, nepriame adresovanie)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DISPMSG:
    push    PSW
    push    ACC
		push    0; R0
		push    1; R1
		
		mov		R1, #0C0h
		mov		A, @R1
		mov		B, #2
		mul		AB
		inc		A
		inc		A
		mov		R1, A
    mov   R0, #0C0h
		
DISPMSG_LOOP:           
		mov     A, R1
    jz      DISPMSG_END
		mov     A, @R0
		;jnb     TI, $
		;clr     TI
    ;    mov     SBUF, A
    lcall   PRINTCHAR
    inc     R0
		dec		  R1
    sjmp    DISPMSG_LOOP
DISPMSG_END:
		mov     A, #07Eh		; odoslanie kridlovej znacky
		;jnb     TI, $
		;clr     TI
    ;    mov     SBUF, A
		lcall   PRINTCHAR
    
    
		pop     1; R1
		pop     0; R0
    pop     ACC
    pop     PSW
    ret


;****************************************************************************
;
;  Description:
;       Calculates Value In Acc Into The Running CRC In 'B', Using The Table
;       Method.  (Faster But Larger)
;
;  Entry Requirements:
;       Acc Has Value To Add To CRC
;       'B' Contains Running CRC Value
;
;  On Exit:
;       'B' Has Updated CRC Value
;
;  Affected:
;       PSW.CY, B
;
;  Stack:
;       3 Bytes, Not Including Called Routines
;
;  Comments:
;       None


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CALC_CRCX
; Vypocita CRC retazca s adresou v R0 a s dlzkou v R2
; Vysledok vrati do A
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CALC_CRCX:
    push    PSW
		push    B
		;mov		R0, A
		
		mov 	  B, #00h;
CRCX_LOOP:      
		cjne	  R2, #0h, CRCX_CONT
		jmp		  CRCX_END
CRCX_CONT:		
    clr     A
    mov    	A, @R0	
    lcall	  CRC8_ADD_TABLE;
    inc     R0
		dec		  R2
		jmp		  CRCX_LOOP
CRCX_END:
		mov		  A, B
    
		pop     B
    pop     PSW
    ret
        

CRC8_ADD_TABLE:  
                push    dph                     ; Save DPH
                push    dpl                     ; Save DPL
                push    acc                     ; Save Acc
;
                mov     dptr, #CRC8_DATA         ; Point To Table
                xrl     a,b                     ; XOR In CRC
                movc    a,@a+dptr               ; Get New CRC Byte
                mov     b,a                     ; Store Back
;
                pop     acc                     ; Recover Acc
                pop     dpl                     ; Recover DPL
                pop     dph                     ; Recover DPH
                ret                             ; Return To Caller
                
CRC8_DATA:      db      000h, 05eh, 0bch, 0e2h, 061h, 03fh, 0ddh, 083h
                db      0c2h, 09ch, 07eh, 020h, 0a3h, 0fdh, 01fh, 041h
                db      09dh, 0c3h, 021h, 07fh, 0fch, 0a2h, 040h, 01eh
                db      05fh, 001h, 0e3h, 0bdh, 03eh, 060h, 082h, 0dch
                db      023h, 07dh, 09fh, 0c1h, 042h, 01ch, 0feh, 0a0h
                db      0e1h, 0bfh, 05dh, 003h, 080h, 0deh, 03ch, 062h
                db      0beh, 0e0h, 002h, 05ch, 0dfh, 081h, 063h, 03dh
                db      07ch, 022h, 0c0h, 09eh, 01dh, 043h, 0a1h, 0ffh
                db      046h, 018h, 0fah, 0a4h, 027h, 079h, 09bh, 0c5h
                db      084h, 0dah, 038h, 066h, 0e5h, 0bbh, 059h, 007h
                db      0dbh, 085h, 067h, 039h, 0bah, 0e4h, 006h, 058h
                db      019h, 047h, 0a5h, 0fbh, 078h, 026h, 0c4h, 09ah
                db      065h, 03bh, 0d9h, 087h, 004h, 05ah, 0b8h, 0e6h
                db      0a7h, 0f9h, 01bh, 045h, 0c6h, 098h, 07ah, 024h
                db      0f8h, 0a6h, 044h, 01ah, 099h, 0c7h, 025h, 07bh
                db      03ah, 064h, 086h, 0d8h, 05bh, 005h, 0e7h, 0b9h
                db      08ch, 0d2h, 030h, 06eh, 0edh, 0b3h, 051h, 00fh
                db      04eh, 010h, 0f2h, 0ach, 02fh, 071h, 093h, 0cdh
                db      011h, 04fh, 0adh, 0f3h, 070h, 02eh, 0cch, 092h
                db      0d3h, 08dh, 06fh, 031h, 0b2h, 0ech, 00eh, 050h
                db      0afh, 0f1h, 013h, 04dh, 0ceh, 090h, 072h, 02ch
                db      06dh, 033h, 0d1h, 08fh, 00ch, 052h, 0b0h, 0eeh
                db      032h, 06ch, 08eh, 0d0h, 053h, 00dh, 0efh, 0b1h
                db      0f0h, 0aeh, 04ch, 012h, 091h, 0cfh, 02dh, 073h
                db      0cah, 094h, 076h, 028h, 0abh, 0f5h, 017h, 049h
                db      008h, 056h, 0b4h, 0eah, 069h, 037h, 0d5h, 08bh
                db      057h, 009h, 0ebh, 0b5h, 036h, 068h, 08ah, 0d4h
                db      095h, 0cbh, 029h, 077h, 0f4h, 0aah, 048h, 016h
                db      0e9h, 0b7h, 055h, 00bh, 088h, 0d6h, 034h, 06ah
                db      02bh, 075h, 097h, 0c9h, 04ah, 014h, 0f6h, 0a8h
                db      074h, 02ah, 0c8h, 096h, 015h, 04bh, 0a9h, 0f7h
                db      0b6h, 0e8h, 00ah, 054h, 0d7h, 089h, 06bh, 035h                
                