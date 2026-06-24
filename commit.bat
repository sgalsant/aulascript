@echo off
setlocal enabledelayedexpansion

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Este directorio no es un repositorio Git.
  exit /b 1
)

for /f "delims=" %%b in ('git branch --show-current') do set "CURRENT_BRANCH=%%b"

if /i not "%CURRENT_BRANCH%"=="main" (
  echo [ERROR] Estas en la rama "%CURRENT_BRANCH%". Cambia a "main" antes de ejecutar este script.
  exit /b 1
)

set "COMMIT_MESSAGE=%~1"
if "%COMMIT_MESSAGE%"=="" set "COMMIT_MESSAGE=chore: update project"

git add -A
if errorlevel 1 exit /b 1

git diff --cached --quiet
if not errorlevel 1 (
  echo [INFO] No hay cambios para commitear.
) else (
  git commit -m "%COMMIT_MESSAGE%"
  if errorlevel 1 exit /b 1
)

git push origin main
if errorlevel 1 exit /b 1

echo [OK] Cambios enviados a origin/main.
