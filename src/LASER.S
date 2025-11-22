        ORG $9000
        DSK   ../bin/LASER.DRAW#069000
        TYP   $06  ; /BIN file

        PUT  COMMON.S

XLOC = 0
YLOC = 1
NUM1 = 2
NUM2 = 3
OPT = 4
SYS = 5
PTR1 = 6
PTR2 = 8
BASE = $26

* NOTE: This unit is getting close to the DIRBASE table.  When adding code
* make sure this ends by $9300 or move the DIRBASE table

* Use a dispatch table instead of forcibly aligned addresses

        JMP LOCAL_LASER     ; was $9000
        JMP LOCAL_CUT       ; was $9100
        JMP LOCAL_DSCREEN   ; was $90FD

LOCAL_COLORFLAG DFB 0       ; was $90FC

LOCAL_LASER
        LDA YLOC
        STA YSTART
        LDA XLOC
        STA XSTART
        LDA SYS
        CMP #$1
        BNE NONEED
        LDA XSTART
        ASL
        ASL
        SEC
        SBC XSTART
        STA XSTART
        LDA #0
        LDX YSTART
L1      BEQ L2
        CLC
        ADC #19
        DEX
        JMP L1
L2      STA YSTART
NONEED  LDA #0
        STA PTR1
        STA PTR2
        LDA NUM1
        LSR
        ROR PTR1
        LSR
        ROR PTR1
        ORA #$80
        STA PTR1+1
        LDA NUM2
        LSR
        ROR PTR2
        LSR
        ROR PTR2
        ORA #$80
        STA PTR2+1
        LDA #0
        STA COUNT
        LDA #19
        STA TEMP0
L3      LDX YSTART
        LDA HIGH,X
        STA BASE+1
        LDA LO,X
        STA BASE
        JSR LINE
        INC YSTART
        DEC TEMP0
        BNE L3
        RTS
LINE    LDA #3
        STA TEMP1
        LDA XSTART
        STA HOLDER
L4      LDY HOLDER
        LDA (BASE),Y
        STA SCREEN
        LDY COUNT
        LDX OPT
        DEX
        BEQ O1
        DEX
        BEQ O2
        DEX
        BEQ O3
        LDA (PTR1),Y
        ORA SCREEN
        JMP L5
O1      LDA (PTR1),Y
        JMP L5
O2      LDA (PTR1),Y
        ORA (PTR2),Y
        JMP L5
O3      LDA (PTR1),Y
        EOR SCREEN
L5      LDY HOLDER
        STA (BASE),Y
        INC COUNT
        INC HOLDER
        DEC TEMP1
        BNE L4
        RTS
 
XSTART  DFB 0
YSTART  DFB 0
COUNT   DFB 0
HOLDER  DFB 0
SCREEN  DFB 0
TEMP0   DFB 0
TEMP1   DFB 0
        DS 48
        HEX 010004000600
        DS 6

LOCAL_CUT     
        LDA NUM1
        LDY #0
        STY PTR1
        LSR
        ROR PTR1
        LSR
        ROR PTR1
        ORA #$80
        STA PTR1+1
        LDA #0
        STA TEMP0
LL2     LDX TEMP0
        LDA HIGH,X
        STA BASE+1
        LDA LO,X
        STA BASE
        LDX #0
        LDY #0
LL0     LDA (BASE),Y
        STA (PTR1,X)
        INC PTR1
        BNE LL1
        INC PTR1+1
LL1     INY
        CPY #3
        BNE LL0
        INC TEMP0
        LDA TEMP0
        CMP #19
        BNE LL2
        RTS

LOCAL_DSCREEN 
        LDA #0
        STA XLOC
        LDA #0
        STA YLOC
PAG1    LDY YLOC
        LDA #0
PAG2    DEY
        BMI PAG3
        CLC
        ADC #10
        JMP PAG2
PAG3    CLC
        ADC XLOC
        TAX
        LDA $9200,X
        STA 2
        BNE DIFF
        LDA #1
        STA 4
        STA 5
        LDA #63
        STA 2
        JMP DIFF2
DIFF    CMP #30
        BNE DIFF1
        LDA #1
        STA 4
        STA 5
        LDA #30
        STA 2
        JMP DIFF2
DIFF1   LDA 2
        CLC
        AND #$80
        ROL
        ROL
        STA 3
        LDA XLOC
        AND #1
        EOR 3
        CLC
        ADC #1
        STA 3
        LDA COLORFLAG
        BEQ DIGG
        LDA 2
        BPL DIGG
        LDA #63
        STA 3
DIGG    LDA #1
        STA 5
        LDA #2
        STA 4
        LDA 2
        AND #$7F
        STA 2
DIFF2   JSR LASER
        INC XLOC
        LDA XLOC
        CMP #10
        BLT PAG1
        LDA #0
        STA XLOC
        INC YLOC
        LDA YLOC
        CMP #10
        BLT PAG1
        RTS
