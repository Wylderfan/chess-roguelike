"""Independent test-only Pawn Retreat oracle using python-chess 1.11.2.
Standard moves use its legal generator. The sole added move is checked by
pushing on an independent board and testing the moving king's attackers.
Not imported or bundled into the game runtime.
"""
import chess, json, pathlib, random

def legal(board, setting):
    out = [m for m in board.legal_moves if board.piece_type_at(m.to_square) != chess.KING]
    active = setting == 'both' or setting == ('white' if board.turn else 'black')
    if active:
        for source in board.pieces(chess.PAWN, board.turn):
            target = source + (-8 if board.turn else 8)
            if 8 <= target < 56 and not board.piece_at(target):
                move = chess.Move(source, target)
                copy = board.copy(); side = board.turn
                # python-chess's push handles ordinary quiet pawn state. The
                # target may equal ep_square but a same-file move is no capture.
                copy.push(move)
                if not copy.is_attacked_by(not side, copy.king(side)): out.append(move)
    return sorted(out, key=lambda m:m.uci())

def perft(board, setting, depth):
    if not depth: return 1
    result = 0
    for move in legal(board,setting):
        child=board.copy();child.push(move)
        result += perft(child,setting,depth-1)
    return result

def fixture(board,setting,name,depths=()):
    other=board.copy();other.turn=not other.turn;other.ep_square=None
    divide={}
    for depth in depths:
        counts={}
        for move in legal(board,setting):
            child=board.copy();child.push(move)
            counts[move.uci()]=perft(child,setting,depth-1)
        divide[str(depth)]=counts
    return dict(name=name,fen=board.fen(en_passant='fen'),ability=setting,
        legal=[m.uci() for m in legal(board,setting)],other=[m.uci() for m in legal(other,setting)],
        threats={chess.square_name(s):sorted(chess.square_name(t) for t in board.attacks(s)) for s in board.piece_map()},divide=divide)

fixtures=[]
for name,fen in [
 ('sparse','7k/8/8/4p3/4P3/8/8/K7 w - - 0 1'),
 ('blocked','7k/8/8/8/4P3/4n3/8/K7 w - - 0 1'),
 ('pin','7k/8/8/8/r3P2K/8/8/8 w - - 0 1'),
 ('evasion','7k/8/8/8/4P3/r6K/8/8 w - - 0 1'),
 ('promotion','7k/P7/8/8/8/8/7p/K7 w - - 0 1')]:
 for setting in ['none','white','black','both']:
    fixtures.append(fixture(chess.Board(fen),setting,name+'_'+setting,(1,2,3)))
rng=random.Random(7042026)
for setting in ['white','black','both']:
 for game in range(2):
    board=chess.Board()
    for ply in range(40):
        fixtures.append(fixture(board,setting,f'{setting}_{game}_{ply}'))
        moves=legal(board,setting)
        if not moves:break
        retreats=[m for m in moves if board.piece_type_at(m.from_square)==chess.PAWN and (m.to_square-m.from_square)* (1 if board.turn else -1)<0]
        board.push(rng.choice(retreats if retreats and rng.random()<.45 else moves))
pathlib.Path(__file__).with_name('retreat_positions.json').write_text(json.dumps({'positions':fixtures},indent=2)+'\n')
print(len(fixtures),'variant oracle positions')
