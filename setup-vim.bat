@echo off
chcp 65001 >nul 2>&1
echo.
echo   Vim 配置一键部署 (Windows)
echo   如果提示执行策略错误，先运行:
echo   PowerShell -Command "Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
echo.

PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-vim.ps1" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo   安装遇到错误，请查看上方日志。
    echo   如提示执行策略错误，运行:
    echo   PowerShell -Command "Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
)

echo.
pause
