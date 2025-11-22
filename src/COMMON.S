
* Tables from GFXTABLES
HIGH = $9500
LO = $9400
DIRBASE = $9300

* Tables from TBLD
DXTBL = $7E00
DYTBL = $7F00

* from GUNCODE.S1
RAY = $7B00

* from LASER.S
* dispatch table at start of unit
LASER = $9000
CUT = $9003         ; was $9100
DSCREEN = $9006     ; was $90FD (page)
COLORFLAG = $9009   ; was $90FC 

* Kind of from START.S
BOARDBASE = $9200
BOARDSAVE = BOARDBASE+128

* Apple II ROM/addresses
HPLOT = $F45A
HPOSN = $F411
HCOLOR = $F6F0
BUTTON0 = $C061
BUTTON1 = $C062
SPKR = $C030 
WAIT = $FCA8