"""Validate and package only independently authored deliverables."""
import hashlib
import json
import re
from pathlib import Path
import sys
import zipfile

root = Path(__file__).parent
addon = root / 'EncounterLab'
output = Path(sys.argv[1]) if len(sys.argv) > 1 else root.parent / 'outputs'
output.mkdir(parents=True, exist_ok=True)
toc = (addon / 'EncounterLab.toc').read_text(encoding='utf-8-sig')
assert '## Interface: 120100' in toc
version = re.search(r'^## Version:\s*([0-9A-Za-z.-]+)\s*$', toc, re.MULTILINE).group(1)
assert f'EL.VERSION = "{version}"' in (addon / 'Namespace.lua').read_text(encoding='utf-8-sig')
loaded = [line.strip().replace('\\','/') for line in toc.splitlines() if line.strip() and not line.startswith('#')]
core = ['Namespace.lua','Locale.lua','Theme.lua','MouseCapture.lua','Persistence.lua','Simulation.lua','Sszorak.lua','Sentinels.lua','TwinFangs.lua','Rehearsal.lua','SceneAssets.lua','ArenaRoom.lua','ViewMotion.lua','Renderer.lua','TempestRenderer.lua','TwinFangsRenderer.lua','SentinelsRenderer.lua','SentinelsArena.lua','Input.lua','Interface.lua','TrainingUI.lua','SentinelsUI.lua','TwinFangsUI.lua','Bootstrap.lua']
assert [name for name in loaded if not name.startswith('Locales/')] == core
assert len(set(loaded)) == len(loaded)
for index, name in enumerate(loaded):
    if name.startswith('Locales/'):
        assert loaded.index('Locale.lua') < index < loaded.index('Theme.lua'), 'Translations must load after Locale.lua and before consumers'
for name in loaded:
    assert (addon / name).is_file(), f'Missing TOC file: {name}'
for name in ['LavaPool.tga','LavaWave.tga','Basalt.tga','RoundedMask.tga','SentinelsFloor.tga']:
    blob = (addon / 'Media' / name).read_bytes()
    assert blob[2] == 2 and blob[16] == 32, f'Expected own 32-bit TGA: {name}'

def pack(path, files):
    with zipfile.ZipFile(path,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for source, arcname in files:
            assert not source.is_symlink()
            z.write(source,arcname)
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        assert all(not n.startswith(('/', '\\')) and '..' not in Path(n).parts for n in z.namelist())
    return {'file':path.name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

addon_files = [(p, 'EncounterLab/'+p.relative_to(addon).as_posix()) for p in sorted(addon.rglob('*')) if p.is_file()]
assert sum(p.stat().st_size for p, _ in addon_files) < 2 * 1024 * 1024, 'Unexpected runtime size; do not ship development files'
assert len(addon_files) == len(loaded) + 9, 'Only TOC, README, LICENSE, locale README and five textures may accompany loaded Lua'
assert all(not any(part in ('.git', 'work', 'outputs', '__pycache__') for part in p.relative_to(addon).parts) for p, _ in addon_files)
release = output / f'EncounterLab-{version}.zip'
release_report = pack(release,addon_files)
devfiles = [(root.parent / name, name) for name in ['LICENSE', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes', 'docs/encounterlab-icon.png', 'docs/twin-fangs.md', 'tools/make_icon.py']]
devfiles += [(p, 'work/'+name) for p, name in addon_files]
devfiles += [(root / name,'work/'+name) for name in ['make_media.py','make_sentinels_floor.py','sentinels_floor.lua','Build.ps1','Install.ps1','package.py','renderer-tests.lua','STATUS.md']]
devfiles += [(p,'work/tests/'+p.name) for p in sorted((root/'tests').glob('*.lua'))]
source_report = pack(output / f'EncounterLab-{version}-source.zip',devfiles)
(output/'README-EncounterLab.md').write_text((addon/'README.md').read_text(encoding='utf-8-sig'),encoding='utf-8')
(output/'STATUS-EncounterLab.md').write_text((root/'STATUS.md').read_text(encoding='utf-8-sig'),encoding='utf-8')
report = {'version':version,'targetInterface':120100,'luaFiles':len(loaded),'addonFiles':len(addon_files),'packages':[release_report,source_report], 'liveClientVerified':False}
(output/'build-manifest.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
