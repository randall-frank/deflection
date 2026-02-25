import copy
import random
import sys
import time
from enum import IntEnum
from typing import Tuple, Any


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
    # For other Pieces (0,1,2,3) steps CW
    CW_0 = 0    # no rotation
    CW_1 = 1    # 90 (or 45) degrees clockwise
    CW_2 = 2    # 180 (or 90) degrees clockwise
    CW_3 = 3    # 270 (or 135) degrees clockwise
    # For Lasers, the rotation is an absolute direction
    L_NE = 0    # LASER_NE + Rotation = new laser piece number
    L_E =  1
    L_SE = 2
    L_NW = 3
    L_W =  4
    L_SW = 5


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
    """Returns the delta (dx, dy) for a given direction.
    The directions are defined in the Direction enum as.
    """
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
    if direction == Direction.DD:
        return (0, 0)
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
    HALF_SW = 14
    HALF_NW = 15
    HALF_NE = 16
    HALF_SE = 17
    SPLIT_90_NSEW = 18
    SPLIT_90_DIAG = 19
    SPLIT_45_NSEW = 20
    SPLIT_45_DIAG = 21
    GUIDE_N_NE = 22
    GUIDE_E_SE = 23
    GUIDE_N_NW = 24
    GUIDE_E_NE = 25
    HALF_S = 26
    HALF_W = 27
    HALF_N = 28
    HALF_E = 29


def clamp(value: Any, minimum: Any, maximum: Any) -> Any:
    """Clamps the value to the specified minimum and maximum range."""
    return max(minimum, min(value, maximum))


class Board:
    """Class representing the game board for Deflection. The board is a 10x10 grid
    with pieces that can be moved and rotated by the players.
    The pieces are represented by the Piece enum, and each piece has a mapping of
    input direction to output direction(s) for when a laser hits that piece.
    The board also keeps track of which player owns each piece."""
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
        #              [d.N , d.NE, d.E , d.SE, d.S , d.SW, d.W , d.NW]
        m[p.HALF_SW] = [d.DD, d.DD, d.DD, d.DD, d.E , d.NE, d.N , d.DD]
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
        #             [d.N , d.NE, d.E , d.SE, d.S , d.SW, d.W , d.NW]
        m[p.HALF_S] = [d.DD, d.DD, d.DD, d.NE, d.N , d.NW, d.DD, d.DD]
        m[p.HALF_W] = [d.DD, d.DD, d.DD, d.DD, d.DD, d.SE, d.E , d.NE]
        m[p.HALF_N] = [d.S , d.SE, d.DD, d.DD, d.DD, d.DD, d.DD, d.SW]
        m[p.HALF_E] = [d.DD, d.NW, d.DD, d.SW, d.DD, d.DD, d.DD, d.DD]

        self._pieces = []
        for i in range(10):
            row = [(Piece.EMPTY,0)] * 10
            self._pieces.append(row)
        self.reset()

    @staticmethod
    def print_player(s: str, player: int) -> str:
        if player == 1:
            return Color.CYAN + s + Color.ENDC
        else:
            return Color.RED + s + Color.ENDC

    def print(self) -> None:
        """Prints the board to the console in a human-readable format. Player 1 pieces are printed in cyan
        and player 2 pieces are printed in red."""
        s1 = self.print_player('Player 1',1)
        s2 = self.print_player('Player 2',2)
        print(f"{s1} {Color.CYAN}({self.score_position(1)}){Color.ENDC} vs " +
              f"{s2} {Color.RED}({self.score_position(2)}){Color.ENDC}")
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
        """Returns a tuple of (piece, player) for the piece at the specified location.
        Player is 0 if the piece is not owned by either player."""
        return self._pieces[x][y]

    def reset(self) -> None:
        """Resets the board to the initial configuration."""
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
        col21 = (Piece.REFL_NW_SE, Piece.HALF_NW, Piece.REFL_E_W, Piece.HALF_W,
                 Piece.HALF_W, Piece.REFL_E_W, Piece.HALF_SW, Piece.REFL_NE_SW)
        col22 = (Piece.REFL_NE_SW, Piece.HALF_NE, Piece.REFL_E_W, Piece.HALF_E,
                 Piece.HALF_E, Piece.REFL_E_W, Piece.HALF_SE, Piece.REFL_NW_SE)
        y = 1
        for v1,v2 in zip(col21, col22):
            self._pieces[2][y] = (v1, 1)
            self._pieces[7][y] = (v2, 2)
            y += 1

    def winner(self) -> int:
        """Returns 0 if no winner, 1 if player 1 wins, and 2 if player 2 wins."""
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
             player: int, rotate: Rotate, do_fire: bool = True) -> None:
        """Moves a piece from the source location to the target location, rotates it, and optionally
        fires the laser if the piece is a laser."""
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
            if self.is_laser(piece):
                self.fire_laser(cur_player)
    
    def fire_laser(self, player: int) -> None:
        """Fires the laser for the specified player. The laser starts at the player's laser piece
        and travels in the direction"""
        col = 0
        if player == 2:
            col = 9
        piece = Piece.ILLEGAL
        loc = [0, 0]
        for row in range(10):
            piece, p = self.get_piece(col, row)
            if self.is_laser(piece) and p == player:
                loc = [col, row]
                break
        if piece == Piece.ILLEGAL:
            raise RuntimeError(f"Player {player} does not have a laser piece on the board!")
        # print(f"Firing laser {loc} {piece} for player {player}...")
        laser_dirs = {Piece.LASER_NE: Direction.NE, Piece.LASER_E: Direction.E, Piece.LASER_SE: Direction.SE,
                      Piece.LASER_NW: Direction.NW, Piece.LASER_W: Direction.W, Piece.LASER_SW: Direction.SW}
        direction = laser_dirs.get(piece, None)
        if direction is None:
            raise RuntimeError(f"Invalid laser piece for player {player}: {piece}")
        laser = [[loc, direction]]
        while len(laser) > 0:
            # print("Processing laser list: ", laser)
            # Walk a copy of the laser list since we will be modifying the original laser list while iterating.
            tmp = copy.deepcopy(laser)
            laser = []
            # Each step is a list in the form: [loc, direction]
            for step in tmp:
                # print("Processing laser step: ", step, tmp)
                # New location is current location + delta of direction.
                loc = [step[0][0] + delta(step[1])[0], step[0][1] + delta(step[1])[1]]
                direction = copy.deepcopy(step[1])
                # Question: if two laser paths hit the same piece at the same time, do they both interact
                # with the piece before it is destroyed/reflected/split?
                # if we move off the core board, then stop that laser path.
                if loc[0] <= 0 or loc[0] >= 9 or loc[1] <= 0 or loc[1] >= 9:
                    # Stop laser path if we hit the edge of the board
                    # print("Removing laser path since we hit the edge of the board.", loc, direction)
                    continue
                piece, p = self.get_piece(loc[0], loc[1])
                # print("New laser location: ", loc, " piece: ", piece, " from: ", direction)
                # If the piece is empty, then continue moving in the same direction.
                if piece == Piece.EMPTY:
                    # continue moving in the same direction
                    laser.append([loc, direction])
                    # print("Continuing laser path since we hit an empty space.", loc, direction)
                    continue
                else:
                    # redirect the ray according to the piece type and continue.
                    new_dir = self._redirect_ray(piece, direction)
                    # print("Redirection ", piece, " from:", direction, " result: ", new_dir)
                    if new_dir != (Direction.DD,):
                        # If the new direction is valid, then add the new location and direction
                        # to the laser list to continue processing.
                        for d in new_dir:
                            laser.append([loc, d])
                            # print("Added: ", loc, d, " to laser list:", laser)
                    else:
                        # print("Destroying piece at ", loc, " and stopping laser path.")
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
        """Rotates the piece at the specified position by the specified rotation.
        The rotation is applied after the piece is moved to the target location.
        If the piece is a laser, then the rotation is an absolute direction and the
        piece is changed to the corresponding laser piece for that direction."""
        # no rotation?
        piece, player = self.get_piece(pos[0], pos[1])
        if player == 0:
            return
        if piece == Piece.TARGET:
            return
        # if laser, then the rotation specifies the piece directly.
        if piece in (Piece.LASER_NE, Piece.LASER_E, Piece.LASER_SE):
            piece = Piece.LASER_NE + rotate
            piece = clamp(piece, Piece.LASER_NE, Piece.LASER_SE)
        elif piece in (Piece.LASER_NW, Piece.LASER_W, Piece.LASER_SW):
            piece = Piece.LASER_NE + rotate
            piece = clamp(piece, Piece.LASER_NW, Piece.LASER_SW)
        else:
            # Other pieces can rotate in "step" increments
            # The rotations are piece number increments within lists for each piece type.
            # If the piece is in the 2 or 4 piece list, then increment by 1 for each 90 degree rotation and
            # apply mod to wrap around.
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
                    idx += rotate
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
        if self.is_laser(piece):
            # only allow movement within the same column for lasers
            if dx != 0:
                return False
            # move to the target
            tmp[1] += dy
            # check that the target is on the full board
            if tmp[1] < 0 or tmp[1] > 9:
                return False
            return True
        if piece == Piece.EMPTY:
            return False
        if dx == 0 and dy == 0:
            return True    # staying in place is legal
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

    def score_position(self, player: int) -> int:
        piece_values = {
            Piece.EMPTY: 0,
            Piece.REFL_NW_SE: 9,
            Piece.REFL_NE_SW: 9,
            Piece.REFL_E_W: 9,
            Piece.REFL_N_S: 9,
            Piece.TARGET: 80,
            Piece.HALF_NE: 4,
            Piece.HALF_SE: 4,
            Piece.HALF_SW: 4,
            Piece.HALF_NW: 4,
            Piece.SPLIT_90_NSEW: 7,
            Piece.SPLIT_90_DIAG: 7,
            Piece.SPLIT_45_NSEW: 7,
            Piece.SPLIT_45_DIAG: 7,
            Piece.GUIDE_N_NE: 6,
            Piece.GUIDE_E_SE: 6,
            Piece.GUIDE_N_NW: 6,
            Piece.GUIDE_E_NE: 6,
            Piece.HALF_N: 4,
            Piece.HALF_E: 4,
            Piece.HALF_S: 4,
            Piece.HALF_W: 4
        }
        # simple evaluation function that counts the number of pieces for the player
        # minus the number of pieces for the opponent.
        score = 0
        # only walk the core board since the pieces outside the core board cannot be destroyed.
        # and thus do not contribute to the score in any meaningful fashion.
        for x in range(1,9):
            for y in range(1,9):
                piece, p = self.get_piece(x, y)
                v = piece_values.get(piece, 0)
                # player can be 1 or 2, so we add to the score if the piece belongs to the player
                # and subtract if it belongs to the opponent.  Note that if p == 0, then the piece is
                # not owned by either player and does not contribute to the score.
                if p == player:
                    score += v
                elif p != 0:
                    score -= v
        return score

    def suggest_move(self, player: int, depth: int, max_depth: int) -> \
            [Tuple[int, int], Tuple[int, int], Rotate, int]:
        # simple move suggestion that tries all legal moves and returns the one with the highest score after the move.
        best_score = sys.maxsize * -1
        best_move = None
        count = 0
        # try moving each piece for the player in the core board to each legal target location
        # and rotating it in each possible way, then score the resulting position and keep track of the best one.
        for x in range(1,9):
            for y in range(1,9):
                piece, p = self.get_piece(x, y)
                if p != player:
                    continue
                if piece == Piece.EMPTY:
                    continue
                # try moving in every direction
                for direction in Direction:
                    dx, dy = delta(direction)
                    steps = 8  # max steps in any direction on the board
                    # Use the 'DD' direction to try the "rotate only" case...
                    if direction == Direction.DD:
                        steps = 1
                    for step in range(steps):
                        # Compute the target location by moving in the direction of movement for the number of steps.
                        tx = x + dx * step
                        ty = y + dy * step
                        if not self.is_legal_move((x,y), (tx,ty)):
                            # once we get an illegal move in a given direction, we can stop trying to move further
                            # in that direction since it will also be illegal.
                            break
                        for rotate in (Rotate.CW_0, Rotate.CW_1, Rotate.CW_2, Rotate.CW_3):
                            # make a copy of the board to test the move on since we don't want to
                            # modify the actual board state.
                            orig_board = copy.deepcopy(self._pieces)
                            try:
                                self.move((x,y), (tx,ty), player, rotate)
                                score = self.score_position(player)
                                count += 1
                                if depth < max_depth:
                                    # recursively call suggest_move for the opponent to see how they would
                                    # respond to this move, and subtract their best score from our score to
                                    # get a more accurate evaluation of the move.
                                    # ((x,y), (tx,ty), rotate, best_score)
                                    turn = self.suggest_move(3-player, depth+1, max_depth)
                                    score -= turn[3]
                                if score > best_score:
                                    best_score = score
                                    best_move = ((x,y), (tx,ty), rotate, best_score, count)
                                elif score == best_score:
                                    # if the score is the same as the best score, then we can randomly
                                    # choose to update the best move or not to add some variability to
                                    # the suggestions.
                                    if random.random() < 0.5:
                                        best_move = ((x,y), (tx,ty), rotate, best_score, count)
                            except RuntimeError:
                                # if the move is invalid for some reason (shouldn't happen since we
                                # check legality), then skip it.
                                continue
                            finally:
                                self._pieces = orig_board

        # Try moving/firing the laser.
        # get the column and the valid laser pieces for the player.
        col = 0
        lasers = [Piece.LASER_NE, Piece.LASER_E, Piece.LASER_SE]
        if player == 2:
            col = 9
            lasers = [Piece.LASER_NW, Piece.LASER_W, Piece.LASER_SW]

        # find the current position of the laser for the player
        orig_pos = -1
        for y in range(10):
            piece, p = self.get_piece(col, y)
            if self.is_laser(piece):
                orig_pos = y
                break
        # try each laser piece in each position in the column and fire the laser for each rotation,
        # then score the resulting position and keep track of the best one.
        for y in range(0, 10):
            for new_piece in lasers:
                # preserve the old board state since we will be modifying the board to test the laser firing
                orig_board = copy.deepcopy(self._pieces)
                try:
                    self._pieces[col][orig_pos] = (Piece.EMPTY, 0)
                    self._pieces[col][y] = (new_piece, player)  # set the laser piece in the new position
                    self.fire_laser(player)  # fire the laser from the new position
                    score = self.score_position(player)
                    count += 1
                    if score > best_score:
                        best_score = score
                        best_move = ((col, orig_pos), (col, y), new_piece - Piece.LASER_NE, best_score, count)
                    # if there is no change in score, do not try to fire from the new position since it is unlikely to
                    # be a good move.
                except RuntimeError:
                    continue
                finally:
                    self._pieces = orig_board

        return best_move

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
            return "  /", " /*", "/**"
        elif p == Piece.HALF_SW:
            return "\\  ", "*\\ ", "**\\"
        elif p == Piece.HALF_NW:
            return "**/", "*/ ", "/  "
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
            return "***", "---", "   "
        elif p == Piece.HALF_E:
            return " |*", " |*", " |*"
        elif p == Piece.HALF_S:
            return "   ", "---", "***"
        elif p == Piece.HALF_W:
            return "*| ", "*| ", "*| "
        raise RuntimeError(f"Unknown piece type: {p}!")

    @staticmethod
    def is_laser(piece: Piece) -> bool:
        return piece in (Piece.LASER_NE, Piece.LASER_E, Piece.LASER_SE, Piece.LASER_NW, Piece.LASER_W, Piece.LASER_SW)


if __name__ == "__main__":
    print("Welcome to Deflection!")
    board = Board()
    board.print()
    player = 1
    piece = Piece.EMPTY
    while board.winner() == 0:
        src = []
        tgt = []
        while True:
            #t0 = time.time()
            #suggest = board.suggest_move(player,1,2)
            #t1 = time.time()
            #print(f"Suggested move for player {player}: {suggest} (computed in {t1-t0:.2f} seconds)")
            s1 = board.print_player(f'Player {player}', player)
            print(f"{s1}: select a piece to move: x, y ([0,9],[0,9])")
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
            if board.is_laser(piece):
                # if piece is a laser, then target must be in the same column.
                if tgt[0] != src[0]:
                    print("Invalid target for laser piece. Target must be in the same column.")
                    continue
                else:
                    break
            t_piece, _ = board.get_piece(tgt[0], tgt[1])
            if t_piece == Piece.EMPTY or (tgt == src):
                break
            print("Invalid target.")
        while True:
            valid = []
            if board.is_laser(piece):
                if player == 1:
                    valid = ["NE", "E", "SE"]
                else:
                    valid = ["NW", "W", "SW"]
                print(f"Select laser direction: {valid}")
            else:
                valid = ["0", "90", "180", "270"]
                print(f"Select a counter clockwise rotation: {valid}")
            cmd = sys.stdin.readline().strip().upper()
            if cmd in valid:
                break
            print("Invalid rotation.")
        rotate_map = {"0": Rotate.CW_0, "90": Rotate.CW_1, "180": Rotate.CW_2, "270": Rotate.CW_3,
                      "NE": Rotate.L_NE, "E": Rotate.L_E, "SE": Rotate.L_SE,
                      "NW": Rotate.L_NW, "W": Rotate.L_W, "SW": Rotate.L_SW}
        rotate = rotate_map.get(cmd, Rotate.CW_0)
        try:
            board.move(src, tgt, player, rotate)
        except RuntimeError as e:
            print(e)
            continue
        print("Result of the move:")
        board.print()
        player = 3 - player
