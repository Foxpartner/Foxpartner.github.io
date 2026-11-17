@echo off
title Foxpartner - publish
cd /d "%~dp0"
echo Getting the latest version from GitHub...
git pull --rebase --autostash
if errorlevel 1 goto fail
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\build-data.ps1"
git add -A
git diff --cached --quiet && (echo. & echo Nothing to publish - everything is already online. & goto end)
git commit -m "Update from my computer"
git push
if errorlevel 1 goto fail
echo.
echo Published! The site updates in about 1 minute.
goto end
:fail
echo.
echo Something went wrong - see the messages above.
:end
echo.
pause
