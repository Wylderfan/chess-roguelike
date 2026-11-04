"""Optional test-only oracle: pip install chess==1.11.2 (GPL; NOT bundled).
Run with PYTHONPATH pointing at that separate installation. Output is position
and move-count data, not copied library code. Seeded corpus is reproducible.
"""
import chess,random,json,pathlib,sys
assert chess.__version__=='1.11.2'
OUT=pathlib.Path(__file__).with_name('positions.json')
def perft(b,d):
 if d==0:return 1
 total=0
 for m in list(b.legal_moves):
  b.push(m);total+=perft(b,d-1);b.pop()
 return total
def divide(b,d):
 out={}
 for m in list(b.legal_moves):
  b.push(m);out[m.uci()]=perft(b,d-1);b.pop()
 return out
invalid_ep=['7k/8/8/4P3/8/8/8/K7 w - d6 0 1', '7k/8/8/8/4p3/8/8/K7 b - d3 0 1', '7k/8/8/3PP3/8/8/8/K7 w - d6 0 1', '7k/8/8/8/3pp3/8/8/K7 b - d3 0 1', '7k/8/3N4/3pP3/8/8/8/K7 w - d6 0 1', '7k/8/8/8/3Pp3/3n4/8/K7 b - d3 0 1', '7k/3n4/8/3pP3/8/8/8/K7 w - d6 0 1', '7k/8/8/8/3Pp3/8/3N4/K7 b - d3 0 1']
for fen in invalid_ep: assert chess.Board(fen).status() & chess.STATUS_INVALID_EP_SQUARE
positions=[]
def add(name,fen,counts=()):
 b=chess.Board(fen)
 allowed=chess.STATUS_TOO_MANY_WHITE_PAWNS|chess.STATUS_TOO_MANY_BLACK_PAWNS|chess.STATUS_TOO_MANY_WHITE_PIECES|chess.STATUS_TOO_MANY_BLACK_PIECES
 assert not (b.status() & ~allowed),(name,b.status())
 assert all(len(b.occupied_co[c].to_bytes(8,'little'))==8 and chess.popcount(b.occupied_co[c])<=32 for c in [0,1])
 other=b.copy();other.turn=not b.turn;other.ep_square=None
 clean=lambda x:sorted(m.uci() for m in x.legal_moves if x.piece_type_at(m.to_square)!=chess.KING)
 p={'name':name,'fen':b.fen(en_passant='fen'),'legal':clean(b),'other':clean(other),'threats':{chess.square_name(s):sorted(chess.square_name(t) for t in b.attacks(s)) for s in b.piece_map()},'divide':{}}
 for d,known in enumerate(counts,1):
  values=divide(b,d);assert sum(values.values())==known,(name,d,sum(values.values()),known)
  p['divide'][str(d)]=values
 positions.append(p)
known=[('start',chess.STARTING_FEN,[20,400,8902,197281]),('kiwipete','r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',[48,2039,97862]),('ep-endgame','8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',[14,191,2812,43238]),('promotions','r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1',[6,264,9467]),('check-evasions','rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8',[44,1486,62379])]
for a in known:add(*a)
fixtures=[
('ep-no-capturer-white', '7k/8/8/3p4/8/8/8/K7 w - d6 0 1'),
('ep-no-capturer-black', '7k/8/8/8/3P4/8/8/K7 b - d3 0 1'),
('ep-capture-white', '7k/8/8/3pP3/8/8/8/K7 w - d6 0 1'),
('ep-capture-black', '7k/8/8/8/3Pp3/8/8/K7 b - d3 0 1'),

('both-castles','r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
('black-castles','r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 0 1'),
('rook-attacked','k6r/8/8/8/8/8/8/4K2R w K - 0 1'),
('b1-attacked','1r5k/8/8/8/8/8/8/R3K3 w Q - 0 1'),
('blocked-b1','7k/8/8/8/8/8/8/RN2K3 w Q - 0 1'),
('transit-attacked','4kr2/8/8/8/8/8/8/4K2R w K - 0 1'),
('destination-attacked','4k1r1/8/8/8/8/8/8/4K2R w K - 0 1'),
('checked-king','k3r3/8/8/8/8/8/8/4K2R w K - 0 1'),
('pinned-knight-attacks','7k/8/8/8/8/8/7n/4K2R w K - 0 1'),
('rights-absent','4k3/8/8/8/8/8/8/R3K2R w - - 0 1'),
('ep-discovered','k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1'),
('ep-rank-discovered','8/8/8/r4pPK/8/8/8/k7 w - f6 0 1'),
('double-check','4r1k1/8/8/8/1b6/8/8/4K3 w - - 0 1'),
('promotion-all4','1r2k3/P7/8/8/8/8/8/4K3 w - - 0 1'),
('nine-isolated-pawns','7k/8/8/8/P1P1P3/P1P1P3/P1P1P3/6K1 w - - 0 1'),
('ten-queens-after-promotion','7k/2P3pp/8/8/8/8/QQ6/KQQQQQQQ w - - 0 1'),
('same-color-bishops-dead','7k/8/8/6B1/8/4B3/8/K1B5 w - - 0 1'),
('221-legal-moves','QQQQQQnk/Q4Qpp/2Q3Q1/Q5QQ/3Q3Q/QQ1Q3Q/PPQ4Q/KN1QQQQQ w - - 0 1'),
('129-captures','qQqQQqnk/qQqQqQpp/QQqQqQqQ/qqqQqQqQ/1QQQqqqq/QqqqQQQQ/PPQqQqqq/KNQqQqQQ w - - 0 1')]
for name,fen in fixtures:add(name,fen)
for kind in [chess.PAWN,chess.KNIGHT,chess.BISHOP,chess.ROOK,chess.QUEEN]:
 b=chess.Board(None);b.set_piece_at(chess.A1,chess.Piece(chess.KING,1));b.set_piece_at(chess.H8,chess.Piece(chess.KING,0));b.set_piece_at(chess.H7,chess.Piece(chess.PAWN,0));b.set_piece_at(chess.G7,chess.Piece(chess.PAWN,0))
 for s in (list(range(8,39)) if kind==chess.PAWN else list(range(1,32))):b.set_piece_at(s,chess.Piece(kind,1))
 add('max-32-'+chess.piece_name(kind),b.fen())
b=chess.Board(None)
for s in chess.SQUARES:b.set_piece_at(s,chess.Piece(chess.QUEEN,s<32))
b.set_piece_at(chess.A1,chess.Piece(chess.KING,1));b.set_piece_at(chess.H8,chess.Piece(chess.KING,0));add('max-both-32',b.fen())
b=chess.Board('7k/2P3pp/8/8/QQQQQQQ1/QQQQQQQQ/QQQQQQQQ/KQQQQQQQ w - - 0 1');add('max-31-queens-after-promotion',b.fen())
rng=random.Random(6062026)
for game in range(8):
 b=chess.Board()
 for ply in range(60):
  if not list(b.legal_moves):break
  b.push(rng.choice(sorted(b.legal_moves,key=lambda m:m.uci())))
  add(f'random-{game}-{ply+1}',b.fen(en_passant='fen'))
# Keep extra-material positions, not adjudication, as oracle comparisons. Orthodox
# inventory status is intentionally ignored; all structural/check flags are not.
for start in [p for p in list(positions) if p['name'] in ['221-legal-moves','129-captures','nine-isolated-pawns','max-32-queen']]:
 b=chess.Board(start['fen'])
 for ply in range(12):
  moves=sorted(b.legal_moves,key=lambda m:m.uci())
  if not moves:break
  b.push(rng.choice(moves));add(start['name']+'-walk-'+str(ply+1),b.fen(en_passant='fen'))
OUT.write_text(json.dumps({'reference':'chess 1.11.2 (separate test-only install)','seed':6062026,'sources':['https://www.chessprogramming.org/Perft_Results','https://github.com/official-stockfish/Stockfish/blob/ff7cee4244ec96ea488c402669e3674c0574dce6/tests/perft.sh'],'positions':positions,'invalid_ep':invalid_ep},indent=2)+'\n')
print(len(positions),'positions;',sum(len(x['divide']) for x in positions),'published perft/divides')
