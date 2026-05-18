@echo off
setlocal

where python >nul 2>nul
if %ERRORLEVEL%==0 (
  python "%~dp0argos-mcp-stdio.py"
) else (
  py -3 "%~dp0argos-mcp-stdio.py"
)
