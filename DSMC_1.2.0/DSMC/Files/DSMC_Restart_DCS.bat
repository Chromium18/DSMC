REM this script is done to provide restart automation

@echo off
color 0a
title DSMCyourServer - DCS Server Monitor
set DCS_PATH="C:\Program Files\Eagle Dynamics\DCS World OpenBeta Server\bin\"

:Serverstart

cd /D %DCS_PATH%

start "DSMCyourServer" /min /wait DCS.exe --server --norender -w DSMCyourServer

timeout 40
echo ============
goto Serverstart