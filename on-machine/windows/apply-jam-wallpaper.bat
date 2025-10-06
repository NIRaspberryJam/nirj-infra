:: apply-jam-wallpaper.bat

@echo off

:: Set registry key for background
reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "C:\Wallpaper\jam-desktop.jpg" /f

:: Apply it immediately
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters