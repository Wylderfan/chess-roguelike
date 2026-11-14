#!/usr/bin/env python3
"""Package already-built Godot exports and matching native engines; no releases."""
import hashlib, json, pathlib, shutil, subprocess, zipfile
root = pathlib.Path(__file__).resolve().parents[1]
out = root / 'build/packages'
out.mkdir(parents=True, exist_ok=True)
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def finish(stage):
    files = {p.relative_to(stage).as_posix(): digest(p) for p in sorted(stage.rglob('*')) if p.is_file()}
    (stage/'BUILD.json').write_text(json.dumps({'source_commit':commit,'godot':'4.6.3','native':'.NET 10 self-contained','files_sha256':files},indent=2)+'\n')
    archive = out/(stage.name+'.zip')
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in sorted(stage.rglob('*')):
            if p.is_file(): z.write(p,stage.name+'/'+p.relative_to(stage).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        assert all('\\' not in n and not pathlib.PurePosixPath(n).is_absolute() and '..' not in pathlib.PurePosixPath(n).parts for n in z.namelist())
        for f in z.infolist():
            if f.filename.endswith(('KnightChess.x86_64','linux-x64/KnightEngine','native/build.sh')):
                assert (f.external_attr>>16)&0o111, f.filename
    return {'file':archive.name,'size_bytes':archive.stat().st_size,'sha256':digest(archive),'source_commit':commit}
def fresh(name):
    stage=root/'build/staging'/name
    if stage.exists(): shutil.rmtree(stage)
    stage.mkdir(parents=True)
    return stage
results=[]
for platform,rid,exe in [('Windows','win-x64','KnightChess.exe'),('Linux','linux-x64','KnightChess.x86_64')]:
    stage=fresh('Knight-Chess-Sandbox-v0.9-'+platform+'-x64')
    shutil.copy2(root/'build'/platform.lower()/exe,stage/exe)
    target=stage/'native/bin'/rid;target.mkdir(parents=True)
    engine='KnightEngine.exe' if platform=='Windows' else 'KnightEngine'
    shutil.copy2(root/'native/bin'/rid/engine,target/engine)
    licenses=stage/'licenses';licenses.mkdir()
    for p in [root/'build/GODOT-COPYRIGHT.txt',root/'assets/FONT-LICENSE.txt',*sorted((root/'native').glob('LICENSE*')),root/'native/THIRD-PARTY-DOTNET.txt']:
        shutil.copy2(p,licenses/p.name)
    (stage/'START-HERE.txt').write_text('Knight Chess integrated playtest\n\nExtract the entire ZIP before playing. Keep native beside the game.\n'+('Double-click KnightChess.exe. No Godot or .NET installation required.\nWindows x64 only; cross-built on Linux, not executed on Windows.\n' if platform=='Windows' else 'Launch ./KnightChess.x86_64. ZIP retains executable bits; if your extractor drops them, chmod +x KnightChess.x86_64 native/bin/linux-x64/KnightEngine.\n')+'\nRight-click either army to inspect. New Game opens sandbox setup; Quit to Menu confirms before discarding a match.\nChoose Create Sandbox Game, then Upgrade a piece, click a pawn and equip Pawn Retreat. Rare/Legendary\nhave two slots, but only Pawn Retreat is implemented; the other stays empty.\nNo progression, loot or second ability. See README.md for controls and limits.\n')
    shutil.copy2(root/'README.md',stage/'README.md')
    results.append(finish(stage))
stage=fresh('Knight-Chess-Sandbox-v0.9-Godot-4.6.3')
files=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode().split('\0')
for name in filter(None,files):
    if name.startswith(('dist/','.github/')): continue
    src=root/name
    if not src.is_file(): continue
    dst=stage/name;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for rid,exe in [('linux-x64','KnightEngine'),('win-x64','KnightEngine.exe')]:
    dst=stage/'native/bin'/rid;dst.mkdir(parents=True)
    shutil.copy2(root/'native/bin'/rid/exe,dst/exe)
(stage/'START-HERE.txt').write_text('Extract all files. Import project.godot in Godot 4.6.3 (standard editor) and press F5 to play. Matching Windows x64 and Linux x64 self-contained engines are bundled. Do not copy engines from older packages. No .NET installation is needed to play.\n')
results.append(finish(stage))
(out/'SHA256SUMS.txt').write_text(''.join(f"{r['sha256']}  {r['file']}\n" for r in results))
(out/'archives.json').write_text(json.dumps(results,indent=2)+'\n')
print(json.dumps(results,indent=2))
