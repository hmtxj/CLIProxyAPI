@echo off
chcp 65001 >nul
echo ====================================
echo   凭证文件修复工具
echo ====================================
echo.

if "%~1"=="" (
    echo 用法: fix_auth.bat ^<原文件路径^> ^<邮箱^>
    echo 示例: fix_auth.bat "composite-rhino.json" "2304917439@qq.com"
    exit /b 1
)

python "%~dp0fix_auth_file.py" %*
