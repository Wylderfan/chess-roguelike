"""Compare native UCI against saved independent oracle, no chess dependency."""
import json,pathlib,subprocess,sys,queue,threading,time
root=pathlib.Path(__file__).resolve().parents[2]
engine=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else root/'native/bin/linux-x64/KnightEngine'
p=subprocess.Popen([str(engine)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
lines=queue.Queue();threading.Thread(target=lambda:[lines.put(x.strip()) for x in p.stdout],daemon=True).start()
def send(s):p.stdin.write(s+'\n');p.stdin.flush()
def get(prefix):
 end=time.monotonic()+30
 while time.monotonic()<end:
  s=lines.get(timeout=max(.1,end-time.monotonic()))
  if s.startswith('info string error'):raise AssertionError(s)
  if s.startswith(prefix):return s[len(prefix):]
 raise AssertionError('timeout '+prefix)
checks=0
def check(ok,label):
 global checks
 checks+=1
 assert ok,label
try:
 if len(sys.argv)>2:send('setoption name RulesProfile value '+sys.argv[2])
 data=json.loads(pathlib.Path(__file__).with_name('retreat_positions.json').read_text())
 for i,f in enumerate(data['positions']):
  send('ucinewgame');send('setoption name PawnRetreat value '+f['ability']);send('position fen '+f['fen']);send('knight snapshot');actual=json.loads(get('knight '))
  for a,b in [('legal','legal'),('other_legal','other'),('threats','threats')]:check(actual[a]==f[b],f['name']+' '+a+'\nactual '+str(actual[a])+'\nexpected '+str(f[b]))
  for depth,expected in f['divide'].items():
   send('knight divide '+depth);counts=json.loads(get('divide '));check(counts==expected,f['name']+' depth '+depth+'\nactual '+str(counts)+'\nexpected '+str(expected))
   print('PERFT',f['name'],depth,sum(counts.values()),flush=True)
  if (i+1)%100==0:print('Native reference positions:',i+1,flush=True)
 print('NATIVE RETREAT REFERENCE:',len(data['positions']),'positions,',checks,'checks, 0 failures')
finally:
 send('quit');p.wait(timeout=5)
 err=p.stderr.read();assert not err,err
