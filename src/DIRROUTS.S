         ORG   $9600
         DSK   ../bin/DIRROUTS#069600
         TYP   $06        ; /BIN file

* This file is designed to be included into another source file
* It provides the basic "select file/directory" operations
* The prefix is set properly on return and any selected filename
* can be found at $0280...

HOME     =     $FC58      ; Clear screen, move cursor to 0,0
MOUSEFNT =     $C00F      ; Enable mouse text font

TEXTMODE =     $C051
GFXMODE  =     $C050

MLI      =     $BF00

TPTR     =     $FC         ; FC,FD
TMP0     =     0
TMP1     =     1

* Basic interface on call:
*
* $280: proposed filename length (0) is none
* $281: proposed filename (up to 15 chars)
* $290: 1=save file, 0=read file
* Directory prefix is the starting point

* On return:
*
* $280: filename length
* $281: filename (up to 15 chars)
* $290: status 0=ok, 1=cancel
* Directory prefix will have been set on ok

* Code length: ~ $0700 ($4300 - $49ff)
*
* Buffers: 
*
*   TMPBUFFER  - $4A00 - $0100
*   FILEBUFFER - $4B00 - $0400
*   NAMETYPE   - $4F00 - $0100 (filetypes) 
*   NAMELIST   - $5000 - $1000 (256x16 byte filenames)
*
* $4300 - $5fff

* API addresses
RETLEN   =     $280
RETNAME  =     $281
RETSTATUS =    $290

* general buffers
TMPBUFFER =    $4A00      ; for i/o operations buffering
FILEBUFFER =   $4B00      ; $400 (1024) bytes for ProDOS fil buffer

* space for 256 filenames
NAMETYPE =     $4F00      ; 256 bytes for the corresponding file type
NAMELIST =     $5000      ; $1000 (4096) bytes for 256x16 filenames

* TAB switches between modes

PR_MODE_LIST =     0
PR_MODE_NAME =     1
PR_MODE_OK =       2
PR_MODE_CANCEL =   3

* Interaction logic

         JSR   HOME
         STA   TEXTMODE
         LDA   RETSTATUS
         STA   PR_SAVE
         LDY   RETLEN
         LDA   #0
         STA   RETNAME,Y  ; zero terminate the filename
         JSR   GETPREFIX
         JSR   READFILES
         LDA   #PR_MODE_LIST
         STA   PR_MODE
         JSR   DRAWSCREEN
WORKING
         LDA   $C000
         BPL   WORKING
         STA   $C010
         LDY   PR_MODE
         CMP   #137       ; TAB character
         BNE   :doit
         LDX   PR_SAVE    ; handle a mode change
         CPX   #1
         BEQ   :save
         CPY   #PR_MODE_LIST ; in load mode, skip NAME field
         BNE   :save
         INY              ; skip the NAME slot if loading (vs saving)
:save    INY
         TYA
         AND   #3
         STA   PR_MODE
         JSR   DRAWSCREEN
         JMP   WORKING

:doit    CPY   #PR_MODE_NAME ; handle keystroke other than tab
         BNE   :trylist
         JMP   :name_mode

:trylist CPY   #PR_MODE_LIST
         BNE   :tryret
         JMP   :list_mode
                          ; handle PR_MODE_OK and PR_MODE_CANCEL
:tryret  CMP   #141       ; return character
         BNE   WORKING
         CPY   #PR_MODE_OK
         BNE   :cancel
         LDA   RETLEN     ; empty target filename
         BEQ   WORKING
         LDA   PREFIX     ; unset prefix
         CMP   #2
         BLT   WORKING
:cancel  DEY
         DEY
         STY   RETSTATUS
         JMP   RESTORE


:list_mode                  ; handle list manipulation
         CMP   #141       ; return character
         BEQ   :doret
         CMP   #155       ; ESC character
         BEQ   :doesc
         CMP   #139       ; up character
         BEQ   :minus
         CMP   #138       ; down character
         BEQ   :plus
         CMP   #149       ; right character
         BEQ   :plus
         CMP   #136       ; left character
         BEQ   :minus
         JMP   WORKING

:plus    LDY   PR_NAMETOP
         INY
         CPY   PR_NAMECOUNT
         BLT   :newtop
         BGE   WORKING

:minus   LDY   PR_NAMETOP
         CPY   #0
         BEQ   WORKING
         DEY

:newtop  STY   PR_NAMETOP
         JSR   DRAWFILES
         JSR   DRAWMODE
:bye     JMP   WORKING

:doesc   LDY   PREFIX
         CPY   #1
         BEQ   :bye
         DEY              ; skip the trailing '/'
:loop    LDA   PREFIX,Y
         CMP   #$2F       ; slash
         BEQ   :found
         DEY
         BNE   :loop
:found   STY   PREFIX
         LDA   #0
         STA   PFXBUF,Y
         JMP   :newpfx

:doret   LDY   PR_NAMETOP
         TYA              ; (TMP0) is the filename
         LSR              ; high order bits become low order bits in the high byte
         LSR              ; basically the upper part of a 16bit x16 operation
         LSR
         LSR
         ORA   #>NAMELIST
         STA   TMP1
         TYA              ; map lower 4 bits to high bits (multi by 16)
         ASL
         ASL
         ASL
         ASL
         STA   TMP0
         LDA   NAMETYPE,Y ; check the type
         CMP   #$0F
         BEQ   :isdir

         LDY   #0         ; ret on a filename copies it to the RETNAME field
:next    LDA   (TMP0),Y
         BEQ   :endstr
         STA   RETNAME,Y
         INY
         BNE   :next
:endstr  STY   RETLEN
         LDA   #0
         STA   RETNAME,Y
         JSR   DRAWNAME
         JMP   WORKING

:isdir   LDY   #0         ; ret on a directory name changes the prefix
         LDX   PREFIX
:another LDA   (TMP0),Y
         BEQ   :send
         STA   PFXBUF,X
         INX
         INY
         JMP   :another
:send    LDA   #$2F
         STA   PFXBUF,X
         LDA   #0
         INX
         STA   PFXBUF,X
         STX   PREFIX
:newpfx  JSR   SETPREFIX
         JSR   READFILES
         JSR   DRAWSCREEN
         JMP   WORKING

:name_mode                  ; Handle filename edit
         LDY   RETLEN
         CMP   #136       ; left (BS) character
         BEQ   :del
         CMP   #255       ; del character
         BEQ   :del

         CPY   #15        ; ok to append character?
         BGE   :done2

* legal chars: [A-Z],[a,z],[0-9],'.'
         AND   #$7F
         CMP   #$2E       ; '.'
         BEQ   :append
         CMP   #$30       ; '0'
         BLT   :done
         CMP   #$3A       ; ':'
         BLT   :append
         CMP   #$41       ; 'A'
         BLT   :done
         CMP   #$5B       ; '['
         BLT   :append
         CMP   #$61       ; 'a'
         BLT   :done
         CMP   #$7B       ; '{'
         BGE   :done
         AND   #$DF       ; lowercase -> uppercase  $61,$7B

:append  STA   RETNAME,Y
         INY
         JMP   :done

:del     CPY   #0
         BEQ   :done
         DEY

:done    LDA   #0
         STA   RETNAME,Y
         STY   RETLEN
:done2   JSR   DRAWNAME
         JMP   WORKING

RESTORE
         STA   GFXMODE
         RTS

PR_XPOS  DFB   0
PR_YPOS  DFB   0
PR_XROOT DFB   0
PR_WRAP  DFB   40         ; if XPOS >= WRAP, then NL
PR_SAVE  DFB   0
PR_MASK  DFB   0
PR_NAMECOUNT DFB   0
PR_NAMETOP DFB   0
PR_MODE  DFB   PR_MODE_LIST
PR_ORIG_DISP_MODE DFB 0

PR_INIT  STA   MOUSEFNT
         LDA   #40
                          ; Fall though to set the wrap to 40

PR_SET_WRAP                  ; wrap column number in A
         STA   PR_WRAP
         RTS

PR_SET_POS                  ; position in X,Y [0,39][0,23]
         STX   PR_XPOS
         STX   PR_XROOT
         STY   PR_YPOS
                          ; Fall though to set the position

PR_REPOS                  ; sets up TPTR from PR_YPOS, destroys A,Y
         LDY   PR_YPOS
         LDA   TEXTTAB_HI,Y
         STA   TPTR+1
         LDA   TEXTTAB_LO,Y
         STA   TPTR+0
         RTS

PR_OUTCHAR                  ; char in A, assumes PR_REPOS has been called, destroys A,Y
         CMP   #0         ; null terminated
         BEQ   :done
         CMP   #10        ; newline
         BNE   :output
:newline LDY   PR_XPOS
         LDA   #$A0       ; space
:clrline STA   (TPTR),Y   ; fill out the line to the wrap point
         INY
         CPY   PR_WRAP
         BLT   :clrline
         LDA   PR_XROOT   ; \n repositions on the next line
         STA   PR_XPOS
         INC   PR_YPOS
         JMP   PR_REPOS
:output  LDY   PR_XPOS
         ORA   PR_MASK
         STA   (TPTR),Y
         INY
         CPY   PR_WRAP
         BGE   :newline
         STY   PR_XPOS
:done    RTS

PR_OUTSTR                  ; address of string in Y(hi), A(lo), destroys A,Y
         STY   SRC+2
         STA   SRC+1
SRC      LDA   $FFFF
         BEQ   :endstr
         JSR   PR_OUTCHAR
         INC   SRC+1
         BNE   SRC
         INC   SRC+2
         BNE   SRC
:endstr  RTS

TEXTTAB_HI
         HEX   0404050506060707
         HEX   0404050506060707
         HEX   0404050506060707

TEXTTAB_LO
         HEX   0080008000800080
         HEX   28A828A828A828A8
         HEX   50D050D050D050D0

DRAWSCREEN
         JSR   HOME
         JSR   PR_INIT
         LDX   #0
         LDY   #0
         JSR   PR_SET_POS
         LDY   #>LOADTITLE
         LDA   #<LOADTITLE
         LDX   PR_SAVE
         BEQ   :title
         LDY   #>SAVETITLE
         LDA   #<SAVETITLE
:title   JSR   PR_OUTSTR
         LDX   #0
         LDY   #2
         JSR   PR_SET_POS
         LDY   #>PREFIXTXT
         LDA   #<PREFIXTXT
         JSR   PR_OUTSTR
         LDX   #0
         LDY   #6
         JSR   PR_SET_POS
         LDY   #>FILELISTTXT
         LDA   #<FILELISTTXT
         JSR   PR_OUTSTR
         LDX   #0
         LDY   #18
         JSR   PR_SET_POS
         LDY   #>FILENAMETXT
         LDA   #<FILENAMETXT
         JSR   PR_OUTSTR
         LDX   #0
         LDY   #21
         JSR   PR_SET_POS
         LDY   #>OKTXT
         LDA   #<OKTXT
         JSR   PR_OUTSTR
         LDX   #10
         STX   PR_XPOS
         LDY   #>CANCELTXT
         LDA   #<CANCELTXT
         JSR   PR_OUTSTR
         JSR   DRAWPREFIX
         JSR   DRAWFILES
         JSR   DRAWNAME
         LDX   #5
         LDY   #23
         JSR   PR_SET_POS
         LDY   #>TABTXT
         LDA   #<TABTXT
         JSR   PR_OUTSTR
         JMP   DRAWMODE

DRAWMODE
         LDX   PR_MODE
         LDA   SELTABY,X
         STA   PR_YPOS
         JSR   PR_REPOS
         LDA   SELTABX1,X
         TAY
         LDA   #$DB
         STA   (TPTR),Y
         LDA   SELTABX2,X
         TAY
         LDA   #$DD
         STA   (TPTR),Y
         RTS

SELTABY  DFB   12,19,21,21
SELTABX1 DFB   0,  0, 0,10
SELTABX2 DFB   18,18, 7,17

DRAWNAME
         LDA   #$80
         STA   PR_MASK
         LDX   #1
         LDY   #19
         JSR   PR_SET_POS
         LDY   #>RETNAME
         LDA   #<RETNAME
         JSR   PR_OUTSTR
         LDA   #$00
         STA   PR_MASK
         LDA   PR_MODE
         CMP   #PR_MODE_NAME
         BNE   :nocurs
         LDA   #$DF
         JSR   PR_OUTCHAR
:nocurs  LDA   #$A0
         JSR   PR_OUTCHAR
         LDA   PR_XPOS
         CMP   #16
         BLT   :nocurs
         LDX   #10
         LDY   #18
         JSR   PR_SET_POS
         LDA   RETLEN
         BNE   :nameok
         LDY   #>INVALIDTXT
         LDA   #<INVALIDTXT
         JMP   PR_OUTSTR
:nameok  LDA   #10
         JMP   PR_OUTCHAR

INVALIDTXT ASC "(invalid)"
         HEX   0A00

DRAWPREFIX
         LDX   #1
         LDY   #3
         JSR   PR_SET_POS
         LDA   #$80
         STA   PR_MASK
         LDY   #>PFXBUF
         LDA   #<PFXBUF
         JSR   PR_OUTSTR
         LDA   #$A0
         JSR   PR_OUTCHAR
         LDA   #$00
         STA   PR_MASK
         LDX   #16
         LDY   #2
         JSR   PR_SET_POS
         LDA   PREFIX
         CMP   #2
         BGE   :dirok
         LDY   #>INVALIDTXT
         LDA   #<INVALIDTXT
         JMP   PR_OUTSTR
:dirok   LDA   #10
         JMP   PR_OUTCHAR
         RTS

DRAWFILES                  ; 9 filenames starting at line 8
         LDA   #$80
         STA   PR_MASK
         LDX   #1
         LDY   #8
         JSR   PR_SET_POS
         LDA   #9
         STA   TMP0       ; number of slots to render
         SEC
         LDA   PR_NAMETOP
         SBC   #4
         STA   TMP1       ; this is the file to render (note, could be negative)
:top     LDA   TMP1
         BMI   :empty
         CMP   PR_NAMECOUNT
         BGE   :empty
         LSR              ; high order bits become low order bits in the high byte
         LSR              ; basically the upper part of a 16bit x16 operation
         LSR
         LSR
         ORA   #>NAMELIST
         TAY
         LDA   TMP1       ; map lower 4 bits to high bits (multi by 16)
         ASL
         ASL
         ASL
         ASL
         JSR   PR_OUTSTR
:spaces  LDA   #$A0
         JSR   PR_OUTCHAR
         LDA   PR_XPOS
         CMP   #20
         BNE   :spaces
         LDX   TMP1
         LDA   NAMETYPE,X
         JSR   DRAWTYPE
:empty
         LDA   #10        ; newline
         JSR   PR_OUTCHAR
         INC   TMP1
         DEC   TMP0
         BNE   :top
         LDA   #$00
         STA   PR_MASK
         RTS

DRAWTYPE                  ; some hard coded type:  SYS, DIR, BAS, BIN, TXT
         LDX   #4
         CMP   #$FF       ; SYS
         BEQ   :render
         LDX   #8
         CMP   #$0F       ; DIR
         BEQ   :render
         LDX   #12
         CMP   #$FC       ; BAS
         BEQ   :render
         LDX   #16
         CMP   #$06       ; BIN
         BEQ   :render
         LDX   #20
         CMP   #$04       ; TXT
         BEQ   :render
         PHA
         AND   #$0f
         ORA   #$B0
         STA   TYPETXT+2
         PLA
         LSR
         LSR
         LSR
         LSR
         ORA   #$B0
         STA   TYPETXT+1
         LDX   #0
:render  LDA   TYPETXT,X
         BEQ   :done
         JSR   PR_OUTCHAR
         INX
         BNE   :render
:done    RTS


TYPETXT  ASC   "$XX"
         HEX   00
         ASC   "SYS"
         HEX   00
         ASC   "DIR"
         HEX   00
         ASC   "BAS"
         HEX   00
         ASC   "BIN"
         HEX   00
         ASC   "TXT"
         HEX   00

READFILES
         LDA   #>NAMELIST
         STA   TPTR+1
         LDA   #<NAMELIST
         STA   TPTR+0
         LDA   #0
         STA   PR_NAMECOUNT
         STA   PR_NAMETOP
         LDA   PREFIX
         CMP   #2
         BGE   :readdir
         JMP   ONLINE
:readdir JMP   DOCATALOG

LOADTITLE
         ASC   "Select Deflection state file to load"
         HEX   00
SAVETITLE
         ASC   "Select file to save Deflection state"
         HEX   00

PREFIXTXT
         ASC   "Current prefix:"
         HEX   00

FILELISTTXT
         ASC   "Files ("
         HEX   4D
         ASC   "=select,esc=up,"
         HEX   484A554B
         ASC   "=pick):"
         HEX   00

FILENAMETXT
         ASC   "Filename:"
         HEX   00

OKTXT
         ASC   "<  OK  >"
         HEX   00

CANCELTXT
         ASC   "<Cancel>"
         HEX   00

TABTXT
         ASC   "(tab=change focus,"
         HEX   4D
         ASC   "=select)"
         HEX   00

SETPREFIX
         JSR   MLI
         HEX   C6
         DA    PPARAMS
         RTS

GETPREFIX
         JSR   MLI
         HEX   C7
         DA    PPARAMS
         BCS   :invalid
         LDA   PREFIX     ; zero length prefix is mapped to '/'
         BNE   :valid
:invalid LDA   #1
         STA   PREFIX
         LDA   #$2F
         STA   PFXBUF
:valid   LDY   PREFIX     ; null terminate the prefix
         LDA   #0
         STA   PFXBUF,Y
         RTS
PPARAMS  HEX   01
         DA    PREFIX
PREFIX   DFB   0
PFXBUF   DS    63

ONLINE   JSR   MLI
         HEX   C5
         DA    DEVICES
         LDA   #0
         STA   TMP0
:next    LDA   TMP0
         ASL
         ASL
         ASL
         ASL
         TAY
         LDA   TMPBUFFER,Y
         BEQ   :done
         AND   #$0F
         STA   TMP1
         LDX   PR_NAMECOUNT
         LDA   #$0F       ; DIR type
         STA   NAMETYPE,X
         TXA
         ASL
         ASL
         ASL
         ASL
         TAX
:loop    INY
         LDA   TMPBUFFER,Y
         STA   NAMELIST,X
         INX
         DEC   TMP1
         BNE   :loop
         LDA   #0
         STA   NAMELIST,X
         INC   PR_NAMECOUNT
         INC   TMP0
         JMP   :next
:done    RTS
DEVICES  DFB   2
         DFB   0
         DA    TMPBUFFER

* directory file structure
* 4 byte header
* 13 entries of $27 bytes
* 1 byte tailer

DOCATALOG
         JSR   OPENPRE
         LDA   #4
         JSR   READN
         BCS   :eoc
:page    LDA   #13
         STA   TMP0
:entry   LDA   #$27
         JSR   READN
         BCS   :eoc
         LDA   TMPBUFFER
         AND   #$F0
         BEQ   :skip      ; zero is an "unused" entry, F0 and E0 are header entries
         CMP   #$F0
         BEQ   :skip
         CMP   #$E0
         BEQ   :skip
         LDX   PR_NAMECOUNT
         LDA   TMPBUFFER+16 ; file type $0f=dir
         STA   NAMETYPE,X
         LDA   TMPBUFFER
         AND   #$0F       ; length of name
         STA   TMP1       ; for looping over the number of chars in the name
         LDY   #0         ; name starts at TMPBUFFER+1
:loop    LDA   TMPBUFFER+1,Y
         LDX   #0
         STA   (TPTR,X)   ; TPTR is a pointer into NAMELIST
         INC   TPTR+0
         BNE   :low
         INC   TPTR+1
:low     INY
         DEC   TMP1
         BNE   :loop
         LDX   #0         ; pad out the name with zeros
         LDA   #0
:zero    STA   (TPTR,X)
         INC   TPTR+0
         BNE   :low2
         INC   TPTR+1
:low2    INY
         CPY   #$10
         BNE   :zero
         INC   PR_NAMECOUNT
:skip    DEC   TMP0
         BNE   :entry     ; next entry in this page

         LDA   #5         ; start a new page by reading the trailer + next header
         JSR   READN
         BCC   :page

:eoc     JSR   CFILE
         RTS

READN    STA   DLEN       ; read N bytes from open file
         LDA   #0
         STA   DLEN+1
         STA   DBUFF
         LDA   #>TMPBUFFER
         STA   DBUFF+1
         JSR   MLI
         HEX   CA
         DA    RPDOS
         RTS
RPDOS    HEX   0401
DBUFF    DA    $0000
DLEN     DA    $0000
         HEX   0000

OPENPRE  JSR   MLI        ; open prefix as a file
         HEX   C8
         DA    OPPRE
         RTS
OPPRE    HEX   03
         DA    PREFIX
         DA    FILEBUFFER
         HEX   01

CFILE    JSR   MLI        ; close the file
         HEX   CC
         DA    CPDOS
         RTS
CPDOS    HEX   0101


* Unused at the moment, but it allows for HGR display

* FONT is at 6C00 we need to multiply char by 8
* and add to 6C00.  Divide 6C00 by 8 to get 0D80
* so we OR 0D80 with the char and shift the addr

DS_TMPY  dfb   0
DS_CNT   dfb   0
GFX_HI_TABLE = $9500  ; HGR1 scanline high order addresses
GFX_LO_TABLE = $9400  ; HGR1 scanline low order addresses
GFX_LO   =     $FA
GFX_HI   =     $FB

DRAWCHAR 
        ORA #$80
        STA FNTBYTE+1
        LDA #$0D    ; high order byte of FONTBASE shifted right 3 bits
        STA FNTBYTE+2

        ASL FNTBYTE+1 ; multiply 16 bit font address by 8
        ROL FNTBYTE+2
        ASL FNTBYTE+1
        ROL FNTBYTE+2
        ASL FNTBYTE+1
        ROL FNTBYTE+2  

        LDX PR_YPOS    ; reset the Y address
        STX DS_TMPY
        LDA #8
        STA DS_CNT  ; how many bytes to render

NEXTY   LDX DS_TMPY
        LDA GFX_LO_TABLE,X    
        STA GFX_LO
        LDA GFX_HI_TABLE,X
        STA GFX_HI
FNTBYTE LDA $FFFF
        INC FNTBYTE+1
        BNE SKIPHI
        INC FNTBYTE+2
SKIPHI  LDY PR_XPOS
        STA (GFX_LO),Y
        INC DS_TMPY ; next scanline
        DEC DS_CNT
        BNE NEXTY
        RTS
