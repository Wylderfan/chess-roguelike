"""UCI profile deadlines, diagnostics, cancellation and state restoration."""
import subprocess,sys,threading,queue,time,json
p=subprocess.Popen([sys.argv[1]],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,bufsize=1)
lines=queue.Queue();threading.Thread(target=lambda:[lines.put(x.strip()) for x in p.stdout],daemon=True).start()
checks=0
seen=[]
def send(s):p.stdin.write(s+'\n');p.stdin.flush()
def get(prefix,timeout=6):
 end=time.monotonic()+timeout
 while time.monotonic()<end:
  s=lines.get(timeout=max(.01,end-time.monotonic()));seen.append(s)
  if s.startswith(prefix):return s[len(prefix):]
  if s.startswith('info string error'):raise AssertionError(s)
 raise AssertionError('timeout '+prefix)
def snap():send('knight snapshot');return json.loads(get('knight '))
def check(ok,label):
 global checks
 checks+=1;assert ok,label;print('PASS',label,flush=True)
try:
 for profile in ['standard','conservative']:
  send('setoption name RulesProfile value '+profile);send('position startpos');before=snap()
  check(before['profile']==profile,'snapshot reflects '+profile)
  start=time.monotonic();send('go movetime 300');move=get('bestmove ');elapsed=time.monotonic()-start
  check(move in before['legal'] and elapsed<2,profile+' timed legal search '+str(round(elapsed,3))+'s')
  check(snap()==before,profile+' timed search restores full snapshot')
  diag=next(s for s in reversed(seen) if s.startswith('info string profile ')).split()
  if profile=='conservative':
   check(all(int(diag[diag.index(k)+1])==0 for k in ['lmr','tt_probes','tt_stores','positional_evals']) and int(diag[diag.index('material_evals')+1])>0,'conservative runtime counters honor controls')
  send('go movetime 5000');time.sleep(.04);start=time.monotonic();send('stop');move=get('bestmove ')
  check(move in before['legal'] and time.monotonic()-start<1,profile+' stop joins promptly with legal result')
  check(snap()==before,profile+' interrupted search restores full snapshot')
  mark=len(seen)
  send('go movetime 5000');send('setoption name RulesProfile value '+('standard' if profile=='conservative' else 'conservative'));send('isready');get('readyok')
  check(not any(x.startswith('bestmove ') for x in seen[mark:]) and lines.empty(),profile+' option transition suppresses stale result')
  send('setoption name RulesProfile value '+profile)
  send('position fen 7k/6Q1/5K2/8/8/8/8/8 b - - 0 1');send('go movetime 300')
  check(get('bestmove ')=='0000',profile+' terminal position returns safe no-move')
 send('setoption name RulesProfile value unsupported')
 check('Unknown RulesProfile' in get('info string error '),'unsupported profile rejected')
 print('PROFILE PROTOCOL:',checks,'checks, 0 failures')
finally:
 send('quit');p.wait(timeout=5)
