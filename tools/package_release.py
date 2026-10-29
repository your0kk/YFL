import importlib.metadata
import json
import sys
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root))
from yfl import __version__

release = root / 'releases'
release.mkdir(exist_ok=True)
exe = root / 'dist' / 'YFL.exe'
if not exe.is_file():
    raise FileNotFoundError(exe)
licenses = []
for name in ['PySide6_Essentials', 'shiboken6', 'pypdf', 'striprtf']:
    try:
        distribution = importlib.metadata.distribution(name)
        for item in distribution.files or []:
            if 'licenses/' in str(item).replace('\\', '/'):
                source = Path(distribution.locate_file(item))
                if source.is_file():
                    licenses.append((source, 'licenses/' + name + '/' + source.name))
    except importlib.metadata.PackageNotFoundError:
        pass
with zipfile.ZipFile(release / f'YFL-{__version__}-Windows-x64.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    z.write(exe, 'YFL.exe')
    for source, name in licenses:
        z.write(source, name)
source_files = [root / name for name in ['main.py', 'requirements.txt', 'build.ps1', '.gitignore']]
for folder, pattern in [('yfl', '*.py'), ('tests', '*.py'), ('tools', '*.py'), ('qml', '*.qml'), ('assets', '*'), ('design', '*.png')]:
    source_files.extend((root / folder).glob(pattern))
source_files.append(root / 'qml' / 'qmldir')
with zipfile.ZipFile(release / f'YFL-{__version__}-source.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for path in source_files:
        if path.is_file():
            z.write(path, path.relative_to(root))
    for source, name in licenses:
        z.write(source, name)
print(json.dumps({'version': __version__, 'source_files': len(source_files), 'license_files': len(licenses), 'executable_bytes': exe.stat().st_size}))
