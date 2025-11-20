        ORG $6000
        DSK   ../bin/GAME#066000
        TYP   $06  ; /BIN file
        LST OFF

COLORFLAG = $90FC
HIGH = $9500
LO = $9400
KP0 = $1C
KP1 = KP0+1
DSCREEN = $90FD
RAY = $7B00
BOARDBASE = $9200
BOARDSAVE = BOARDBASE+128
BUTTON0 = $C061
BUTTON1 = $C062
SPKR = $C030 
WAIT = $FCA8

        JMP START

CALC    LDA LO,X
        STA $26
        LDA HIGH,X
        STA $27
        RTS
SELECT  JSR CLEAROUT
        LDA #9
        LDX #7
        LDY PLAYER
        BPL SELECT1
        LDA #16
SELECT1 JMP DRAWSTR
ROTATE  JSR CLEAROUT
        LDA #10
        LDX #8
        LDY PLAYER
        BPL ROTATE1
        LDA #17
ROTATE1 JMP DRAWSTR
CLEAROUT
        LDX #1
        LDA #9
        JSR DRAWSTR
        LDX #1
        LDA #10
        JSR DRAWSTR
        LDX #1
        LDA #16
        JSR DRAWSTR
        LDX #1
        LDA #17
        JSR DRAWSTR
        RTS
KEYBOARD DFB 0
JOY     LDA #50
        STA KP0
        STA KP1
        LDA KEYBOARD
        BNE KEYS
        LDX #0
        STX KP0
        STX KP1
        LDA $C070
JOY1    LDA $C064
        BPL WJOY0
        STX KP0
PD1     LDA $C065
        BPL WJOY1
        STX KP1
PD2     INX
        BNE JOY1
KEYS    JSR ARROWS
        LDA $C000
        CMP #$92
        BEQ PD3
        CMP #$8B
        BEQ PD4
        CMP #$83
        BNE PD3-1
        STA $C010
        LDA COLORFLAG
        EOR #1
        STA COLORFLAG
        RTS
PD3     JMP GAME1
WJOY0   BPL PD1
WJOY1   BPL PD2
PD4     LDA KEYBOARD
        EOR #1
        STA KEYBOARD
        STA $C010
        RTS
ARROWS  LDA $C000
        CMP #201
        BNE AR1
        LDA #0
        STA KP1
        JMP AROUT
AR1     CMP #205
        BNE AR2
        LDA #70
        STA KP1
        JMP AROUT
AR2     CMP #202
        BNE AR3
        LDA #0
        STA KP0
        JMP AROUT
AR3     CMP #203
        BNE ARNOT
        LDA #70
        STA KP0
AROUT   STA $C010
ARNOT   RTS
DELAY   LDA #125
        JSR $FCA8
        RTS

PLAYER  DFB 0
XP      DFB 0
YP      DFB 0
Z       DFB 0

GETZ    LDA #0
        LDX YP
G1      DEX
        BMI G2
        CLC
        ADC #10
        JMP G1
G2      CLC
        ADC XP
        TAX
        LDA BOARDBASE,X
        STA Z
        RTS
DRAWCUR STA 2
        LDA XP
        STA 0
        LDA YP
        STA 1
        LDA #3
        STA 4
        LDA #1
        STA 5
        JMP $9000

* start by saving off the board starting setup

START   LDY #0
S1      LDA BOARDBASE,Y
        STA $7A00,Y
        INY
        BNE S1

* Restore the initial board setup

GAME1   LDY #0
S2      LDA $7A00,Y
        STA BOARDBASE,Y
        INY
        BNE S2

        LDX #$FF
        TXS
        STA $C010
        JSR $F3E2
        LDA $C052
        LDX #0
        LDA #0
        JSR DRAWSTR
        LDX #2
        LDA #2
        JSR DRAWSTR
        LDX #3
        TXA
        JSR DRAWSTR
        LDA #6
        LDX #4
        JSR DRAWSTR
        LDA #13
        LDX #5
        JSR DRAWSTR
        LDA #21
        LDX #10
        JSR DRAWSTR
        LDA #22
        LDX #11
        JSR DRAWSTR
        JSR RECOUNT
        LDA PLAY1
        ORA #$30
        STA BLOCKS
        LDA #7
        LDX #6
        JSR DRAWSTR
        LDA PLAY2
        ORA #$30
        STA BLOCKS
        LDA #14
        LDX #6
        JSR DRAWSTR
GAME2   JSR DSCREEN
        JSR PLAYIT
        JSR CLEAROUT
        JSR RECOUNT
        LDA PLAY1
        ORA #$30
        STA BLOCKS
        LDA #7
        LDX #6
        JSR DRAWSTR
        LDA PLAY2
        ORA #$30
        STA BLOCKS
        LDA #14
        LDX #6
        JSR DRAWSTR
        LDA PLAY1
        BNE GAME3
        JMP EOG
GAME3   LDA PLAY2
        BNE GAME4
        JMP EOG
GAME4   LDA PLAYER
        EOR #$80
        STA PLAYER
        JMP GAME2
EOG     STA $C010
        LDA #19
        LDX #9
        JSR DRAWSTR
        LDA #8
        LDX #12
        LDY PLAY1
        BNE EOG2
        INX
EOG2    JSR DRAWSTR
        LDA #15
        LDX #12
        LDY PLAY2
        BNE EOG3
        INX
EOG3    JSR DRAWSTR
EOG1    LDA $C000
        BPL EOG1
        STA $C010
        JMP GAME1

PLAY1   DFB 0  ; Number of blocks for player 1
PLAY2   DFB 0  ; Number of blocks for player 2

RECOUNT LDA #0
        STA PLAY1
        STA PLAY2

        LDY #100
SCANLOOP        
        LDA BOARDBASE,Y
        CMP #$0D
        BNE NOT0D
        INC PLAY1
NOT0D   CMP #$8D
        BNE NOT1D
        INC PLAY2
NOT1D   DEY
        BPL SCANLOOP
        RTS

FL      DFB 0
XSEL    DFB 0
YSEL    DFB 0
ZSEL    DFB 0

PLAYIT  LDY #101
PL10    LDA BOARDBASE,Y
        STA BOARDSAVE,Y
        DEY
        BPL PL10
        JMP PLAYIT2
PLAYIT3 LDY #101
PL12    LDA BOARDSAVE,Y
        STA BOARDBASE,Y
        DEY
        BPL PL12
PLAYIT2 JSR DSCREEN
        LDA #0
        STA FL
        LDA #4
        STA XP
        STA YP
        LDA #62
        JSR DRAWCUR
        JSR SELECT
P1      JSR DELAY
        JSR DELAY
        JSR JOY
        LDA #62
        JSR DRAWCUR
        LDA KP0
        CMP #20
        BGE P2
        DEC XP
        JMP P3
P2      CMP #70
        BLT P3
        INC XP
P3      LDA KP1
        CMP #20
        BGE P4
        DEC YP
        JMP P5
P4      CMP #70
        BLT P5
        INC YP
P5      LDA XP
        CMP #$FF
        BNE P6
        LDA #0
        STA XP
        JMP OK1
P6      CMP #10
        BNE OK1
        LDA #9
        STA XP
OK1     LDA YP
        CMP #$FF
        BNE P7
        LDA #0
        STA YP
        JMP OK2
P7      CMP #10
        BNE OK2
        LDA #9
        STA YP
OK2     LDA #62
        JSR DRAWCUR
        LDA BUTTON0
        BPL NO0
        LDA FL
        BNE NO0
        JSR GETZ
        LDA Z
        AND #$80
        CMP PLAYER
        BNE NO0
        LDA Z
        AND #$7F
        CMP #3
        BLT NO0
        CMP #30
        BGE NO0
        LDA XP
        STA XSEL
        LDA YP
        STA YSEL
        LDA Z
        STA ZSEL
        LDA #61
        JSR DRAWCUR
        INC FL
NO00    LDA BUTTON0
        BMI NO00
        JMP P1
NO0
        LDA BUTTON0
        BPL NO1
        LDA FL
        BEQ NO1
        LDA XP
        CMP XSEL
        BNE BBB1
        LDA YP
        CMP YSEL
        BEQ BB1
BBB1    JSR GETZ
        LDA Z
        CMP #0
        BEQ BB1
        LDA ZSEL
        AND #$7F
        CMP #9
        BGE NO1
        LDA Z
        CMP #30
        BEQ BB1
        JMP NO1
BB1     JSR TESTMOVE
        BCS NO1
        JMP MADEMOVE
NO1     LDA BUTTON1
        BMI BB2
        JMP P1
BB2     LDA FL
        BNE BB3
        JMP P1
BB3     LDA #0
        STA FL
        LDA XP
        PHA
        LDA YP
        PHA
        LDA XSEL
        STA XP
        LDA YSEL
        STA YP
        LDA #61
        JSR DRAWCUR
        PLA
        STA YP
        PLA
        STA XP
        JMP P1
MADEMOVE 
        LDA BUTTON0
        BMI MADEMOVE
        LDA #0
        LDX YSEL
MM1     DEX
        BMI MM2
        CLC
        ADC #10
        JMP MM1
MM2     CLC
        ADC XSEL
        TAX
        LDY #0
        LDA ZSEL
        AND #$7F
        CMP #9
        BGE MM3
        LDY #30
MM3     TYA
        STA BOARDBASE,X
        LDA #0
        LDX YP
MM4     DEX
        BMI MM5
        CLC
        ADC #10
        JMP MM4
MM5     CLC
        ADC XP
        TAX
        LDA ZSEL
        STA BOARDBASE,X
        STX Z
        JSR DSCREEN
        LDA ZSEL
        AND #$7F
        STA ZSEL
        JSR ROTATE
MM6     JSR DRAWROT
        JSR DELAY
        JSR DELAY
        JSR DELAY
        LDA BUTTON0
        BMI MM7
        LDA BUTTON1
        BPL PATCH1
        JMP PLAYIT3
PATCH1  JSR JOY
        LDA KP0
        CMP #70
        BLT MM6
        LDY ZSEL
        LDA ROTTBL,Y
        STA ZSEL
        JMP MM6
MM7     LDX Z
        LDA ZSEL
        ORA PLAYER
        STA BOARDBASE,X
        JSR DSCREEN
        JMP EVENMORE
DRAWROT LDA XP
        STA 0
        LDA YP
        STA 1
        LDA ZSEL
        STA 2
        LDA #1
        STA 4
        STA 5
        JMP $9000

ROTTBL  DFB 0,0,0,4,5,3,7,8,6,10,9,12,11,13,15,16,17,14
        DFB 19,18,21,20,23,22,25,24,27,28,29,26,30

EVENMORE 
        LDA ZSEL
        CMP #9
        BLT EM1
        RTS
EM1     LDA XP
        STA 0
        LDA YP
        STA 1
        LDY ZSEL
        LDA TTBL,Y
        STA 2
        LDA 1
        CMP #0
        BNE EM2
        LDA 2
        CMP #7
        BEQ EMNO
        CMP #1
        BEQ EMNO
EM2     LDA 1
        CMP #9
        BNE EM3
        LDA 2
        CMP #5
        BEQ EMNO
        CMP #3
        BEQ EMNO
EM3     JSR RAY
EMNO    RTS

TTBL    DFB 0,0,0,1,2,3,7,6,5
XT      DFB 0
YT      DFB 0
DX      DFB 0
DY      DFB 0
TESTCOUNT DFB 0

TESTMOVE 
        LDA XSEL
        STA XT
        LDA YSEL
        STA YT
        LDX #0
        LDA XSEL
        CMP XP
        BEQ TM1
        BGE TM2
        INX
        BNE TM1
TM2     DEX
TM1     STX DX
        LDX #0
        LDA YSEL
        CMP YP
        BEQ TM3
        BGE TM4
        INX
        BNE TM3
TM4     DEX
TM3     STX DY
        LDA #0
        STA TESTCOUNT
        LDA ZSEL
        AND #$7F
        CMP #9
        BGE TM5
        LDA #0
        STA DX
TM5     INC TESTCOUNT
        LDA TESTCOUNT
        CMP #15
        BNE TM6
        SEC
        RTS
TM6     LDA XT
        CLC
        ADC DX
        STA XT
        LDA YT
        CLC
        ADC DY
        STA YT
        LDA XT
        CMP XP
        BNE TM7
        LDA YT
        CMP YP
        BNE TM7
        CLC
        RTS
TM7
        LDA #0
        LDX YT
TM8     DEX
        BMI TM9
        CLC
        ADC #10
        JMP TM8
TM9     CLC
        ADC XT
        TAX
        LDA BOARDBASE,X
TM10    CMP #0
        BEQ TM5
        LDA ZSEL
        AND #$7F
        CMP #$9
        BGE TM11
        LDA BOARDBASE,X
        CMP #$1E
        BEQ TM5
TM11    SEC
        RTS
*************************
*  DRAWS STRING POINTED AT BY X REG AT X=30 Y= A LINE
************************
DRAWSTR ASL
        ASL
        ASL
        STA 1
        LDA #0
DSTR1   DEX
        BMI DSTR2
        CLC
        ADC #10
        JMP DSTR1
DSTR2   TAY
        LDA #30
        STA 0
DSTR3   LDA STRTBL,Y
        JSR PLOT
        INY
        INC 0
        LDA 0
        CMP #40
        BNE DSTR3
        RTS
PLOT    PHA
        LDA #13
        STA PLACE+2
        PLA
        ASL
        ROL PLACE+2
        ASL
        ROL PLACE+2
        ASL
        ROL PLACE+2
        STA PLACE+1
        LDX #7
        STX QQQ
        LDX 1
        STX QQ1
        STY QQ2
PLOT1   LDX 1
        JSR CALC
PLACE   LDA $FFFF
        LDY 0
        STA ($26),Y
        INC PLACE+1
        INC 1
        DEC QQQ
        BPL PLOT1
        LDX QQ1
        STX 1
        LDY QQ2
        RTS

QQQ     DFB 0
QQ2     DFB 0
QQ1     DFB 0

STRTBL  ASC 'Deflection'
        ASC '          '
        asc 'Ver: '
        PUT VERSION.S
        asc '          '
        asc ' Player 1 '
        asc ' Player 2 '
BL      asc ' Blocks:0 '
        asc ' <Select> '
        asc ' <Rotate> '
        asc 'Game Over '
        asc ' '
        hex  13
        asc    ' 1987  '
        ASC ' R. Frank '
        ASC '  Winner  '
        asc '  Loser   '

BLOCKS = BL+8

* Sound in the X register [0,15]
* Routine from Assembly Cookbook for the Apple II/IIe (Don Lancaster)
*  Chapter 4: Obnoxious Sounds

SOUND    
        PHP 
        PHA 
        TYA 
        PHA 
        TXA 
        CMP FLNGTH4 
        BCC LOK4 
        LDA #$00 
LOK4
        ASL 
        TAX 
        LDA SEFO,X 
        STA TRPCNT4 
        INX 
        LDA SEFO,X 
        STA SWEEP4+1 
SWEEP4 
        LDY #$00 
NXTSWP4 
        TYA 
        TAX 
NXTCYC4
        TYA 
        JSR WAIT 
        BIT SPKR 
        CPX #$80 
        BEQ EXIT4 
        DEX 
        BNE NXTCYC4 
        DEY 
        BNE NXTSWP4 
        DEC TRPCNT4 
        BNE SWEEP4
EXIT4 
        PLA 
        TAY 
        PLA 
        PLP 
        RTS

TRPCNT4 DFB $01
FLNGTH4 DFB $10
         ; Table for sounds that start at '5'
SEFO    DFB $01,$08 ; Tick
SEF1    DFB $01,$18 ; Whopidoop
SEF2    DFB $ff,$01 ; Pip
SEF3    DFB $06,$10 ; Phasor
SEF4    DFB $01,$30 ; Music scale (long)
SEF5    DFB $20,$06 ; Short beep
SEF6    DFB $70,$06 ; Medium beep
SEF7    DFB $ff,$06 ; Long beep
SEF8    DFB $01,$a0 ; Geiger (longish)
SEF9    DFB $ff,$02 ; Gleep (quick)
SEF10   DFB $04,$1c ; Glissade (woop,woop,woop,woop)
SEFll   DFB $01,$10 ; Qwip
SEF12   DFB $30,$0b ; Oboe (warble?  laser)
SEF13   DFB $30,$07 ; French horn (fail buzzer?)
SEF14   DFB $01,$15 ; Pass beep
SEF15   DFB $01,$64 ; Time bomb

RANDOM_SETUP 
        LDA $4E          ; Seed the random number generator
        STA R1           ; based on delay between keypresses
        STA R3
        LDA $4F
        STA R2
        STA R4
        LDX #$20         ; Generate a few random numbers
RNDLOOP JSR RANDOM       ; to kick things off
        DEX
        BNE RNDLOOP
        RTS

R1      DFB 0
R2      DFB 0
R3      DFB 0
R4      DFB 0

* return a random byte 

RANDOM  ROR R4           ; Bit 25 to carry
        LDA R3           ; Shift left 8 bits
        STA R4
        LDA R2
        STA R3
        LDA R1
        STA R2
        LDA R4           ; Get original bits 17-24
        ROR              ; Now bits 18-25 in ACC
        ROL R1           ; R1 holds bits 1-7
        EOR R1           ; Seven bits at once
        ROR R4           ; Shift right by one bit
        ROR R3
        ROR R2
        ROR
        STA R1
        RTS
