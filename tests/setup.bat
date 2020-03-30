@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass "& {& '%~dp0setup.ps1' %*}"
