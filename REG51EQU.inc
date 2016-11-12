; (c) by TEMU developers

    ; Some byte addresses
P0      EQU    080H    ; Port 0
SP      EQU    081H    ; Stack pointer
DPL     EQU    082H
DPH     EQU    083H
PCON    EQU    087H
TCON    EQU    088H
TMOD    EQU    089H
TL0     EQU    08AH
TL1     EQU    08BH
TH0     EQU    08CH
TH1     EQU    08DH
P1      EQU    090H    ; Port 1
SCON    EQU    098H
SBUF    EQU    099H
P2      EQU    0A0H    ; Port 2
IE      EQU    0A8H
P3      EQU    0B0H    ; Port 3
IP      EQU    0B8H
PSW     EQU    0D0H
ACC     EQU    0E0H    ; Accumulator
B       EQU    0F0H    ; Secondary Accumulator
 
    ;Now some bit addresses
P0.0    BIT    080H    ; Port 0 bit 0
P0.1    BIT    081H    ; Port 0 bit 1
P0.2    BIT    082H    ; Port 0 bit 2
P0.3    BIT    083H    ; Port 0 bit 3
P0.4    BIT    084H    ; Port 0 bit 4
P0.5    BIT    085H    ; Port 0 bit 5
P0.6    BIT    086H    ; Port 0 bit 6
P0.7    BIT    087H    ; Port 0 bit 7
P1.0    BIT    090H    ; Port 1 bit 0
P1.1    BIT    091H    ; Port 1 bit 1
P1.2    BIT    092H    ; Port 1 bit 2
P1.3    BIT    093H    ; Port 1 bit 3
P1.4    BIT    094H    ; Port 1 bit 4
P1.5    BIT    095H    ; Port 1 bit 5
P1.6    BIT    096H    ; Port 1 bit 6
P1.7    BIT    097H    ; Port 1 bit 7
P2.0    BIT    0A0H    ; Port 2 bit 0
P2.1    BIT    0A1H    ; Port 2 bit 1
P2.2    BIT    0A2H    ; Port 2 bit 2
P2.3    BIT    0A3H    ; Port 2 bit 3
P2.4    BIT    0A4H    ; Port 2 bit 4
P2.5    BIT    0A5H    ; Port 2 bit 5
P2.6    BIT    0A6H    ; Port 2 bit 6
P2.7    BIT    0A7H    ; Port 2 bit 7
P3.0    BIT    0B0H    ; Port 3 bit 0
P3.1    BIT    0B1H    ; Port 3 bit 1
P3.2    BIT    0B2H    ; Port 3 bit 2
P3.3    BIT    0B3H    ; Port 3 bit 3
P3.4    BIT    0B4H    ; Port 3 bit 4
P3.5    BIT    0B5H    ; Port 3 bit 5
P3.6    BIT    0B6H    ; Port 3 bit 6
P3.7    BIT    0B7H    ; Port 3 bit 7
ACC.0   BIT    0E0H    ; Acc bit 0
ACC.1   BIT    0E1H    ; Acc bit 1
ACC.2   BIT    0E2H    ; Acc bit 2
ACC.3   BIT    0E3H    ; Acc bit 3
ACC.4   BIT    0E4H    ; Acc bit 4
ACC.5   BIT    0E5H    ; Acc bit 5
ACC.6   BIT    0E6H    ; Acc bit 6
ACC.7   BIT    0E7H    ; ACC bit 7
B.0     BIT    0F0H    ; B bit 0
B.1     BIT    0F1H    ; B bit 1
B.2     BIT    0F2H    ; B bit 2
B.3     BIT    0F3H    ; B bit 3
B.4     BIT    0F4H    ; B bit 4
B.5     BIT    0F5H    ; B bit 5
B.6     BIT    0F6H    ; B bit 6
B.7     BIT    0F7H    ; B bit 7
 
EA      BIT    0AFH    ; Enable ALL interrupts
TR0     BIT    08CH    ; Start T0
TR1     BIT    08EH    ; Start T1
ET0     BIT    0A9H    ; Enable int. from T0
ET1     BIT    0ABH    ; Enable int. from T0
RI      BIT    098H    ; Received data flag
TI      BIT    099H    ; Transmitted data flag

