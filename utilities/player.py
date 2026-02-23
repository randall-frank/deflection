import copy
import sys
from enum import IntEnum
from typing import Tuple


class Color:
    PURPLE = '\033[95m'
    CYAN = '\033[96m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    REVERSE = '\033[7m'
    NORMAL = '\033[0m'


class Rotate(IntEnum):
    # For other Pieces
    CW_0 = 0
    CW_90 = 1
    CW_180 = 2
    CW_270 = 3
    # For LASERS
    L_CW_45 = 4
    L_CW_90 = 5
    L_CCW_45 = 6
    L_CCW_90 = 7


class Direction(IntEnum):
    DD = -1   # Dead
    N  = 0
    NE = 1
    E  = 2
    SE = 3
    S  = 4
    SW = 5
    W  = 6
    NW = 7


def delta(direction: int) -> Tuple[int, int]:
    _deltas = [
        ( 0, -1),  # N
        ( 1, -1),  # NE
        ( 1,  0),  # E
        ( 1,  1),  # SE
        ( 0,  1),  # S
        (-1,  1),  # SW
        (-1,  0),  # W
        (-1, -1)   # NW
    ]
    idx = direction % 8
    return _deltas[idx]


class Piece(IntEnum):
    ILLEGAL = -1
    EMPTY = 0
    LASER_NE = 3
    LASER_E = 4
    LASER_SE = 5
    LASER_NW = 6
    LASER_W = 7
    LASER_SW = 8
    REFL_NW_SE = 9
    REFL_NE_SW = 10
    REFL_E_W = 11
    REFL_N_S = 12
    TARGET = 13
    HALF_NE = 14
    HALF_SE = 15
    HALF_SW = 16
    HALF_NW = 17
    SPLIT_90_NSEW = 18
    SPLIT_90_DIAG = 19
    SPLIT_45_NSEW = 20
    SPLIT_45_DIAG = 21
    GUIDE_N_NE = 22
    GUIDE_E_SE = 23
    GUIDE_N_NW = 24
    GUIDE_E_NE = 25
    HALF_N = 26
    HALF_E = 27
    HALF_S = 28
    HALF_W = 29


def clamp(value, minimum, maximum):
    return max(minimum, min(value, maximum))


class Board:
    def __init__(self):
        self._dir_map = {}
        # Bit of a hack to initialize the direction map with the correct piece and
        # direction enums without having to use the long class names
        p = Piece
        d = Direction
        m = self._dir_map
        # For each 8 input direction, what is the output direction
        # d.DEAD if the ray destroys the piece and does not continue.
        # The input directions are: N, NE, E, SE, S, SW, W, NW in order of the Direction enum.
        m[p.EMPTY] = [d.N , d.NE, d.E , d.SE, d.S , d.SW, d.W , d.NW]   # pass-thru case, no changes

        # Reflector pieces... For each input direction, what is the output direction after hitting that piece.
        m[p.REFL_NW_SE] = [d.E , d.DD, d.N , d.NW, d.W , d.DD, d.S , d.SE]
        m[p.REFL_NE_SW] = [d.W , d.SW, d.S , d.DD, d.E , d.NE, d.N , d.DD]
        m[p.REFL_E_W] = [d.DD, d.NW, d.W , d.SW, d.DD, d.SE, d.E , d.NE]
        m[p.REFL_N_S] = [d.S , d.SE, d.DD, d.NE, d.N , d.NW, d.DD, d.SW]

        # target is destroyed and does not reflect
        m[p.TARGET] = [d.DD, d.DD, d.DD, d.DD, d.DD, d.DD, d.DD, d.DD]

        # Diagonal half pieces. Similar to reflectors but they destroy the piece if it hits the non-reflecting side.
        m[p.HALF_SW] = [d.DD, d.DD, d.N , d.DD, d.E , d.NE, d.N , d.DD]
        m[p.HALF_NW] = [d.E , d.DD, d.DD, d.DD, d.DD, d.DD, d.S , d.SE]
        m[p.HALF_NE] = [d.W , d.SW, d.S , d.DD, d.DD, d.DD, d.DD, d.DD]
        m[p.HALF_SE] = [d.DD, d.DD, d.N , d.NW, d.W , d.DD, d.DD, d.DD]

        # Split pieces can return multiple directions for a given input direction, so we return tuples of directions.
        m[p.SPLIT_90_NSEW] = [(d.E,d.W), d.DD, (d.N,d.S), d.DD, (d.E,d.W), d.DD, (d.N,d.S), d.DD]
        m[p.SPLIT_90_DIAG] = [d.DD, (d.SE,d.NW), d.DD, (d.NE,d.SW), d.DD, (d.SE,d.NW), d.DD, (d.NE,d.SW)]
        m[p.SPLIT_45_NSEW] = [(d.NE,d.NW), d.DD, (d.NE,d.SE), d.DD, (d.SE,d.SW), d.DD, (d.NW,d.SW), d.DD]
        m[p.SPLIT_45_DIAG] = [d.DD, (d.N,d.E), d.DD, (d.S,d.E), d.DD, (d.S,d.W), d.DD, (d.N,d.W)]

        # Guide pieces redirect the ray by 45 degrees
        m[p.GUIDE_N_NE] = [d.NE, d.N , d.DD, d.DD, d.SW, d.S , d.DD, d.DD]
        m[p.GUIDE_E_SE] = [d.DD, d.DD, d.SE, d.E , d.DD, d.DD, d.NW, d.W ]
        m[p.GUIDE_N_NW] = [d.NW, d.DD, d.DD, d.S , d.SE, d.DD, d.DD, d.N ]
        m[p.GUIDE_E_NE] = [d.DD, d.E , d.NE, d.DD, d.DD, d.W , d.SW, d.DD]

        # Horizontal and vertical half reflection pieces
        m[p.HALF_S] = [d.DD, d.DD, d.DD, d.NE, d.N , d.NW, d.DD, d.DD]
        m[p.HALF_W] = [d.DD, d.DD, d.W , d.DD, d.DD, d.SE, d.E , d.NE]
        m[p.HALF_N] = [d.S , d.SE, d.DD, d.DD, d.DD, d.DD, d.DD, d.SW]
        m[p.HALF_E] = [d.DD, d.NW, d.DD, d.SW, d.DD, d.DD, d.DD, d.DD]

        self._pieces = []
        for i in range(10):
            row = [(Piece.EMPTY,0)] * 10
            self._pieces.append(row)
        self.reset()

    def print(self) -> None:
        print(f"{Color.CYAN}Player 1 (cyan){Color.ENDC} vs {Color.RED}Player 2 (red){Color.ENDC}")
        print("+-0-+-1-+-2-+-3-+-4-+-5-+-6-+-7-+-8-+-9-+")
        for y in range(10):
            row1 = ""
            row2 = ""
            row3 = ""
            for x in range(10):
                c = ""
                ec = ""
                piece, player = self._pieces[x][y]
                if player == 1:
                    c = Color.CYAN
                    ec = Color.ENDC
                elif player == 2:
                    c = Color.RED
                    ec = Color.ENDC
                i1, i2, i3 = self.image(x, y)
                row1 += "|" + c + i1 + ec
                v = "|"
                if x == 0:
                    v = str(y)
                row2 += v + c + i2 + ec
                row3 += "|" + c + i3 + ec
            print(row1 + "|")
            print(row2 + str(y))
            print(row3 + "|")
            if y == 9:
                print("+-0-+-1-+-2-+-3-+-4-+-5-+-6-+-7-+-8-+-9-+")
            else:
                print("+---+---+---+---+---+---+---+---+---+---+")

    def get_piece(self, x: int, y: int) -> Tuple[Piece, int]:
        return self._pieces[x][y]

    def reset(self) -> None:
        for x in range(10):
            for y in range(10):
                p = Piece.EMPTY
                if y in (0,9) and (x > 0) and (x < 9):
                    p = Piece.ILLEGAL
                self._pieces[x][y] = (p, 0)
        self._pieces[0][4] = (Piece.LASER_E, 1)
        self._pieces[9][4] = (Piece.LASER_W, 2)
        col1 = (Piece.TARGET, Piece.SPLIT_90_NSEW, Piece.TARGET, Piece.GUIDE_N_NE,
                Piece.GUIDE_N_NW, Piece.TARGET, Piece.SPLIT_45_NSEW, Piece.TARGET)
        y = 1
        for v in col1:
            self._pieces[1][y] = (v, 1)
            self._pieces[8][9-y] = (v, 2)
            y += 1
        col21 = (Piece.REFL_NW_SE, Piece.HALF_SE, Piece.REFL_E_W, Piece.HALF_E,
                 Piece.HALF_E, Piece.REFL_E_W, Piece.HALF_NE, Piece.REFL_NE_SW)
        col22 = (Piece.REFL_NE_SW, Piece.HALF_SW, Piece.REFL_E_W, Piece.HALF_W,
                 Piece.HALF_W, Piece.REFL_E_W, Piece.HALF_NW, Piece.REFL_NW_SE)
        y = 1
        for v1,v2 in zip(col21, col22):
            self._pieces[2][y] = (v1, 1)
            self._pieces[7][y] = (v2, 2)
            y += 1

    def check_win(self) -> int:
        p1_win = True
        p2_win = True
        for x in range(10):
            for y in range(10):
                piece, player = self._pieces[x][y]
                if piece == Piece.TARGET:
                    if player == 1:
                        p2_win = False
                    elif player == 2:
                        p1_win = False
        if p1_win and not p2_win:
            return 1
        elif p2_win and not p1_win:
            return 2
        else:
            return 0

    def move(self, src: Tuple[int, int], tgt: Tuple[int,int],
             player: int = 0, rotate: Rotate = Rotate.CW_0, do_fire: bool = True) -> None:
        piece, cur_player = self.get_piece(src[0], src[1])
        if player:
            if player != cur_player:
                raise RuntimeError(f"Piece is not owned by the specified player: {player}")
        if not self.is_legal_move(src, tgt):
            raise RuntimeError(f"Specified move from: {src} to {tgt} is not legal.")
        # move the piece to the target location and set the source location to empty.
        self._pieces[src[0]][src[1]] = (Piece.EMPTY, 0)
        self._pieces[tgt[0]][tgt[1]] = (piece, cur_player)
        # rotate the piece at the target location if needed.
        self.rotate(tgt, rotate)
        # if the piece is a laser, then fire the laser after moving and rotating.
        if do_fire:
            if piece in (Piece.LASER_NE, Piece.LASER_E, Piece.LASER_SE, Piece.LASER_NW, Piece.LASER_W, Piece.LASER_SW):
                self.fire_laser(cur_player)
    
    def fire_laser(self, player: int) -> None:
        col = 0
        if player == 2:
            col = 9
        piece = Piece.ILLEGAL
        loc = [0, 0]
        for row in range(10):
            piece, p = self.get_piece(col, row)
            if piece in (Piece.LASER_NE, Piece.LASER_E, Piece.LASER_SE,
                         Piece.LASER_NW, Piece.LASER_W, Piece.LASER_SW):
                loc = [col, row]
                break
        if piece == Piece.ILLEGAL:
            raise RuntimeError(f"Player {player} does not have a laser piece on the board!")
        print(f"Firing laser {loc} for player {player}...")
        laser_dirs = {Piece.LASER_NE: Direction.NE, Piece.LASER_E: Direction.E, Piece.LASER_SE: Direction.SE,
                      Piece.LASER_NW: Direction.NW, Piece.LASER_W: Direction.W, Piece.LASER_SW: Direction.SW}
        direction = laser_dirs.get(piece, None)
        if direction is None:
            raise RuntimeError(f"Invalid laser piece for player {player}: {piece}")
        laser = [[loc, direction]]
        while len(laser) > 0:
            # Walk a copy of the laser list since we will be modifying the original laser list while iterating.
            tmp = laser
            laser = []
            for step in tmp:
                # New location is current location + delta of direction.
                loc = step[0]
                direction = step[1]
                loc[0] += delta(direction)[0]
                loc[1] += delta(direction)[1]
                piece, p = self.get_piece(loc[0], loc[1])
                # Question: if two laser paths hit the same piece at the same time, do they both interact
                # with the piece before it is destroyed/reflected/split?
                # if we move off the core board, then stop that laser path.
                if loc[0] in (0, 9) or loc[1] in (0, 9):
                    # Stop laser path if we hit the edge of the board
                    continue
                # If the piece is empty, then continue moving in the same direction.
                if piece == Piece.EMPTY:
                    # continue moving in the same direction
                    laser.append([loc, direction])
                    continue
                # If the piece is a target, then destroy the target
                elif piece == Piece.TARGET:
                    # destroy the target and stop that laser path
                    self._pieces[loc[0]][loc[1]] = (Piece.EMPTY, 0)
                    continue
                else:
                    # redirect the ray according to the piece type and continue.
                    new_dir = self._redirect_ray(piece, direction)
                    if new_dir != (Direction.DD,):
                        # If the new direction is valid, then add the new location and direction
                        # to the laser list to continue processing.
                        for d in new_dir:
                            laser.append([loc, d])
                    else:
                        # piece is destroyed, remove the piece from the board and stop that laser path.
                        self._pieces[loc[0]][loc[1]] = (Piece.EMPTY, 0)
                        # ray is destroyed, so do not add to laser list.
                        continue

    def _redirect_ray(self, piece: Piece, direction: Direction) -> Tuple[Direction, ...]:
        # If the piece is a reflector, then change direction accordingly and continue.
        # If the piece is a splitter, then split the laser into multiple directions and continue.
        # If the piece is a guide, then change direction accordingly and continue.
        # If the piece is a half-piece, then reflect or destroy it and stop.
        redirect_list = self._dir_map.get(piece, None)
        if redirect_list is None:
            raise RuntimeError(f"Invalid piece type for redirection: {piece}")
        # Always return a tuple of directions, even if there is only one direction, for consistency.
        ret = redirect_list[direction]
        if type(ret) is not tuple:
            ret = (ret,)
        return ret

    def rotate(self, pos: Tuple[int, int], rotate: Rotate) -> None:
        # no rotation?
        if rotate == Rotate.CW_0:
            return
        piece, player = self.get_piece(pos[0], pos[1])
        if player == 0:
            return
        if piece == Piece.TARGET:
            return
        # if laser, then rotate some amount and clamp to the laser range.
        laser_inc = {Rotate.L_CW_45: 1, Rotate.L_CW_90: 2, Rotate.L_CCW_45: -1, Rotate.L_CCW_90: -2}
        if piece in (Piece.LASER_NE, Piece.LASER_E, Piece.LASER_SE):
            piece += laser_inc.get(rotate, 0)
            piece = clamp(piece, Piece.LASER_NE, Piece.LASER_SE)
        elif piece in (Piece.LASER_NW, Piece.LASER_W, Piece.LASER_SW):
            piece -= laser_inc.get(rotate, 0)
            piece = clamp(piece, Piece.LASER_NW, Piece.LASER_SW)
        else:
            # Other pieces can rotate in 90 degree increments
            # The rotations are piece number increments within lists for each piece type.
            # If the piece is in the 2 or 4 piece list, then increment by 1 for each 90 degree rotation and
            # apply mod to wrap around.
            other_inc = {Rotate.CW_0: 0, Rotate.CW_90: 1, Rotate.CW_180: 2, Rotate.CW_270: 3}
            l0 = [Piece.REFL_NW_SE, Piece.REFL_NE_SW]
            l1 = [Piece.REFL_E_W, Piece.REFL_N_S]
            l2 = [Piece.HALF_NE, Piece.HALF_SE, Piece.HALF_SW, Piece.HALF_NW]
            l3 = [Piece.SPLIT_90_NSEW, Piece.SPLIT_90_DIAG]
            l4 = [Piece.SPLIT_45_NSEW, Piece.SPLIT_45_DIAG]
            l5 = [Piece.GUIDE_N_NE, Piece.GUIDE_E_SE]
            l6 = [Piece.GUIDE_N_NW, Piece.GUIDE_E_NE]
            l7 = [Piece.HALF_N, Piece.HALF_E, Piece.HALF_S, Piece.HALF_W]
            rotation_lists = [l0, l1, l2, l3, l4, l5, l6, l7]
            for the_list in rotation_lists:
                if piece in the_list:
                    idx = the_list.index(piece)
                    idx += other_inc.get(rotate, 0)
                    idx = idx % len(the_list)
                    piece = the_list[idx]
                    break
        self._pieces[pos[0]][pos[1]] = (piece, player)

    def is_legal_move(self, src: Tuple[int, int], tgt: Tuple[int, int]) -> bool:
        # if one delta is 0 (row move or column move) then ok.
        # if both are non-zero, then they must have the same magnitude.
        dx = tgt[0] - src[0]
        dy = tgt[1] - src[1]
        tmp = list(src)
        # if both deltas are non-zero, then they must have the same magnitude (diagonal move).
        if dx != 0 and dy != 0:
            if abs(dx) != abs(dy):
                return False
        # check the piece at the source location. If it's a laser, then it can only move within its own column.
        piece, _ = self.get_piece(src[0], src[1])
        if piece in (Piece.LASER_NE, Piece.LASER_E, Piece.LASER_SE, Piece.LASER_NW, Piece.LASER_W, Piece.LASER_SW):
            # only allow movement within the same column for lasers
            if dx != 0:
                return False
            # move to the target
            tmp[1] += dy
            # check that the target is on the full board
            if tmp[1] < 0 or tmp[1] > 9:
                return False
            return True
        # check that the path from source to target is clear (no pieces in the way). We can do this by walking
        # from source to target in increments of -1, 0, or 1 for each delta until we reach the target.
        mag = max(abs(dx),abs(dy))
        # deltas are now -1, 0 or 1
        dx = int(dx / mag)
        dy = int(dy / mag)
        # Note: if dx and dy are both 0, then we will (implicitly) not enter the loop and will
        # just check that the source and target are the same.
        for i in range(mag):
            # move one step towards the target
            tmp[0] += dx
            tmp[1] += dy
            # check that current position is on the core board
            if tmp[0] < 1 or tmp[0] > 8:
                return False
            if tmp[1] < 1 or tmp[1] > 8:
                return False
            # check that there is no piece at the current position
            s, _ = self.get_piece(tmp[0], tmp[1])
            if s != Piece.EMPTY:
                return False
        # if we made it here, then the path is clear.
        return tmp == list(tgt)

    def image(self, x: int, y: int) -> Tuple[str, str, str]:
        p, _ = self.get_piece(x, y)
        if p == Piece.ILLEGAL:
            return "   ", "   ", "   "
        elif p == Piece.EMPTY:
            if x < 1 or x > 8 or y < 1 or y > 8:
                return ". .", "   ", ". ."
            return "...", "...", "..."
        elif p == Piece.TARGET:
            return "+-+", "|X|", "+-+"
        elif p == Piece.LASER_NE:
            return "  /", " O ", "   "
        elif p == Piece.LASER_E:
            return "   ", " o-", "   "
        elif p == Piece.LASER_SE:
            return "   ", " O ", "  \\"
        elif p == Piece.LASER_NW:
            return "\\  ", " O ", "   "
        elif p == Piece.LASER_W:
            return "   ", "-O ", "   "
        elif p == Piece.LASER_SW:
            return "   ", " O ", "/  "
        elif p == Piece.REFL_NW_SE:
            return "  /", " / ", "/  "
        elif p == Piece.REFL_NE_SW:
            return "\\  ", " \\ ", "  \\"
        elif p == Piece.REFL_E_W:
            return " | ", " | ", " | "
        elif p == Piece.REFL_N_S:
            return "   ", "---", "   "
        elif p == Piece.HALF_NE:
            return "\\  ", "*\\ ", "**\\"
        elif p == Piece.HALF_SE:
            return "**/", "*/ ", "/  "
        elif p == Piece.HALF_SW:
            return "\\**", " \\*", "  \\"
        elif p == Piece.HALF_NW:
            return "  /", " /*", "/**"
        elif p == Piece.SPLIT_90_NSEW:
            return "*|*", "-+-", "*|*"
        elif p == Piece.SPLIT_90_DIAG:
            return "\\*/", "*+*", "/*\\"
        elif p == Piece.SPLIT_45_NSEW:
            return "\\|/", "-+-", " | "
        elif p == Piece.SPLIT_45_DIAG:
            return "\\|/", " +-", "/ \\"
        elif p == Piece.GUIDE_N_NE:
            return "  /", " + ", " | "
        elif p == Piece.GUIDE_E_SE:
            return "   ", "-+ ", "  \\"
        elif p == Piece.GUIDE_N_NW:
            return "\\  ", " + ", " | "
        elif p == Piece.GUIDE_E_NE:
            return "   ", "-+ ", " /"
        elif p == Piece.HALF_N:
            return "   ", "---", "***"
        elif p == Piece.HALF_E:
            return "*| ", "*| ", "*| "
        elif p == Piece.HALF_S:
            return "***", "---", "   "
        elif p == Piece.HALF_W:
            return " |*", " |*", " |*"
        raise RuntimeError(f"Unknown piece type: {p}!")


if __name__ == "__main__":
    print("Welcome to Deflection!")
    board = Board()
    board.print()
    player = 1
    piece = Piece.EMPTY
    while board.check_win() == 0:
        while True:
            print(f"Player {player}: select a piece to move: x, y ([0,9],[0,9])")
            try:
                cmd = sys.stdin.readline().strip()
                src = tuple(map(int, cmd.split(",")))
            except Exception as e:
                print("Invalid input format.")
                continue
            if len(src) != 2:
                print("Invalid input format.")
                continue
            piece, play = board.get_piece(src[0], src[1])
            if play != player or piece == Piece.ILLEGAL:
                print("Invalid piece selection.")
                continue
            if piece != Piece.EMPTY:
                break
        while True:
            print("Select a target location: x, y ([0,9],[0,9])")
            try:
                cmd = sys.stdin.readline().strip()
                tgt = tuple(map(int, cmd.split(",")))
            except Exception as e:
                print("Invalid input format.")
                continue
            if len(tgt) != 2:
                print("Invalid input format.")
                continue
            if piece < Piece.REFL_NW_SE:
                # if piece is a laser, then target must be in the same column.
                if tgt[0] != src[0]:
                    print("Invalid target for laser piece. Target must be in the same column.")
                    continue
                else:
                    break
            t_piece, _ = board.get_piece(tgt[0], tgt[1])
            if t_piece == Piece.EMPTY:
                break
            print("Invalid target.")
        while True:
            if piece < Piece.REFL_NW_SE:
                print("Select a rotation: -90, -45, 0, 45, 90")
            else:
                print("Select a rotation: 0, 90, 180, or 270")
            cmd = sys.stdin.readline().strip()
            if cmd in ("0", "90", "180", "270", "45", "-45", "-90"):
                break
            print("Invalid rotation.")
        rotate_map = {"0": Rotate.CW_0, "90": Rotate.CW_90, "180": Rotate.CW_180, "270": Rotate.CW_270,
                      "45": Rotate.L_CW_45, "-45": Rotate.L_CCW_45, "-90": Rotate.L_CCW_90}
        rotate = rotate_map.get(cmd, Rotate.CW_0)
        if piece < Piece.REFL_NW_SE and rotate == Rotate.CW_90:
            rotate = Rotate.L_CW_90
        try:
            board.move(src, tgt, player, rotate)
        except RuntimeError as e:
            print(e)
            continue
        print("Result of the move:")
        board.print()
        player = 3 - player
