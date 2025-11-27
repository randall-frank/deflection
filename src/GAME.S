        ORG $6000
        DSK   ../bin/GAME#066000
        TYP   $06  ; /BIN file
        LST OFF

        PUT COMMON.S

KP0 = $1E
KP1 = $1F

        JMP START
        JMP PLAYSOUND_LOCAL
        JMP RANDOM_SETUP_LOCAL
        JMP RANDOM_LOCAL
        JMP DRAWSTRING_LOCAL

CALC    LDA LO,X     ; set up $26,$27 to scanline in X register
        STA $26
        LDA HIGH,X
        STA $27
        RTS

STATEMSG DFB   0

DRAWBOX 
        LDY #Y_player1
        LDA #DS_box
        LDX PLAYER   ; Player 1 or 2
        BPL :nobox
        LDA #DS_unbox
:nobox  LDX #30
        JSR DRAWSTRING
        LDY #Y_player2
        LDA #DS_unbox
        LDX PLAYER   ; Player 1 or 2
        BPL :box
        LDA #DS_box
:box    LDX #30
        JSR DRAWSTRING        
        RTS

CHANGESTATE
        JSR CLEAROUT ; Display the mode message
        LDY #Y_player1+32
        LDA PLAYER   ; Player 1 or 2
        BPL :upper
        LDY #Y_player2+32
:upper  LDA STATEMSG
        LDX #31
        JMP DRAWSTRING

; Display the mode "select"

SELECT  LDA #DS_select
        STA STATEMSG
        JMP CHANGESTATE

; Display the mode "rotate"

ROTATE  LDA #DS_rotate
        STA STATEMSG
        JMP CHANGESTATE

; Display the mode "place"

PLACE   LDA #DS_place
        STA STATEMSG
        JMP CHANGESTATE

CLEAROUT             ; Remove all player status info
        LDX #31
        LDY #Y_player1+32
        LDA #DS_blank
        JSR DRAWSTRING
        LDX #31
        LDY #Y_player2+32
        LDA #DS_blank
        JSR DRAWSTRING
        JSR DRAWBOX
        RTS

DELAY   LDA #125
        JSR WAIT
        RTS

PLAYER  DFB 0
XP      DFB 0
YP      DFB 0
Z       DFB 0

GETZ    LDA #0            ; multiply YP by 10
        LDX YP
G1      DEX
        BMI G2
        CLC
        ADC #10
        JMP G1
G2      CLC               ; add XP
        ADC XP
        TAX
        LDA BOARDBASE,X   ; Z is the piece at XP,YP
        STA Z
        RTS

* Draw a piece ICON at XP,YP: 0:XP, 1:YP, 2:piece(A), 4:3, 5:1 

DRAWCUR STA 2
        LDA XP
        STA 0
        LDA YP
        STA 1
        LDA #3
        STA 4
        LDA #1
        STA 5
        JSR LASER
        RTS

* start by saving off the board starting setup

START   LDY #0
S1      LDA BOARDBASE,Y
        STA $7A00,Y
        INY
        BNE S1
        JSR RANDOM_SETUP

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
        
                        ; Initial setup
        LDA #0
        STA PLAYER

        LDY #4          ; General title
        LDX #6
        LDA #DS_deflection
        JSR DRAWSTRING
        LDY #22*8-2     ; Copyright stuff
        LDX #7
        LDA #DS_copyright
        JSR DRAWSTRING
        
        LDY #17*8         ; help text
        LDX #30
        LDA #DS_help
        JSR DRAWSTRING

        LDY #Y_player1+8   ; player strings
        LDX #31
        LDA #DS_player1
        JSR DRAWSTRING

        LDY #Y_player2+8
        LDX #31
        LDA #DS_player2
        JSR DRAWSTRING

        JSR PLAYERBLOCKS   ; 'Blocks'

* Main game loop

GAME2   JSR DSCREEN
        
        JSR ONEPLAYERTURN  ; one player's turn

        JSR CLEAROUT       ; Update state and 'score' (blocks)
        JSR PLAYERBLOCKS

* Is the game over?

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

* game over, someone lost

EOG     STA $C010

        LDY #4
        LDX #30
        LDA #DS_gameover
        JSR DRAWSTRING

        LDY #Y_player1+32
        LDX #DS_winner
        LDA PLAY1
        BNE EOG2
        INX
EOG2    TXA
        LDX #31
        JSR DRAWSTRING
        LDY #Y_player2+32
        LDX #DS_winner
        LDA PLAY2
        BNE EOG3
        INX
EOG3    TXA
        LDX #31
        JSR DRAWSTRING

* keypress and new game start

        STA $C010
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

* move the cursor [0,9], [0,9]
* clamp as needed

MOVECLAMP
        LDA THEKEY         ; try to move the cursor
        CMP #KEY_up
        BNE :k1
        DEC YP
        JMP CLAMP
:k1     CMP #KEY_down
        BNE :k2
        INC YP
        JMP CLAMP    
:k2     CMP #KEY_left
        BNE :k3
        DEC XP
        JMP CLAMP    
:k3     CMP #KEY_right
        BNE CLAMP
        INC XP
CLAMP   LDA XP             ; validate the cursor location
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
OK2     RTS

* Pieces: high order bit set = player 2 (right)
*
* 03=NE pointing gun
* 04=E pointing gun (04)
* 05=SE pointing gun
* 06=NW pointing gun
* 07=W pointing gun (87)
* 08=SW pointing gun
* 09=/
* 0A=\
* 0B=|
* 0C=--
* 0D=Block
* 0E=+\
* 0F=+/
* 10=\+
* 11=/+
* 12=T splitter
* 13=diagonal T splitter
* 14=Y splitter
* 15=diagonal Y splitter
* 16=light pipe bend right horiz
* 17=light pipe bend right vertical
* 18=light pipe bend left horiz
* 19=light pipe bend left vertical
* 1A=horiz up
* 1B=+|
* 1C=horiz down
* 1D=|+
* 1E=boundary
* 1F=blank boundary

* 3D=solid blocks (61)
* 3E=two squares (62)
* 3F=square (63)

*****************************
* Poll the keyboard and set THEKEY

KEY_up          = 1
KEY_down        = 2
KEY_left        = 3
KEY_right       = 4
KEY_redraw      = 5
KEY_sel         = 6
KEY_undo        = 7

CHECK_KEYS
        LDA #0
        STA THEKEY
        LDA $C000
        BMI :need
        RTS
:need   CMP #$81    ; ^A - abort game entirely
        BNE :snd
        STA $C010
        PLA  ; fix the stack
        PLA
        PLA
        PLA
        JMP GAME1 
:snd    CMP #$93    ; ^S - toggle sound
        BNE :color
        LDA SOUNDON
        EOR #1
        STA SOUNDON
        STA $C010
        RTS
:color  CMP #$83    ; ^C - toggle color mode
        BNE :done
        LDA COLORFLAG
        EOR #1
        STA COLORFLAG
        STA $C010
        LDA #KEY_redraw
        STA THEKEY
        RTS
:done   CMP #$91     ; ^Q - ProDOS BYE
        BEQ :bye
        CMP #$9B           ; ESC key
        BNE :space
        STA $C010
        LDA #KEY_undo
        STA THEKEY
        RTS
:space  CMP #$A0          ; space key
        BNE :arrows
        LDA #KEY_sel    
        BNE :akey
:arrows LDX #2
:aloop  CMP IKEYS,X
        BNE :trym
        LDA #KEY_up
        BNE :akey
:trym   CMP MKEYS,X
        BNE :tryj
        LDA #KEY_down
        BNE :akey
:tryj   CMP JKEYS,X
        BNE :tryk
        LDA #KEY_left
        BNE :akey 
:tryk   CMP KKEYS,X
        BNE :nextk
        LDA #KEY_right
        BNE :akey
:nextk  DEX
        BPL :aloop
        RTS                
:akey   STA THEKEY
        STA $C010
        RTS
:bye    JSR   $BF00
        HEX   65
        DA    BYEMLI
        RTS
BYEMLI  HEX   04000000000000

* Allow for upper and lowercase IJKM as well as the arrow keys

IKEYS   HEX   E9C98B
MKEYS   HEX   EDCD8A
JKEYS   HEX   EACA88
KKEYS   HEX   EBCB95

* The processed keystrroke (if any) 0=no keypress

THEKEY  DFB 0

**************************
* Turn state

XSEL    DFB 0
YSEL    DFB 0
ZSEL    DFB 0

******************************
* One player's turn...

ONEPLAYERTURN  
        LDY #101           ; Save off state (undo)
:loop   LDA BOARDBASE,Y
        STA BOARDSAVE,Y
        DEY
        BPL :loop
        JMP :setup

UNDO    LDY #101           ; Restore (undo) state
:uloop  LDA BOARDSAVE,Y
        STA BOARDBASE,Y
        DEY
        BPL :uloop

:setup  JSR DSCREEN
        LDA #4             ; Start the cursor @ 4,4
        STA XP
        STA YP
        JSR SELECT         ; advertise "<select>" mode

SELLOOP LDA #62
        JSR DRAWCUR
        JSR DELAY          ; time to see the cursor
        JSR DELAY
        JSR CHECK_KEYS
        LDA #62
        JSR DRAWCUR        ; erase cursor

* handle non-motion keystrokes

        LDA THEKEY
        CMP #KEY_redraw   ; redraw (^C)
        BNE :k0
        JSR DSCREEN
        JMP SELLOOP

:k0     CMP #KEY_sel      ; attempt to select (space)
        BEQ TRYSELECT
        JSR MOVECLAMP
INVSEL  JMP SELLOOP

TRYSELECT 
        JSR GETZ
        LDA Z
        AND #$80
        CMP PLAYER
        BNE INVSEL
        LDA Z
        AND #$7F
        CMP #3
        BLT INVSEL
        CMP #30
        BGE INVSEL

* switching to move mode

        LDA XP            ; valid selection
        STA XSEL
        LDA YP
        STA YSEL
        LDA Z
        STA ZSEL
        LDA #61           ; draw selection marker
        JSR DRAWCUR
        JSR PLACE         ; Change the mode text

* Pick a new location for the piece

MOVELOOP
        LDA #62
        JSR DRAWCUR
        JSR DELAY          ; time to see the cursor
        JSR DELAY
        JSR CHECK_KEYS
        LDA #62
        JSR DRAWCUR        ; erase cursor

* handle non-motion keystrokes

        LDA THEKEY
        CMP #KEY_redraw   ; redraw (^C)
        BNE :k0
        JSR DSCREEN
        JMP MOVELOOP
:k0     CMP #KEY_sel      ; attempt to place
        BEQ TRYMOVE
        CMP #KEY_undo      ; undo
        BNE :k1
        JMP UNDO
:k1     JSR MOVECLAMP
        JMP MOVELOOP

* check to see if the selected move target is valid

TRYMOVE
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
NO1     JMP MOVELOOP

* Complete the move and switch to rotate mode

MADEMOVE
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
        STA BOARDBASE,X    ; Place the piece
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
        JSR ROTATE        ; change the mode text to <rotate>

ROTATELOOP        
        JSR DRAWROT
        JSR DELAY
        JSR DELAY
        JSR CHECK_KEYS
        
* Handle the non-rotate keys

        LDA THEKEY
        CMP #KEY_redraw   ; redraw (^C)
        BNE :k0
        JSR DSCREEN
        JMP ROTATELOOP
:k0     CMP #KEY_sel      ; attempt to place
        BEQ ROTDONE
        CMP #KEY_undo      ; undo
        BNE :k1
        JMP UNDO
:k1     CMP #KEY_right
        BEQ NEWROTATE
        CMP #KEY_down
        BEQ NEWROTATE
        CMP #KEY_up
        BEQ NEWROTATE
        CMP #KEY_left
        BEQ NEWROTATE
        JMP ROTATELOOP

NEWROTATE        
        LDY ZSEL
        LDA ROTTBL,Y
        STA ZSEL ; new piece is the result of rotating the current piece
        JMP ROTATELOOP

ROTDONE LDX Z
        LDA ZSEL
        ORA PLAYER
        STA BOARDBASE,X
        JSR DSCREEN

* We might be firing...

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

* draw the current selected square

DRAWROT LDA XP
        STA 0
        LDA YP
        STA 1
        LDA ZSEL
        STA 2
        LDA #1
        STA 4
        STA 5
        JSR LASER
        RTS

ROTTBL  DFB 0,0,0,4,5,3,7,8,6,10,9,12,11,13,15,16,17,14
        DFB 19,18,21,20,23,22,25,24,27,28,29,26,30


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
        CMP #$1F
        BEQ TM5
TM11    SEC
        RTS

PLAYERBLOCKS
        JSR RECOUNT

        LDA PLAY1
        ORA #$30
        STA BLOCKS
        LDY #Y_player1+16
        LDX #31
        LDA #DS_blocks
        JSR DRAWSTRING

        LDA PLAY2
        ORA #$30
        STA BLOCKS
        LDY #Y_player2+16
        LDX #31
        LDA #DS_blocks
        JSR DRAWSTRING
        RTS

* The X register is the starting column [0-39]
* The Y regiester is the starting row (pixels) [0-191]
* The A register is the string number DS_*

* 00 = end of string
* 0A = new line (y=y+8, x=xstart)
* 01 = advance cursor, no draw

DS_X    = $19 ; current column
DS_Y    = $1A ; current row in pixels
DS_XS   = $1B ; column start (return to with 'nl')
DS_TMPY = $1C ; pixel row for current byte
DS_CNT  = $1D ; number of rows to draw

DRAWSTRING_LOCAL
        STX DS_X
        STX DS_XS
        ASL
        TAX  ; convert A to text address
        LDA DS_TABLE,X
        STA NEXTCHR+1
        INX
        LDA DS_TABLE,X
        STA NEXTCHR+2
        STY DS_Y

NEXTCHR LDA $FFFF  ; get the next character in the string
        INC NEXTCHR+1
        BNE :isnull
        INC NEXTCHR+2
:isnull CMP #0
        BNE :dochar
        RTS
:dochar CMP #1
        BEQ :cdone
        CMP #10    ; newline character
        BNE :drawit

        LDA DS_XS   ; Handle newline: reset X and add 8 to Y
        STA DS_X
        LDA DS_Y
        CLC
        ADC #8
        STA DS_Y
        JMP NEXTCHR

* FONT is at 6C00 we need to multiply char by 8
* and add to 6C00.  Divide 6C00 by 8 to get 0D80
* so we OR 0D80 with the char and shift the addr

:drawit ORA #$80
        STA FNTBYTE+1
        LDA #$0D    ; high order byte of FONTBASE shifted right 3 bits
        STA FNTBYTE+2

        ASL FNTBYTE+1 ; multiply 16 bit font address by 8
        ROL FNTBYTE+2
        ASL FNTBYTE+1
        ROL FNTBYTE+2
        ASL FNTBYTE+1
        ROL FNTBYTE+2  

        LDX DS_Y    ; reset the Y address
        STX DS_TMPY
        LDA #8
        STA DS_CNT  ; how many bytes to render

:byte1  LDX DS_TMPY
        JSR CALC
FNTBYTE LDA $FFFF
        INC FNTBYTE+1
        BNE :lclinc
        INC FNTBYTE+2
:lclinc LDY DS_X
        STA ($26),Y
        INC DS_TMPY ; next scanline
        DEC DS_CNT
        BNE :byte1
:cdone  INC DS_X    ; next column
        JMP NEXTCHR

DS_TABLE
        DA DS_S_deflect
        DA DS_S_cright
        DA DS_S_player1     
        DA DS_S_player2     
        DA DS_S_blocks     
        DA DS_S_select      
        DA DS_S_rotate
        DA DS_S_place     
        DA DS_S_gameover    
        DA DS_S_winner    
        DA DS_S_loser 
        DA DS_S_blank
        DA DS_S_box
        DA DS_S_unbox
        DA DS_S_help

DS_S_deflect
        ASC 'Deflection ('
        PUT VERSION.S
        ASC ')'
        HEX 00
DS_S_cright
        ASC 'Copyright ',$13,' 1987',$0A
        ASC '  Randy Frank'
        HEX 00
DS_S_player1
        ASC 'L Player'
        HEX 00
DS_S_player2
        ASC 'R Player '
        HEX 00
DS_S_blocks
        ASC 'Blocks:0'
        HEX 00
BLOCKS   = DS_S_blocks+7
DS_S_select
        ASC '<Select>'
        HEX 00
DS_S_rotate
        ASC '<Rotate>'
        HEX 00
DS_S_place
        ASC '<Place> '
        HEX 00
DS_S_gameover
        ASC 'Game Over '
        HEX 00
DS_S_winner
        ASC ' Winner '
        HEX 00
DS_S_loser        
        ASC ' Loser  '
        HEX 00
DS_S_blank
        ASC '        '
        HEX 00
DS_S_box
        HEX 141818181818181818150A
        HEX 190101010101010101190A
        HEX 190101010101010101190A
        HEX 190101010101010101190A
        HEX 190101010101010101190A
        HEX 161818181818181818170A
        HEX 00
DS_S_unbox
        HEX 202020202020202020200A
        HEX 200101010101010101200A
        HEX 200101010101010101200A
        HEX 200101010101010101200A
        HEX 200101010101010101200A
        HEX 202020202020202020200A
        HEX 00
DS_S_help
        ASC 'IJKM: Move',$0A
        ASC 'spc:Select',$0A
        ASC 'esc: Undo', $0A
        ASC '^S: Sound', $0A
        ASC '^C: Color', $0A
        ASC '^A: Abort', $0A
        ASC '^Q: Quit',  $00


* Sound in the X register [0,15]
* Routine from:
*  Assembly Cookbook for the Apple II/IIe (Don Lancaster)
*  Chapter 4: Obnoxious Sounds

SOUNDON DFB 1    ; is sound enabled or not

PLAYSOUND_LOCAL    
        PHP 
        PHA 
        TYA 
        PHA
        LDY SOUNDON
        CPY #0
        BEQ EXIT4
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

RANDOM_SETUP_LOCAL 
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

RANDOM_LOCAL
        ROR R4           ; Bit 25 to carry
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
