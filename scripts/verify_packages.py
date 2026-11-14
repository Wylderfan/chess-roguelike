#!/usr/bin/env python3
"""Linux verification of fresh ZIP extraction, hashes, executable modes and bridge."""
import hashlib,json,pathlib,subprocess,tempfile,zipfile
root=pathlib.Path(__file__).resolve().parents[1]
out=root/'build/packages'
with tempfile.TemporaryDirectory(prefix='knight clean extraction ') as temp:
    temp=pathlib.Path(temp)
    for archive in sorted(out.glob('*.zip')):
        with zipfile.ZipFile(archive) as z:
            assert z.testzip() is None
            for f in z.infolist():
                path=pathlib.PurePosixPath(f.filename)
                assert not path.is_absolute() and '..' not in path.parts and '\\' not in f.filename
        subprocess.run(['unzip','-q',str(archive),'-d',str(temp)],check=True)
        stage=temp/archive.stem
        manifest=json.loads((stage/'BUILD.json').read_text())
        for name,digest in manifest['files_sha256'].items():
            assert hashlib.sha256((stage/name).read_bytes()).hexdigest()==digest,name
        print('ARCHIVE PASS',archive.name,archive.stat().st_size,flush=True)
    linux=temp/'Knight-Chess-Playtest-Linux-x64'
    engine=linux/'native/bin/linux-x64/KnightEngine'
    assert engine.stat().st_mode&0o111 and (linux/'KnightChess.x86_64').stat().st_mode&0o111
    def run(args,cwd):
        p=subprocess.run(list(map(str,args)),cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=600)
        print(p.stdout,flush=True)
        assert p.returncode==0 and 'SCRIPT ERROR' not in p.stdout and 'Parse Error' not in p.stdout and 'FAIL:' not in p.stdout,args
    run([engine,'--selftest'],temp)
    run([linux/'KnightChess.x86_64','--headless','--quit-after','3'],temp)
    project=temp/'Knight-Chess-Playtest-Godot-4.6.3'
    assert not (project/'.godot').exists()
    run(['godot','--headless','--editor','--path',project,'--import'],temp)
    for suite in ['piece_upgrades','piece_bridge','retreat_ui','reference']:
        run(['godot','--headless','--path',project,'--script',f'res://tests/test_{suite}.gd'],temp)
print('CLEAN EXTRACTION: all archives, hashes, executable modes, exported startup, source import, native selftest and source bridge/oracle PASS')
