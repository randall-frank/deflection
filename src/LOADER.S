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

* Read from 2100-5F00 and store to 6000-9E00         
        LDA   #$21
        STA   SRCHI
        LDA   #$60
        STA   TGTHI
        LDX   #$3E
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
