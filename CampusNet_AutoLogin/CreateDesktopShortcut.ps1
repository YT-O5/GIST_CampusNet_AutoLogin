# CreateDesktopShortcut.ps1
# Creates desktop shortcut for easy access

# …Ë÷√øÿ÷∆Ã®±‡¬Î
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcutPath = Join-Path $desktopPath "CampusNet Login.lnk"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($shortcutPath)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$batchFile = Join-Path $scriptDir "CampusNet.bat"

$Shortcut.TargetPath = "cmd.exe"
$Shortcut.Arguments = "/k `"cd /d `"$scriptDir`" && `"$batchFile`"`""
$Shortcut.WorkingDirectory = $scriptDir
$Shortcut.Description = "Campus Network Auto Login System"
$Shortcut.IconLocation = "shell32.dll,13"  # Network icon
$Shortcut.Save()

Write-Host "Desktop shortcut created successfully!" -ForegroundColor Green
Write-Host "Location: $shortcutPath" -ForegroundColor Cyan
Write-Host "Note: Shortcut will open in the correct directory automatically." -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")