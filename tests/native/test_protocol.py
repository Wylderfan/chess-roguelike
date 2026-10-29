#!/usr/bin/env python3
"""Standard-library UCI lifecycle tests. Pass the native executable path."""
import json, queue, subprocess, sys, threading, time
engine = sys.argv[1]
p = subprocess.Popen([engine], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
lines = queue.Queue()
threading.Thread(target=lambda: [lines.put(s.strip()) for s in p.stdout], daemon=True).start()
checks = 0

def send(s):
    p.stdin.write(s+'\n'); p.stdin.flush()
def until(prefix, timeout=6):
    end = time.monotonic()+timeout
    while time.monotonic()<end:
        try: s=lines.get(timeout=max(.01,end-time.monotonic()))
        except queue.Empty: break
        if s.startswith('info string error'): raise AssertionError(s)
        if s.startswith(prefix): return s
    raise AssertionError('timeout waiting '+prefix)
def check(ok,label):
    global checks
    checks+=1
    assert ok,label
    print('PASS '+label,flush=True)
def snapshot():
    send('knight snapshot')
    return json.loads(until('knight ')[7:])
try:
    send('uci'); until('uciok'); send('isready'); until('readyok')
    check(True,'startup UCI handshake')
    for fen in ['7k/5Q2/6K1/8/8/8/8/8 b - - 0 1','7k/6Q1/5K2/8/8/8/8/8 b - - 0 1']:
        send('position fen '+fen); send('go movetime 10')
        check(until('bestmove ')=='bestmove 0000','safe terminal root '+fen)
    send('position startpos')
    original=snapshot()
    check(len(original['legal'])==20,'20 initial legal moves')
    seq='g1f3 g8f6 f3g1 f6g8 '*2
    send('position startpos moves '+seq)
    repeated=snapshot()
    check(repeated['repetition_count']==3 and repeated['history_count']==9,'full move sequence retains threefold history')
    send('position fen '+repeated['fen'])
    isolated=snapshot()
    check(isolated['repetition_count']==1,'isolated FEN correctly differs from repeated history')
    fixtures=[
      ('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1',{'e1g1','e1c1'}),
      ('4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1',{'e5d6'}),
      ('4k3/P7/8/8/8/8/8/4K3 w - - 0 1',{'a7a8q','a7a8r','a7a8b','a7a8n'})]
    for fen,moves in fixtures:
        send('position fen '+fen)
        check(moves<=set(snapshot()['legal']),'special legal set '+str(moves))
    for i in range(12):
        send('position startpos');send('go movetime 2000')
        time.sleep(.006)
        send('stop')
        check(until('bestmove ').split()[1] in original['legal'],'rapid stop returns one legal move '+str(i))
        send('ucinewgame')
        send('position startpos moves e2e4')
        snap=snapshot()
        send('go movetime 100')
        check(until('bestmove ').split()[1] in snap['legal'],'new position cannot receive old result '+str(i))
    send('position startpos');send('go movetime 10')
    send('position startpos moves d2d4');snapshot()
    start=time.monotonic();send('go movetime 450')
    best=until('bestmove ')
    elapsed=time.monotonic()-start
    check(elapsed>=.35,'old short timer cannot stop new search')
    send('position startpos');send('go depth 3 movetime 2000')
    info=until('info depth ')
    check(int(info.split()[2])==3,'go depth supported explicitly')
    until('bestmove ')
    send('quit');p.wait(timeout=3)
    check(p.returncode==0,'clean quit joins active worker')
    check(not p.stderr.read().strip(),'no native stderr/runtime errors')
    print(f'PROTOCOL: {checks} checks, 0 failures')
finally:
    if p.poll() is None: p.kill();p.wait()
