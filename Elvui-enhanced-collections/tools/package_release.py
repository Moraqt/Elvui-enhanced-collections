from pathlib import Path
import hashlib
import zipfile

root = Path(__file__).resolve().parents[1]
addon = root / 'ElvUI_EnhancedCollections'
installed = Path(r'C:\Users\Rodrigo\AppData\Local\Whitemane\Games\FrostmourneRebuffed\Interface\AddOns\ElvUI_EnhancedCollections')
names = ['Core.lua', 'Skin.lua', 'Options.lua', 'ElvUI_EnhancedCollections.toc', 'README.md']
archive = root.parent / 'ElvUI-EnhancedCollections-1.1.0.zip'
for name in names:
    assert (addon / name).read_bytes() == (installed / name).read_bytes(), name
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as package:
    for name in names:
        package.write(addon / name, f'{addon.name}/{name}')
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    assert len(package.namelist()) == len(names)
    for name in names:
        assert package.read(f'{addon.name}/{name}') == (addon / name).read_bytes(), name
print(f'Verified {len(names)} packaged files match the installed addon.')
print(archive)
print('SHA256:', hashlib.sha256(archive.read_bytes()).hexdigest())
