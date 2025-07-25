@echo off

PowerShell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0wsl-post-restart.ps1\"' -Verb RunAs"


