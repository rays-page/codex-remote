$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$shortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex Remote.lnk"
$targetPath = Join-Path $scriptRoot "start_codex_remote.bat"
$workingDirectory = $repoRoot
$iconPath = Join-Path $env:SystemRoot "System32\shell32.dll"

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $targetPath
$shortcut.WorkingDirectory = $workingDirectory
$shortcut.IconLocation = "$iconPath,220"
$shortcut.Description = "Launch the Codex Remote desktop relay."
$shortcut.Save()

Write-Output "Created $shortcutPath"
