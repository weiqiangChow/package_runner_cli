# 构建 Windows 安装程序
# 注意：生成的 install.bat 需要管理员权限运行（安装到系统目录）

param(
    [switch]$CreateInstaller
)

# 设置控制台输出编码为 UTF-8，解决中文乱码问题
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
    chcp 65001 | Out-Null
} catch {
    # 如果设置失败，继续执行
}

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$Version = (Select-String -Path "$ProjectDir\Cargo.toml" -Pattern '^version = "([^"]+)"').Matches.Groups[1].Value
$AppName = "rps"
$PkgName = "package-runner-cli"
$BuildDir = "$ProjectDir\dist\windows"
$BinDir = "$BuildDir\bin"

Write-Host "[Building] Building Windows release version..." -ForegroundColor Cyan
Set-Location $ProjectDir
cargo build --release

Write-Host "[Packaging] Preparing installation package structure..." -ForegroundColor Cyan
Remove-Item -Path $BuildDir -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

# 复制二进制文件
Copy-Item "$ProjectDir\target\release\rps.exe" "$BinDir\$AppName.exe"

Write-Host "[Scripts] Creating installation scripts..." -ForegroundColor Cyan

# 创建安装脚本
$InstallScript = @"
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ⚠️  需要管理员权限才能安装到系统目录
    echo 请右键点击此脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo 正在安装 rps 到系统目录...

:: 使用系统程序目录（所有用户可访问）
set "INSTALL_DIR=C:\Program Files\Package Runner CLI"
set "BINARY=%INSTALL_DIR%\rps.exe"

:: 创建目录
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: 复制文件
copy /Y "%~dp0bin\rps.exe" "%BINARY%"
if %errorLevel% neq 0 (
    echo ❌ 复制文件失败，请检查权限
    pause
    exit /b 1
)

:: 获取系统 PATH
for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do set "SYSTEM_PATH=%%B"

:: 检查是否已在 PATH 中
echo %SYSTEM_PATH% | findstr /C:"%INSTALL_DIR%" >nul
if %errorLevel% neq 0 (
    echo 正在将安装目录添加到系统 PATH...
    setx PATH "%SYSTEM_PATH%;%INSTALL_DIR%" /M >nul 2>&1
    if !errorLevel! neq 0 (
        echo ⚠️  添加到 PATH 失败，但程序已安装
        echo 请手动将 %INSTALL_DIR% 添加到系统 PATH
    ) else (
        echo ✅ 已添加到系统 PATH
    )
) else (
    echo ✅ 安装目录已在系统 PATH 中
)

echo.
echo ✅ 安装完成！
echo.
echo rps 已安装到: %BINARY%
echo.
echo ⚠️  请重新打开终端窗口以使 PATH 更改生效
echo.
pause
"@

$InstallScript | Out-File -FilePath "$BuildDir\install.bat" -Encoding UTF8

# 创建卸载脚本
$UninstallScript = @"
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ⚠️  需要管理员权限才能卸载
    echo 请右键点击此脚本，选择"以管理员身份运行"
    pause
    exit /b 1
)

echo 正在卸载 rps...

set "INSTALL_DIR=C:\Program Files\Package Runner CLI"
set "BINARY=%INSTALL_DIR%\rps.exe"

if exist "%BINARY%" (
    del "%BINARY%"
    echo ✅ rps 已卸载
    
    :: 尝试从系统 PATH 中移除
    for /f "tokens=2*" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v PATH') do set "SYSTEM_PATH=%%B"
    
    :: 移除安装目录路径
    set "NEW_PATH=!SYSTEM_PATH:%INSTALL_DIR%;=!"
    set "NEW_PATH=!NEW_PATH:;%INSTALL_DIR%=!"
    set "NEW_PATH=!NEW_PATH:%INSTALL_DIR%;=!"
    
    if not "!NEW_PATH!"=="!SYSTEM_PATH!" (
        echo 正在从系统 PATH 中移除...
        setx PATH "!NEW_PATH!" /M >nul 2>&1
        if !errorLevel! equ 0 (
            echo ✅ 已从系统 PATH 中移除
        )
    )
    
    :: 如果目录为空，尝试删除目录
    dir "%INSTALL_DIR%" /b >nul 2>&1
    if %errorLevel% neq 0 (
        rmdir "%INSTALL_DIR%" >nul 2>&1
    )
) else (
    echo ⚠️  rps 未找到，可能已经卸载
)

echo.
echo ⚠️  请重新打开终端窗口以使 PATH 更改生效
echo.
pause
"@

$UninstallScript | Out-File -FilePath "$BuildDir\uninstall.bat" -Encoding UTF8

Write-Host "[Success] Windows installation package ready: $BuildDir" -ForegroundColor Green
Write-Host "   Run install.bat to install" -ForegroundColor Yellow

# 如果安装了 Inno Setup，创建安装程序
if ($CreateInstaller -and (Get-Command "iscc" -ErrorAction SilentlyContinue)) {
    Write-Host "[Installer] Creating Inno Setup installer..." -ForegroundColor Cyan
    
    $InnoScript = @"
[Setup]
AppName=Package Runner CLI
AppVersion=$Version
AppPublisher=Package Runner CLI
DefaultDirName={pf}\Package Runner CLI
DefaultGroupName=Package Runner CLI
OutputDir=$BuildDir
OutputBaseFilename=$PkgName-$Version-setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin

[Files]
Source: "$BinDir\rps.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Uninstall rps"; Filename: "{uninstallexe}"

[Run]
Filename: "{app}\rps.exe"; Description: "Run rps"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
var
  Path: String;
  SystemPath: String;
begin
  if CurStep = ssPostInstall then
  begin
    Path := ExpandConstant('{app}');
    SystemPath := GetEnvironmentString('PATH');
    
    // 检查是否已在 PATH 中
    if Pos(Path, SystemPath) = 0 then
    begin
      // 添加到系统 PATH
      RegWriteStringValue(HKEY_LOCAL_MACHINE, 
        'SYSTEM\CurrentControlSet\Control\Session Manager\Environment', 
        'Path', SystemPath + ';' + Path);
    end;
  end;
end;
"@

    $InnoScriptPath = "$BuildDir\installer.iss"
    $InnoScript | Out-File -FilePath $InnoScriptPath -Encoding UTF8
    
    & iscc $InnoScriptPath
    
    Write-Host "[Success] Installer created: $BuildDir\$PkgName-$Version-setup.exe" -ForegroundColor Green
} elseif ($CreateInstaller) {
    Write-Host "[Warning] Inno Setup Compiler (iscc) not found" -ForegroundColor Yellow
    Write-Host "   Download from https://jrsoftware.org/isinfo.php" -ForegroundColor Yellow
    Write-Host "   Or use install.bat directly" -ForegroundColor Yellow
}

