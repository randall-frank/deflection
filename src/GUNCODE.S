        ORG $7000
        DSK   ../bin/GUNCODE#067000
        TYP   $06  ; /BIN file

        PUT COMMON.S

XIN = 0
YIN = 1
DIN = 2

        JMP STARTUP
        
MULT    LDA #0
        STY MULTY
MULT1   DEX
        BMI MULT2
        CLC
        ADC MULTY
        JMP MULT1
MULTY   DFB 0
MULT2   RTS
DIV     STY MULTY
        TXA
        LDX #0
DIV1    CMP MULTY
        BLT DIV2
        SEC
        SBC MULTY
        INX
        JMP DIV1
DIV2    TXA
        RTS
GETDXDY LDX X1
        LDA T
        ASL
        ASL
        ASL
        CLC
        ADC DIR,X
        TAX
        LDA DXTBL,X
        STA DX
        LDA DYTBL,X
        STA DY
        RTS

PITCH   DFB 0

DELAY   LDA SOUNDON
        BNE :laser
        LDA #$20            ; 0.5*(26 + 27*A + 5*A*A) cycles
        JSR WAIT
        RTS
:laser  LDX #10
:long   LDY PITCH
:short  DEY
        BNE :short
        STA SPKR
        DEX
        BNE :long
        LDA PITCH
        CMP #200
        BGE :done
        CLC
        ADC #1
        STA PITCH
:done   RTS

XPOS    DFB 0
YPOS    DFB 0
DX      DFB 0
DY      DFB 0
TOTAL   DFB 0
T       DFB 0
STAT    HEX 0000000000000000
XDAT    HEX 0000000000000000
YDAT    HEX 0000000000000000
DIR     HEX 0000000000000000
X1      DFB 0

STARTUP
        LDA #20
        STA PITCH
        LDA #0
        LDX #7
S1      STA STAT,X
        DEX
        BPL S1
        LDA #1
        STA STAT
        LDX XIN
        LDY #21
        JSR MULT
        CLC
        ADC #10
        STA XDAT
        LDX YIN
        LDY #19
        JSR MULT
        CLC
        ADC #9
        STA YDAT
        LDA DIN
        STA DIR
        LDA #0
        STA TOTAL
NEXTLOOP 
        LDA #0
        STA T
TLOP    LDA #7
        STA X1
LOOP1   JSR GETDXDY
        LDX X1
        LDA STAT,X
        BEQ NODO
        LDX X1
        LDA XDAT,X
        CLC
        ADC DX
        STA XDAT,X
        PHA
        LDA YDAT,X
        CLC
        ADC DY
        STA YDAT,X
        TAY
        PLA
        TAX
        TYA
        JSR BPLOT
        JSR DELAY
        LDY X1
        LDA XDAT,Y
        TAX
        LDA YDAT,Y
        JSR WPLOT
NODO    DEC X1
        BPL LOOP1
        INC T
        LDA T
        CMP #21
        BNE TLOP
        LDA #7
        STA X1
LOOP2   LDX X1
        LDA STAT,X
        BEQ LOOP222
        CMP #2
        BNE LOOP22
        LDA #1
        STA STAT,X
        JMP LOOP222
LOOP22  LDA XDAT,X
        SEC
        SBC #10
        TAX
        LDY #21
        JSR DIV
        STA XPOS
        LDX X1
        LDA YDAT,X
        SEC
        SBC #9
        TAX
        LDY #19
        JSR DIV
        STA YPOS
        JSR HANDLEIT
LOOP222 DEC X1
        BPL LOOP2
        LDA #7
        STA X1
ZQZ1    LDX X1
        LDA STAT,X
        CMP #2
        BNE ZQZ2
        LDA #1
        STA STAT,X
ZQZ2    DEC X1
        BPL ZQZ1
        INC TOTAL
        LDA TOTAL
        CMP #50
        BEQ OUTWEGO
        JMP NEXTLOOP
OUTWEGO RTS

CDIR    DFB 0
PIECE   DFB 0
Z       DFB 0

HANDLEIT 
        LDX X1
        LDA DIR,X
        STA CDIR
        LDX YPOS
        LDY #10
        JSR MULT
        CLC
        ADC XPOS
        TAY
        LDA BOARDBASE,Y
        AND #$7F
        CMP #$1F          ; the non-drawn $1F is interpreted as $1E
        BLT :okblk
        LDA #$1E
:okblk  STA PIECE
        ASL
        ASL
        ASL
        CLC
        ADC CDIR
        TAX
        LDA DIRBASE,X
        STA Z
        CMP #8
        BGE H1
        LDX X1
        STA DIR,X
        RTS
H1      CMP #8
        BNE H2
        LDX X1
        LDA #0
        STA STAT,X
        LDA PIECE
        CMP #9
        BGE H11
        RTS
H11     CMP #30
        BEQ H11-1
        LDA #0
        STA BOARDBASE,Y
        LDA XPOS
        STA 0
        LDA YPOS
        STA 1
        LDA #1
        STA 4
        STA 5
        LDA #63
        STA 2
        JSR LASER
        RTS
H2      LDA #7
        STA X2
H3      LDX X2
        LDA STAT,X
        BEQ H4
        DEC X2
        BPL H3
        LDA #0
        LDX X1
        STA STAT,X
        RTS

X2      DFB 0
DIR2    DFB 0

H4      LDA Z
        CMP #10
        BEQ YSPLIT
        LDX CDIR
        INX
        INX
        STX DIR2
        DEC CDIR
        DEC CDIR
        JMP CONSOL
YSPLIT  LDX CDIR
        INX
        STX DIR2
        DEC CDIR
CONSOL  LDA CDIR
        BMI C1
        CMP #8
        BLT OK1
        SEC
        SBC #8
        STA CDIR
        JMP OK1
C1      CLC
        ADC #8
        STA CDIR
OK1     LDA DIR2
        BMI C2
        CMP #8
        BLT OK2
        SEC
        SBC #8
        STA DIR2
        JMP OK2
C2      CLC
        ADC #8
        STA DIR2
OK2     LDX X1
        LDA CDIR
        STA DIR,X
        LDY X2
        LDA XDAT,X
        STA XDAT,Y
        LDA YDAT,X
        STA YDAT,Y
        LDA #2
        STA STAT,Y
        LDA DIR2
        STA DIR,Y
        RTS

* plot white pixel (can only plot X from [0,255])
* A=Ypos, X=XposLO, Y=XposHI (like the HPOSN call)

WPLOT   TAY
        LDA     HIGH,Y
        STA     $27
        LDA     LO,Y
        STA     $26
        LDA     D7BYTE,X
        TAY
        LDA     D7SHIFT,X
        TAX
        LDA     ($26),Y
        ORA     PBITS,X
        STA     ($26),Y
        RTS

* plot black pixel (can only plot X from [0,255])
* A=Ypos, X=XposLO, Y=XposHI (like the HPOSN call)

BPLOT   TAY
        LDA     HIGH,Y
        STA     $27
        LDA     LO,Y
        STA     $26
        LDA     D7BYTE,X
        TAY
        LDA     D7SHIFT,X
        TAX
        LDA     ($26),Y
        AND     PMASK,X
        STA     ($26),Y
        RTS

* input from [0,255] return X // 7 and X % 7 for pre-shifted
* table plotting.  Essentially high-speed division by 7

D7BYTE  DFB      0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 2, 2
        DFB      2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4
        DFB      4, 4, 4, 5, 5, 5, 5, 5, 5, 5, 6, 6, 6, 6, 6, 6
        DFB      6, 7, 7, 7, 7, 7, 7, 7, 8, 8, 8, 8, 8, 8, 8, 9
        DFB      9, 9, 9, 9, 9, 9,10,10,10,10,10,10,10,11,11,11
        DFB     11,11,11,11,12,12,12,12,12,12,12,13,13,13,13,13
        DFB     13,13,14,14,14,14,14,14,14,15,15,15,15,15,15,15
        DFB     16,16,16,16,16,16,16,17,17,17,17,17,17,17,18,18
        DFB     18,18,18,18,18,19,19,19,19,19,19,19,20,20,20,20
        DFB     20,20,20,21,21,21,21,21,21,21,22,22,22,22,22,22
        DFB     22,23,23,23,23,23,23,23,24,24,24,24,24,24,24,25
        DFB     25,25,25,25,25,25,26,26,26,26,26,26,26,27,27,27
        DFB     27,27,27,27,28,28,28,28,28,28,28,29,29,29,29,29
        DFB     29,29,30,30,30,30,30,30,30,31,31,31,31,31,31,31
        DFB     32,32,32,32,32,32,32,33,33,33,33,33,33,33,34,34
        DFB     34,34,34,34,34,35,35,35,35,35,35,35,36,36,36,36

D7SHIFT DFB      0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1
        DFB      2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3
        DFB      4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5
        DFB      6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0
        DFB      1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2
        DFB      3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4
        DFB      5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6
        DFB      0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1
        DFB      2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3
        DFB      4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5
        DFB      6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0
        DFB      1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2
        DFB      3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4
        DFB      5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6
        DFB      0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1
        DFB      2, 3, 4, 5, 6, 0, 1, 2, 3, 4, 5, 6, 0, 1, 2, 3

PBITS   HEX      01020408102040
PMASK   HEX      FEFDFBF7EFDFBF

* 1 2 4 8 1 2 4 1 2 4 8 1 2 4
* 1 0 0 0 0 0 0 0 1 1 1 1 1 1 1 - $01 $FE
* 0 1 0 0 0 0 0 1 0 1 1 1 1 1 1 - $02 $FD 
* 0 0 1 0 0 0 0 1 1 0 1 1 1 1 1 - $04 $FB
* 0 0 0 1 0 0 0 1 1 1 0 1 1 1 1 - $08 $F7 
* 0 0 0 0 1 0 0 1 1 1 1 0 1 1 1 - $10 $EF
* 0 0 0 0 0 1 0 1 1 1 1 1 0 1 1 - $20 $DF
* 0 0 0 0 0 0 1 1 1 1 1 1 1 0 1 - $40 $BF
