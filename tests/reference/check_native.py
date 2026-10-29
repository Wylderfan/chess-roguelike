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
 data=json.loads(pathlib.Path(__file__).with_name('positions.json').read_text())
 for i,f in enumerate(data['positions']):
  send('position fen '+f['fen']);send('knight snapshot');actual=json.loads(get('knight '))
  for a,b in [('legal','legal'),('other_legal','other'),('threats','threats')]:check(actual[a]==f[b],f['name']+' '+a+'\nactual '+str(actual[a])+'\nexpected '+str(f[b]))
  for depth,expected in f['divide'].items():
   send('knight divide '+depth);counts=json.loads(get('divide '));check(counts==expected,f['name']+' depth '+depth+'\nactual '+str(counts)+'\nexpected '+str(expected))
   print('PERFT',f['name'],depth,sum(counts.values()),flush=True)
  if (i+1)%100==0:print('Native reference positions:',i+1,flush=True)
 # Invalid commands must leave live position unchanged and process usable.
 send('position startpos');send('knight snapshot');before=json.loads(get('knight '))
 invalid=['4k3/8/8/8/8/8/8/4K3 w K - 0 1','4k3/8/8/8/8/8/4K3/7R w K - 0 1','9/8/8/8/8/8/8/4K2k w - - 0 1','4k3/8/8/8/8/8/8/K3R3 w - - 0 1','4k3/8/8/8/8/8/8/4K3 z - - 0 1']
 invalid += data['invalid_ep']
 for fen in invalid:
  send('position fen '+fen)
  s=lines.get(timeout=5);check(s.startswith('info string error'), 'malformed FEN rejected: '+s)
  send('knight snapshot');after=json.loads(get('knight '));check(before==after,'malformed command did not partially mutate live position')
 print('NATIVE REFERENCE:',len(data['positions']),'positions,',checks,'checks, 0 failures')
finally:
 send('quit');p.wait(timeout=5)
 err=p.stderr.read();assert not err,err
