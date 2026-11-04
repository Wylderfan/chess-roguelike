#!/usr/bin/env python3
"""Per-piece Pawn Retreat UCI contract regression. Run with native executable path."""
import json, subprocess, sys, queue, threading, time
p=subprocess.Popen([sys.argv[1]],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
q=queue.Queue(); threading.Thread(target=lambda:[q.put(s.strip()) for s in p.stdout],daemon=True).start()
checks=0
def send(s): p.stdin.write(s+'\n');p.stdin.flush()
def until(prefix):
    end=time.monotonic()+10
    while time.monotonic()<end:
        s=q.get(timeout=max(.01,end-time.monotonic()))
        if s.startswith('info string error') and not prefix.startswith('info string error'): raise AssertionError(s)
        if s.startswith(prefix):return s
    raise AssertionError('timeout '+prefix)
def snap(): send('knight snapshot');return json.loads(until('knight ')[7:])
def check(ok,label):
    global checks
    checks+=1;assert ok,label;print('PASS '+label)
try:
    send('uci');until('uciok')
    send('setoption name PawnRetreatSquares value e3')
    send('knight snapshot');until('info string error')
    check(True,'square configuration defers occupancy validation and blocks premature snapshot')
    send('position fen 7k/8/8/8/8/3PP3/8/K7 w - - 0 1')
    s=snap();check(s['schema']==2 and s['retreat_squares']==['e3'] and s['profile']=='conservative','per-piece contract active')
    check('e3e2' in s['legal'] and 'd3d2' not in s['legal'],'only selected pawn can retreat')
    send('position fen 7k/8/8/8/8/3PP3/8/K7 w - - 0 1 moves e3e2 h8g8 e2e4')
    s=snap();check(s['retreat_squares']==['e4'],'initial square option replays marker movement')
    send('go movetime 100');check(until('bestmove ').split()[1] in s['legal'],'per-piece search returns legal move')
    send('setoption name PawnRetreatSquares value d3');until('info string error')
    check(snap()['retreat_squares']==['e4'],'midgame marker changes reject without mutation')
    for value in ['e3,e3','a1','z3','e3,','unknown']:
        send('setoption name PawnRetreatSquares value '+value);until('info string error')
        check(snap()['retreat_squares']==['e4'],'invalid syntax leaves state intact '+value)
    send('ucinewgame');send('position fen 7k/8/8/8/8/3PP3/8/K7 w - - 0 1')
    check(snap()['retreat_squares']==['e3'],'newgame retains initial square configuration')
    send('ucinewgame');send('setoption name PawnRetreatSquares value e4')
    send('position fen 7k/8/8/8/8/3PP3/8/K7 w - - 0 1');until('info string error')
    send('go movetime 10');until('info string error');check(True,'invalid marker occupancy blocks search until valid position')
    send('setoption name PawnRetreatSquares value e3')
    send('position fen 7k/8/8/8/8/4p3/4R3/K7 w - - 0 1 moves e2e3')
    s=snap();check(s['retreat_squares']==[] and s['schema']==0 and s['abilities_empty'] and s['profile']=='conservative','captured final marker disappears but root profile remains conservative')
    send('ucinewgame');send('setoption name PawnRetreatSquares value a7')
    send('position fen 7k/P7/8/8/8/8/8/K7 w - - 0 1 moves a7a8q')
    s=snap();check(s['retreat_squares']==[] and s['schema']==0 and s['profile']=='conservative','promotion consumes pawn-only power')
    send('ucinewgame');send('setoption name PawnRetreatSquares value d5,e5')
    send('position fen 7k/8/8/3pP3/8/8/8/K7 w - d6 0 1 moves e5d6')
    check(snap()['retreat_squares']==['d6'],'EP removes victim marker and moves capturing marker')
    send('ucinewgame');send('setoption name PawnRetreatSquares value none');send('position startpos')
    s=snap();check(s['schema']==0 and s['profile']=='standard' and len(s['legal'])==20,'empty marker config restores orthodox baseline')
    send('quit');p.wait(timeout=5);check(p.returncode==0 and not p.stderr.read().strip(),'clean process exit')
    print(f'PIECE RETREAT PROTOCOL: {checks} checks, 0 failures')
finally:
    if p.poll() is None:p.kill();p.wait()
