        ORG   $2000
        DSK   ../bin/LOADER#062000
        TYP   $06  ; /BIN file

* This is the DEFLECT.SYSTEM loader
* It is a packed version of the game
* that starts execution @ $2000, unpacks
* the various bits and then starts the 
* game.  See: STARTUP.abas for what this
* file actually does.

SRCLO    =     0
SRCHI    =     1
TGTLO    =     2
TGTHI    =     3

* // LINK - ../memorymap.txt#loader

* Low order addresses
        LDA   #$00
        STA   SRCLO
        STA   TGTLO

* Read from 2400-5B00 and store to 6000-9700         
        LDA   #$24
        STA   SRCHI
        LDA   #$60
        STA   TGTHI
        LDX   #$37
        JSR   MOVEMEM

* Start the game                           
        JMP   $6000

MOVEMEM LDY   #$00
MOVLOOP LDA   (SRCLO),Y
        STA   (TGTLO),Y
        DEY
        BNE   MOVLOOP
        INC   TGTHI
        INC   SRCHI
        DEX
        BNE   MOVEMEM
        RTS
