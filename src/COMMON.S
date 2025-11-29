
* Common address/values

* Tables from GFXTABLES
HIGH        = $9500  ; HGR1 scanline high order addresses
LO          = $9400  ; HGR1 scanline low order addresses
DIRBASE     = $9300

* Font ($400 bytes)
FONTBASE    = $6800

* Tables from TBLD
DXTBL       = $7E00
DYTBL       = $7F00

* from GUNCODE.S1
RAY         = $7000

* from LASER.S
* dispatch table at start of unit
LASER       = $9000
CUT         = $9003   ; was $9100
DSCREEN     = $9006   ; was $90FD (page)
COLORFLAG   = $9009   ; was $90FC 

* Kind of from START.S
BOARDBASE   = $9200
BOARDSAVE   = BOARDBASE+128 ; used to undo a move
STARTSAVE   = $7D00       ; used to start a new game

* Icons from LASER.SHAPES
ICONBASE    = $8000
ICON_DX     =  21         ; 21 pixels wide (3 bytes)
ICON_DY     =  19         ; 19 pixels high (10 tiles = 190 pixels total)
ICON_XBYTES =  3
ICON_BYTES  =  64         ; stored as 64 bytes/icon (57 used)

* Apple II ROM/addresses
HPLOTN      = $F457       ; A=Ypos, X=XposLO, Y=XposHI (calls HPOSN then HPLOT)
HLINE       = $F53A

HPLOT       = $F45A       ; Must call HPOSN first
HPOSN       = $F411       ; A=Ypos, X=XposLO, Y=XposHI (E0-E2)
HCOLOR      = $F6F0       ; X=COLOR
BUTTON0     = $C061
BUTTON1     = $C062
SPKR        = $C030 
WAIT        = $FCA8

* Sounds
SOUNDON         = $600F   ; flag 1 is sound is enabled
PLAYSOUND       = $6003   ; sound to play in X register
SOUND_Drip      = 0
SOUND_Whoop     = 1
SOUND_Pip       = 2
SOUND_Phasor    = 3
SOUND_Scale     = 4
SOUND_S_beep    = 5
SOUND_M_beep    = 6
SOUND_L_beep    = 7
SOUND_Geiger    = 8
SOUND_Gleep     = 9
SOUND_Whooping  = 10
SOUND_Qwip      = 11
SOUND_Laser     = 12
SOUND_Fail      = 13
SOUND_Pass      = 14
SOUND_Timebomb  = 15

* Random number generator
RANDOM_SETUP    = $6006  ; Must be called first
RANDOM          = $6009  ; random byte returned in A

* Draw text: X=column [0-39], Y=row [0-191], A=string number
DRAWSTRING      = $600C
DS_deflection   = 0
DS_copyright    = 1
DS_player1      = 2
DS_player2      = 3
DS_blocks       = 4
DS_select       = 5
DS_rotate       = 6
DS_place        = 7
DS_gameover     = 8
DS_winner       = 9
DS_loser        = 10
DS_blank        = 11
DS_box          = 12
DS_unbox        = 13
DS_help         = 14

* placement vertically of user info boxes
Y_player1       = 24
Y_player2       = 80
