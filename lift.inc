
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
; ERRFLOOR > |       |       |       | ErrF4 | ErrF3 | ErrF2 | ErrF1 |       |
; ****************************************************************************


; adresy I/O portov, ktore pridu na port P2 89C52-ky
i8255INA        equ     080h
i8255INB        equ     081h
i8255INC        equ     082h
i8255INCW       equ     083h
i8255OUTA       equ     0c0h
i8255OUTB       equ     0c1h
i8255OUTC       equ     0c2h
i8255OUTCW      equ     0c3h

INPORTA         data    28h         ; nutne kvoli emulatoru!!!
INPORTB         data    21h
INPORTC         data    22h
OUTPORTA        data    23h
OUTPORTB        data    24h
OUTPORTC        data    25h
INPORTBold      data    26h
CTRLREG         data    27h

ERRFLOOR_U      data    2Ah
ERRFLOOR_D      data    2Bh

ERRF1_U         bit     ERRFLOOR_U.1
ERRF2_U         bit     ERRFLOOR_U.2
ERRF3_U         bit     ERRFLOOR_U.3
ERRF4_U         bit     ERRFLOOR_U.4  

ERRF12_U        bit     ERRFLOOR_U.2
ERRF23_U        bit     ERRFLOOR_U.3
ERRF34_U        bit     ERRFLOOR_U.4   

ERRF1_D         bit     ERRFLOOR_D.1
ERRF2_D         bit     ERRFLOOR_D.2
ERRF3_D         bit     ERRFLOOR_D.3
ERRF4_D         bit     ERRFLOOR_D.4   

ERRF12_D        bit     ERRFLOOR_D.1
ERRF23_D        bit     ERRFLOOR_D.2
ERRF34_D        bit     ERRFLOOR_D.3    

ERRF1_C         data    35h
ERRF2_C         data    36h
ERRF3_C         data    37h
ERRF4_C         data    38h

ERRF12_C        data    39h
ERRF23_C        data    3Ah
ERRF34_C        data    3Bh
           
POSITION        data    30h
LOWEST          data    31h
HIGHEST         data    32h
STOPTIMER       data    33h
OUTPORTBold     data    34h

G        		data    3Ch
D1	        data    3Dh
D2          data    3Eh

STOPNOT         bit     INPORTA.0
PKI1            bit     INPORTA.1
PKI2            bit     INPORTA.2
PKI3            bit     INPORTA.3
PKI4            bit     INPORTA.4
DOORCLSD        bit     INPORTA.5 

MB1             bit     INPORTB.1       ; clonky maju invertovanu logiku
MB2             bit     INPORTB.2
SKRH            bit     INPORTB.3
SKRD            bit     INPORTB.4
DP              bit     INPORTB.5
DPZK            bit     INPORTB.6
DPK             bit     INPORTB.7

MB1old          bit     INPORTBold.1
MB2old          bit     INPORTBold.2
SKRHold         bit     INPORTBold.3
SKRDold         bit     INPORTBold.4

PI1             bit     INPORTC.0
PI2D            bit     INPORTC.1
PI2U            bit     INPORTC.2
PI3D            bit     INPORTC.3
PI3U            bit     INPORTC.4
PI4             bit     INPORTC.5

KS              bit     OUTPORTA.0
PKO1            bit     OUTPORTA.1
PKO2            bit     OUTPORTA.2
PKO3            bit     OUTPORTA.3
PKO4            bit     OUTPORTA.4

UP              bit     OUTPORTB.0
DOWN            bit     OUTPORTB.1
FAST            bit     OUTPORTB.2
SLOW            bit     OUTPORTB.3
FLED1           bit     OUTPORTB.4
FLED2           bit     OUTPORTB.5
FLED3           bit     OUTPORTB.6
FLED4           bit     OUTPORTB.7

PO1U            bit     OUTPORTC.0
PO1D            bit     OUTPORTC.0
PO1             bit     OUTPORTC.0
PO2D            bit     OUTPORTC.1
PO2U            bit     OUTPORTC.2
PO3D            bit     OUTPORTC.3
PO3U            bit     OUTPORTC.4
PO4             bit     OUTPORTC.5
PO4U            bit     OUTPORTC.5
PO4D            bit     OUTPORTC.5
LEDD            bit     OUTPORTC.6
LEDU            bit     OUTPORTC.7

STOPPED         bit     CTRLREG.0
DOORCLSDold     bit     CTRLREG.1
UPold           bit     CTRLREG.2
DOWNold         bit     CTRLREG.3
FASTold         bit     CTRLREG.4
SLOWold         bit     CTRLREG.5

WRNOT           bit     0b6h        ; p3.6
RDNOT           bit     0b7h        ; p3.7

; bitove masky
; 8255OUT 
; port A
bmKS              equ    00000001b
bmPKO1            equ    00000010b
bmPKO2            equ    00000100b
bmPKO3            equ    00001000b
bmPKO4            equ    00010000b

; port B
bmUP              equ    00000001b
bmDOWN            equ    00000010b
bmFAST            equ    00000100b
bmSLOW            equ    00001000b
bmFLED1           equ    00010000b
bmFLED2           equ    00100000b
bmFLED3           equ    01000000b
bmFLED4           equ    10000000b

; port C
bmPO1             equ    00000001b
bmPO2D            equ    00000010b
bmPO2U            equ    00000100b
bmPO3D            equ    00001000b
bmPO3U            equ    00010000b
bmPO4             equ    00100000b
bmLEDD            equ    01000000b
bmLEDU            equ    10000000b

; 8255IN
; port A
bmSTOP            equ    00000001b
bmPKI1            equ    00000010b
bmPKI2            equ    00000100b
bmPKI3            equ    00001000b
bmPKI4            equ    00010000b
bmDOORCLSD        equ    00100000b

; port B
bmMB1I            equ    00000010b
bmMB2I            equ    00000100b
bmSKRHI           equ    00001000b
bmSKRHD           equ    00010000b
bmDPI             equ    00100000b
bmDPZKI           equ    01000000b
bmDPKI            equ    10000000b

; port C
bmPI1             equ    00000001b
bmPI2D            equ    00000010b
bmPI2U            equ    00000100b
bmPI3D            equ    00001000b
bmPI3U            equ    00010000b
bmPI4             equ    00100000b

