@echo off
setlocal
title SmartPark - Customer, Staff and Admin
cd /d "%~dp0"
where node.exe >nul 2>nul
if errorlevel 1 (
  echo Node.js is required. Install Node.js, then run this file again.
  pause
  exit /b 1
)
node.exe "%~dp0tools\run-smartpark.cjs" %*
set "smartpark_exit=%errorlevel%"
if not "%smartpark_exit%"=="0" (
  echo.
  echo SmartPark could not start. Review the message above and .smartpark\logs.
  pause
)
exit /b %smartpark_exit%
