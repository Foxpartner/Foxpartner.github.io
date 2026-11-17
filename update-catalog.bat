@echo off
title Foxpartner - update catalog
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "tools\update-catalog.ps1" %*
echo.
pause
