:: OPEN SOURCE :)

@echo off
setlocal EnableExtensions

echo Please wait...
set "regeditAC=False"
set "pshWeb=False"

echo Checking For Permissions...
set "compatCode=CC-%date%-%time%_%random%-%random%"
echo Compatibility check code: %compatCode%

echo Attempting to create registry value...
REG ADD "HKCU\Software\permCheck" /v cCode /t REG_SZ /d "%compatCode%" /f >nul 2>&1

for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\permCheck" /v cCode 2^>nul') do (
    if "%%B"=="%compatCode%" set "regeditAC=True"
)

echo Cleaning up...
REG DELETE "HKCU\Software\permCheck" /v cCode /f >nul 2>&1

echo Compatible? - %regeditAC%

if /I not "%regeditAC%"=="True" (
    echo ERROR: Registry access test failed.
    pause
    exit /b
)

echo Checking PowerShell Web Access...

set "pshTestFile=%TEMP%\DeAIDS_psh_test_%random%_%random%.txt"
set "pshLogoURL=https://raw.githubusercontent.com/fugedaboudit/DeAIDS/refs/heads/main/logo.txt"

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%pshLogoURL%' -OutFile '%pshTestFile%' -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1

if errorlevel 1 (
    set "pshWeb=False"
) else (
    if exist "%pshTestFile%" (
        set "pshWeb=True"
    ) else (
        set "pshWeb=False"
    )
)

if exist "%pshTestFile%" del "%pshTestFile%" >nul 2>&1

echo PowerShell Web Access - %pshWeb%

if /I "%pshWeb%"=="False" (
    echo WARNING: PowerShell Invoke-WebRequest is unavailable.
)

echo.
goto FirstLaunch


:FirstLaunch
reg query "HKCU\Software\DeAIDS" >nul 2>&1

if %errorlevel% equ 0 (
    goto Main
)

echo First Launch Detected, Creating a backup...
set "firstBackup=True"
goto BackupCreate


:BackupCreate
if not exist "%USERPROFILE%\Documents\DeAIDS" (
    mkdir "%USERPROFILE%\Documents\DeAIDS"
)

if /I "%firstBackup%"=="True" (
    set "backupfile=%USERPROFILE%\Documents\DeAIDS\FIRST_deaids_backup_%random%-%random%.deaids"
) else (
    set "backupfile=%USERPROFILE%\Documents\DeAIDS\deaids_backup_%random%-%random%.deaids"
)

echo.
echo Creating backup...
echo.

(
    echo DEAIDS_BACKUP_V4
    echo REGISTRY=HKCU\Control Panel\Mouse
    for /f "tokens=1,2,*" %%A in ('reg query "HKCU\Control Panel\Mouse" 2^>nul ^| findstr /R /V "^HKEY_"') do (
        echo %%A^|%%B^|%%C
    )
    echo REGISTRY=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced
    for /f "tokens=1,2,*" %%A in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl 2^>nul ^| findstr /I /B "TaskbarAl"') do (
        echo %%A^|%%B^|%%C
    )
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$langs = Get-WinUserLanguageList; if ($langs) { Write-Output ('LANGUAGES=' + ($langs.LanguageTag -join ',')) }"
) > "%backupfile%"

if not exist "%backupfile%" (
    echo ERROR: Failed to create backup.
    pause
    exit /b
)

findstr /B /C:"DEAIDS_BACKUP_V4" "%backupfile%" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Backup validation failed.
    del "%backupfile%" >nul 2>&1
    pause
    exit /b
)

findstr /B /C:"LANGUAGES=" "%backupfile%" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Language backup validation failed.
    del "%backupfile%" >nul 2>&1
    pause
    exit /b
)

echo Backup successfully created:
echo "%backupfile%"
echo.

if /I "%firstBackup%"=="True" (
    reg add "HKCU\Software\DeAIDS" /f >nul 2>&1

    if errorlevel 1 (
        echo WARNING: Backup succeeded, but the DeAIDS marker could not be created.
        echo The next launch may be detected as a first launch again.
    ) else (
        echo First-launch backup completed.
    )
)

set "firstBackup=False"
pause
goto Main


:BackupLoad
set "backupfile="

echo.
set /p "backupfile=Enter file path to .deaids backup file: "
set "backupfile=%backupfile:"=%"

if not exist "%backupfile%" (
    echo ERROR: Backup file does not exist.
    pause
    goto Main
)

for %%F in ("%backupfile%") do set "extension=%%~xF"

if /I not "%extension%"==".deaids" (
    echo ERROR: Invalid file extension. Expected a .deaids file.
    pause
    goto Main
)

set "header="
set /p "header="<"%backupfile%"

if not "%header%"=="DEAIDS_BACKUP_V4" (
    echo ERROR: Invalid .deaids backup file.
    echo This backup was created with an unsupported version.
    pause
    goto Main
)

echo.
echo Valid DeAIDS V4 backup detected.
echo.
echo Loading backup...
echo.

set "currentRegistry="
set "savedLanguages="

for /f "usebackq delims=" %%A in ("%backupfile%") do (
    call :ProcessBackupLine "%%A"
)

if defined savedLanguages (
    echo.
    echo Restoring Windows language configuration...
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$tags = '%savedLanguages%'.Split(',') | Where-Object { $_ -and $_.Trim() }; if ($tags.Count -gt 0) { $list = New-WinUserLanguageList -Language $tags; Set-WinUserLanguageList -LanguageList $list -Force }"

    if errorlevel 1 (
        echo WARNING: Failed to restore the Windows language configuration.
        echo The registry settings were restored successfully.
    ) else (
        echo Windows language configuration restored.
    )
) else (
    echo.
    echo WARNING: No language configuration was found in this backup.
)

echo.
echo Backup loading completed.
echo.
echo Refreshing Explorer...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul
start explorer.exe

echo Taskbar refreshed.
echo.
echo A sign-out or restart may be required for language changes to fully apply.
pause
goto Main


:ProcessBackupLine
set "backupLine=%~1"

if not defined backupLine exit /b

if /I "%backupLine:~0,9%"=="REGISTRY=" (
    set "currentRegistry=%backupLine:~9%"
    exit /b
)

if /I "%backupLine:~0,10%"=="LANGUAGES=" (
    set "savedLanguages=%backupLine:~10%"
    exit /b
)

for /f "tokens=1,2,* delims=|" %%A in ("%backupLine%") do (
    call :RestoreRegistryValue "%currentRegistry%" "%%A" "%%B" "%%C"
)

exit /b


:RestoreRegistryValue
set "restoreRegistry=%~1"
set "valuename=%~2"
set "valuetype=%~3"
set "valuedata=%~4"

if not defined restoreRegistry exit /b

if not defined valuename (
    echo WARNING: Invalid empty registry value name. Skipping.
    exit /b
)

if /I not "%restoreRegistry%"=="HKCU\Control Panel\Mouse" if /I not "%restoreRegistry%"=="HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" (
    echo WARNING: Unsupported registry path "%restoreRegistry%". Skipping.
    exit /b
)

if /I not "%valuetype%"=="REG_SZ" if /I not "%valuetype%"=="REG_EXPAND_SZ" if /I not "%valuetype%"=="REG_DWORD" if /I not "%valuetype%"=="REG_QWORD" if /I not "%valuetype%"=="REG_BINARY" if /I not "%valuetype%"=="REG_MULTI_SZ" (
    echo WARNING: Invalid registry type for "%valuename%": %valuetype%
    echo Skipping this value.
    exit /b
)

reg add "%restoreRegistry%" /v "%valuename%" /t "%valuetype%" /d "%valuedata%" /f >nul 2>&1

if errorlevel 1 (
    echo WARNING: Failed to restore "%valuename%". Skipping.
) else (
    echo Restored: "%restoreRegistry%\%valuename%"
)

exit /b


:Main
set "inputCMD="
cls
title DeAIDS
color 1f
echo.
goto ShowLogo


:ShowLogo
if /I not "%pshWeb%"=="True" (
    echo DeAIDS
    goto ShowLogoDone
)

set "logoFile=%TEMP%\DeAIDS_logo_%random%_%random%.txt"

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -Uri '%pshLogoURL%' -OutFile '%logoFile%' -ErrorAction Stop; exit 0 } catch { exit 1 }" >nul 2>&1

if not exist "%logoFile%" (
    echo DeAIDS
    goto ShowLogoDone
)

for %%A in ("%logoFile%") do set "logoSize=%%~zA"

if "%logoSize%"=="0" (
    del "%logoFile%" >nul 2>&1
    echo DeAIDS
    goto ShowLogoDone
)

type "%logoFile%"
del "%logoFile%" >nul 2>&1


:ShowLogoDone
echo ----------------------------------------------------------
echo ... Welcome!
if /I "%regeditAC%"=="True" (echo + Registry Access AVAILABLE) else (echo - Registry Access UNAVAILABLE)
if /I "%pshWeb%"=="True" (echo + WebRequests Access AVAILABLE) else (echo - WebRequests Access UNAVAILABLE)
if /I "%regeditAC%"=="False" (echo WARNING! Registry editing access is blocked. Nothing here works without it.)
if /I "%regeditAC%"=="False" (goto endScript)
echo .
echo Available Commands:
echo exit - Close the terminal
echo backup.save - Save a backup of these settings
echo backup.load - Load a backup of these settings
echo settings.enhancedpointerprecision.disable - Disable "Enhanced Pointer Precision"
echo settings.enhancedpointerprecision.enable - Enable "Enhanced Pointer Precision"
echo settings.mousesensitivity.edit - Edit mouse sensitivity
echo settings.taskbar.alignment.center - Align the taskbar to the center
echo settings.taskbar.alignment.left - Align the taskbar to the left
echo settings.systemlanguage.edit - Change the Windows user language
echo .
set /p "inputCMD=Input Command > "

if /I "%inputCMD%"=="exit" exit
if /I "%inputCMD%"=="settings.enhancedpointerprecision.disable" goto disEPP
if /I "%inputCMD%"=="settings.enhancedpointerprecision.enable" goto enEPP
if /I "%inputCMD%"=="settings.mousesensitivity.edit" goto MouseSensitivity
if /I "%inputCMD%"=="settings.taskbar.alignment.center" goto tbC
if /I "%inputCMD%"=="settings.taskbar.alignment.left" goto tbL
if /I "%inputCMD%"=="settings.systemlanguage.edit" goto SystemLanguage
if /I "%inputCMD%"=="backup.save" goto BackupCreate
if /I "%inputCMD%"=="backup.load" goto BackupLoad

goto Main


:disEPP
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f >nul 2>&1

RUNDLL32.EXE user32.dll,SystemParametersInfo 0,0,0,0

echo Attempted to disable Enhanced Pointer Precision.
echo A restart or sign-out might be needed to apply the changes.
pause
goto Main


:enEPP
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 1 /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 6 /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 10 /f >nul 2>&1

RUNDLL32.EXE user32.dll,SystemParametersInfo 0,0,0,0

echo Attempted to enable Enhanced Pointer Precision.
echo A restart or sign-out might be needed to apply the changes.
pause
goto Main


:MouseSensitivity
set "mouseSensitivity="

echo.
echo Mouse Sensitivity
echo.
echo Enter a value from 1 to 20.
echo 10 is the normal Windows default.
echo.

set /p "mouseSensitivity=Sensitivity > "

if not defined mouseSensitivity (
    echo.
    echo ERROR: No value entered.
    pause
    goto Main
)

for /f "delims=0123456789" %%A in ("%mouseSensitivity%") do (
    echo.
    echo ERROR: Please enter a whole number from 1 to 20.
    pause
    goto Main
)

set /a mouseSensitivityCheck=%mouseSensitivity% >nul 2>&1

if %mouseSensitivityCheck% LSS 1 (
    echo.
    echo ERROR: Sensitivity must be between 1 and 20.
    pause
    goto Main
)

if %mouseSensitivityCheck% GTR 20 (
    echo.
    echo ERROR: Sensitivity must be between 1 and 20.
    pause
    goto Main
)

reg add "HKCU\Control Panel\Mouse" /v MouseSensitivity /t REG_SZ /d "%mouseSensitivity%" /f >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Failed to change mouse sensitivity.
    pause
    goto Main
)

echo.
echo Mouse sensitivity changed to %mouseSensitivity%.
echo.
echo Refreshing mouse settings...

RUNDLL32.EXE user32.dll,SystemParametersInfo 0,0,0,0

echo Mouse settings refreshed.
pause
goto Main


:tbC
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 1 /f >nul 2>&1

if errorlevel 1 (
    echo ERROR: Failed to change taskbar alignment.
    pause
    goto Main
)

echo Attempting to restart explorer.exe...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul
start explorer.exe

echo Attempted to set taskbar alignment to the center.
pause
goto Main


:tbL
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f >nul 2>&1

if errorlevel 1 (
    echo ERROR: Failed to change taskbar alignment.
    pause
    goto Main
)

echo Attempting to restart explorer.exe...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul
start explorer.exe

echo Attempted to set taskbar alignment to the left.
pause
goto Main


:SystemLanguage
echo.
echo Installed Windows Languages
echo.
echo Loading installed language list...
echo.

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ^
    "$langs = Get-InstalledLanguage; $i = 1; foreach ($lang in $langs) { Write-Host ($i.ToString() + '. ' + $lang.LanguageId + ' - ' + $lang.LanguageName); $i++ }"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to retrieve the installed language list.
    echo Make sure the Windows LanguagePackManagement module is available.
    pause
    goto Main
)

echo.
set "languageChoice="
set /p "languageChoice=Enter the number of the language to use, or 0 to cancel > "

if "%languageChoice%"=="0" goto Main

if not defined languageChoice (
    echo.
    echo ERROR: No selection entered.
    pause
    goto Main
)

for /f "delims=0123456789" %%A in ("%languageChoice%") do (
    echo.
    echo ERROR: Please enter a valid language number.
    pause
    goto Main
)

set /a languageIndex=%languageChoice% >nul 2>&1

set "selectedLanguage="

for /f "tokens=1,2,* delims=|" %%A in ('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$langs = Get-InstalledLanguage; $index = %languageIndex% - 1; if ($index -ge 0 -and $index -lt $langs.Count) { $langs[$index].LanguageId }" 2^>nul') do (
    set "selectedLanguage=%%A"
)

if not defined selectedLanguage (
    echo.
    echo ERROR: Invalid language selection.
    pause
    goto Main
)

echo.
echo Selected language: %selectedLanguage%
echo.
echo Applying language...

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ^
    "$language = '%selectedLanguage%';" ^
    "$list = New-WinUserLanguageList -Language $language;" ^
    "Set-WinUserLanguageList -LanguageList $list -Force;" ^
    "Set-WinUILanguageOverride -Language $language"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to change the Windows language.
    echo Make sure the selected language is installed.
    pause
    goto Main
)

echo.
echo Windows language changed to %selectedLanguage%.
echo.
echo Windows may require you to sign out before the new display language is applied.
pause
goto Main


:endScript
echo.
echo.
echo.
echo Press any key to exit DeAIDS
pause >nul
exit /b
