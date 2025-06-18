@echo off

PowerShell -ExecutionPolicy Bypass -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File \"%~dp0wsl.ps1\"' -Verb RunAs"


