import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
windows = Path(os.environ.get('SystemRoot', 'C:/Windows'))
os.environ['PATH'] = os.pathsep.join([str(Path(sys.executable).parent), str(windows / 'System32'), str(windows), str(root / '.build-deps' / 'PySide6'), str(root / '.build-deps' / 'shiboken6')])
args = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--onefile', '--windowed', '--name', 'YFL', '--collect-all', 'striprtf', '--paths', str(root / '.build-deps'), '--add-data', str(root / 'qml') + ';qml']
for module in ['numpy', 'pandas', 'scipy', 'matplotlib', 'torch', 'IPython', 'jupyter', 'cv2', 'openpyxl', 'sympy', 'cryptography', 'Crypto', 'PIL', 'tkinter', 'PySide6.QtWebEngineCore', 'PySide6.QtWebEngineWidgets', 'PySide6.QtWebEngineQuick', 'PySide6.QtPdf', 'PySide6.QtCharts', 'PySide6.QtGraphs', 'PySide6.QtMultimedia', 'PySide6.QtMultimediaWidgets', 'PySide6.QtQuick3D']:
    args += ['--exclude-module', module]
if (root / 'assets' / 'yfl.ico').exists():
    args += ['--icon', str(root / 'assets' / 'yfl.ico'), '--add-data', str(root / 'assets') + ';assets']
args.append(str(root / 'main.py'))
os.chdir(root)
subprocess.run(args, check=True)
