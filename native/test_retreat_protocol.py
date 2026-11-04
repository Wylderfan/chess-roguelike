#!/usr/bin/env python3
"""Pawn Retreat UCI contract regression. Run with native executable path."""
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
    for side in ['white','black','both']:
        send('ucinewgame');send('setoption name PawnRetreat value '+side)
        send('setoption name RulesProfile value standard')
        turn='b' if side=='black' else 'w'
        send('position fen 7k/8/4p3/8/8/4P3/8/K7 '+turn+' - - 0 1')
        s=snap();check(s['schema']==1 and not s['abilities_empty'] and s['pawn_retreat']==side and s['profile']=='conservative','registered contract '+side)
        check(('e6e7' if turn=='b' else 'e3e2') in s['legal'],'retreat legal '+side)
        check(('e3e2' if turn=='b' else 'e6e7') in s['other_legal'] if side=='both' else ('e3e2' if turn=='b' else 'e6e7') not in s['other_legal'],'off-turn per-side contract '+side)
        check(s['threats']['e3']==['d4','f4'] and s['threats']['e6']==['d5','f5'],'unchanged pawn attacks '+side)
        send('go movetime 100');check(until('bestmove ').split()[1] in s['legal'],'search returns legal active move '+side)
    send('position fen 7k/4P3/8/4p3/8/8/8/K7 w - e6 0 1 moves e7e6')
    until('info string error');check(True,'inconsistent EP vacated origin rejected')
    send('position fen 7k/8/4p3/8/8/4P3/8/K7 w - - 0 1 moves e3e2')
    send('setoption name PawnRetreat value none');until('info string error')
    check(snap()['pawn_retreat']=='both','midgame capability changes reject without mutation')
    send('ucinewgame');send('setoption name PawnRetreat value both')
    send('position fen 7k/8/4p3/8/8/4P3/8/K7 w - - 0 1 moves '+'e3e2 e6e7 e2e3 e7e6 '*2)
    s=snap();check(s['repetition_count']==3 and s['history_count']==9,'pawn cycle repetition survives replay')
    send('ucinewgame');check(snap()['pawn_retreat']=='both','newgame retains options')
    send('setoption name PawnRetreat value none');s=snap()
    check(s['schema']==0 and s['abilities_empty'] and s['profile']=='standard' and len(s['legal'])==20,'disabled restores standard contract')
    send('setoption name PawnRetreat value invalid');until('info string error')
    check(snap()['pawn_retreat']=='none','unknown ability option rejects atomically')
    send('quit');p.wait(timeout=5);check(p.returncode==0 and not p.stderr.read().strip(),'clean process exit')
    print(f'RETREAT PROTOCOL: {checks} checks, 0 failures')
finally:
    if p.poll() is None:p.kill();p.wait()
