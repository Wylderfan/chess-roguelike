#!/usr/bin/env python3
"""Separate visual playtest; never overwrites the v0.9 package names."""
import hashlib,json,pathlib,shutil,subprocess,zipfile,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'build/castle-print';out.mkdir(exist_ok=True)
name='Knight-Chess-Castle-Print-v1-Windows-x64'
stage=out/name
if stage.exists():shutil.rmtree(stage)
stage.mkdir()
shutil.copy2(root/'build/windows/KnightChess.exe',stage/'KnightChess.exe')
engine=stage/'native/bin/win-x64';engine.mkdir(parents=True)
shutil.copy2(root/'native/bin/win-x64/KnightEngine.exe',engine/'KnightEngine.exe')
licenses=stage/'licenses';licenses.mkdir()
for p in [root/'build/GODOT-COPYRIGHT.txt',root/'assets/FONT-LICENSE.txt',root/'assets/art/SOURCES.md',*sorted((root/'native').glob('LICENSE*')),root/'native/THIRD-PARTY-DOTNET.txt']:shutil.copy2(p,licenses/p.name)
(stage/'START-HERE.txt').write_text('Knight Chess - Castle Print visual playtest\n\nExtract the whole ZIP, then double-click KnightChess.exe. Keep native beside the game.\nChoose Create Sandbox Game. Gameplay and the native engine are unchanged from v0.9.\nThis is a separate art direction candidate; keep your v0.9 baseline.\nWindows x64 export verified on Linux, not executed on Windows.\n')
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
m={'source_commit':head,'godot':'4.6.3','baseline':'78d5e1615d133201acb36fca3ca26ca4e35d970f','files_sha256':{p.relative_to(stage).as_posix():digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}}
(stage/'BUILD.json').write_text(json.dumps(m,indent=2)+'\n')
archive=out/(name+'.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(stage.rglob('*')):
  if p.is_file():z.write(p,name+'/'+p.relative_to(stage).as_posix())
with tempfile.TemporaryDirectory(prefix='castle print clean extraction ') as temp:
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  assert all(not pathlib.PurePosixPath(n).is_absolute() and '..' not in pathlib.PurePosixPath(n).parts and '\\' not in n for n in z.namelist())
  z.extractall(temp)
 extracted=pathlib.Path(temp)/name
 for p,h in m['files_sha256'].items():assert digest(extracted/p)==h
 for p in [extracted/'KnightChess.exe',extracted/'native/bin/win-x64/KnightEngine.exe']:
  data=p.read_bytes();assert data[:2]==b'MZ';offset=int.from_bytes(data[60:64],'little');assert data[offset:offset+6]==b'PE\0\0d\x86'
 expected=json.loads((root/'native/BINARY-SHA256.json').read_text())['native/bin/win-x64/KnightEngine.exe']
 assert digest(extracted/'native/bin/win-x64/KnightEngine.exe')==expected
result={'file':archive.name,'size_bytes':archive.stat().st_size,'sha256':digest(archive),'source_commit':head,'verification':'ZIP CRC, safe paths, fresh extraction, every file hash, x64 PE game and matching unchanged native engine PASS'}
(out/'archive.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
