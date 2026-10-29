$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
py -3.12 -m venv .venv
& '.\.venv\Scripts\python.exe' -m pip install -r requirements.txt 'pyinstaller==6.22.3'
& '.\.venv\Scripts\python.exe' 'tools\build_local.py'
if ($LASTEXITCODE -ne 0) { throw 'Build failed' }
