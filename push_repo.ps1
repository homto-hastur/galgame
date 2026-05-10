$env:PATH = "C:\Program Files\Git\cmd;" + $env:PATH
Set-Location -Path "C:\ai\ArkhamHorror"
& "C:\Program Files\GitHub CLI\gh.exe" repo create ArkhamHorrorBackup --private --source=. --remote=origin --push
