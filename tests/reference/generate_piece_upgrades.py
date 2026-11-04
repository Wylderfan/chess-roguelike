"""Independent test-only oracle for per-piece Pawn Retreat, python-chess 1.11.2.
Markers follow individual pawns; captures/EP/promotion remove markers. No game
code is imported. Generated fixtures are facts, not a runtime dependency.
"""
import chess,json,pathlib,random

def legal(board,markers):
    moves=[m for m in board.legal_moves if board.piece_type_at(m.to_square)!=chess.KING]
    for source in sorted(markers):
        if board.piece_at(source)!=chess.Piece(chess.PAWN,board.turn):continue
        target=source+(-8 if board.turn else 8)
        if 8<=target<56 and board.piece_at(target) is None:
            move=chess.Move(source,target);child=board.copy();side=board.turn
            child.push(move)
            if not child.is_attacked_by(not side,child.king(side)):moves.append(move)
    return sorted(moves,key=lambda m:m.uci())
def push(board,markers,move):
    child=board.copy();next_markers=set(markers)
    active=move.from_square in next_markers
    next_markers.discard(move.from_square);next_markers.discard(move.to_square)
    if board.is_en_passant(move):next_markers.discard(move.to_square+(-8 if board.turn else 8))
    child.push(move)
    if active and move.promotion is None:next_markers.add(move.to_square)
    return child,next_markers
def perft(board,markers,depth):
    if depth==0:return 1
    return sum(perft(*push(board,markers,m),depth-1) for m in legal(board,markers))
def fixture(board,markers,name,depths=()):
    other=board.copy();other.turn=not other.turn;other.ep_square=None
    divide={str(d):{m.uci():perft(*push(board,markers,m),d-1) for m in legal(board,markers)} for d in depths}
    return dict(name=name,fen=board.fen(en_passant='fen'),markers=sorted(chess.square_name(s) for s in markers),legal=[m.uci() for m in legal(board,markers)],other=[m.uci() for m in legal(other,markers)],threats={chess.square_name(s):sorted(chess.square_name(t) for t in board.attacks(s)) for s in board.piece_map()},divide=divide)
fixtures=[]
for name,fen,markers in [
 ('mixed_white','7k/8/8/8/3PP3/8/8/K7 w - - 0 1',['e4']),
 ('mixed_black','7k/8/8/3pp3/8/8/8/K7 b - - 0 1',['d5']),
 ('both','7k/8/3pp3/8/8/3PP3/8/K7 w - - 0 1',['e3','d6']),
 ('capture','7k/8/3p4/4P3/8/8/8/K7 w - - 0 1',['e5','d6']),
 ('ep','7k/8/8/3pP3/8/8/8/K7 w - d6 0 1',['e5','d5']),
 ('promotion','7k/P7/8/8/8/8/7p/K7 w - - 0 1',['a7','h2']),
 ('pin','7k/8/8/8/r3P2K/8/8/8 w - - 0 1',['e4']),
 ('evasion','7k/8/8/8/4P3/r6K/8/8 w - - 0 1',['e4'])]:
 fixtures.append(fixture(chess.Board(fen),{chess.parse_square(s) for s in markers},name,(1,2,3)))
rng=random.Random(8042026)
for game in range(4):
 board=chess.Board();markers={chess.parse_square(s) for s in [['e2','c7'],['d2','f7'],['a2','h2','b7'],['e7','a7','d2']][game]}
 for ply in range(40):
  fixtures.append(fixture(board,markers,f'walk{game}_{ply}'))
  moves=legal(board,markers)
  if not moves:break
  retreats=[m for m in moves if m.from_square in markers and (m.to_square-m.from_square)*(1 if board.turn else -1)<0]
  board,markers=push(board,markers,rng.choice(retreats if retreats and rng.random()<.5 else moves))
pathlib.Path(__file__).with_name('piece_upgrade_positions.json').write_text(json.dumps({'positions':fixtures},indent=2)+'\n')
print(len(fixtures),'per-piece positions')
