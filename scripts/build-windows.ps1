# 构建 Windows 安装程序
# 需要管理员权限运行

param(
    [switch]$CreateInstaller
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$Version = (Select-String -Path "$ProjectDir\Cargo.toml" -Pattern '^version = "([^"]+)"').Matches.Groups[1].Value
$AppName = "rps"
$PkgName = "package-runner-cli"
$BuildDir = "$ProjectDir\dist\windows"
$BinDir = "$BuildDir\bin"

Write-Host "🔨 构建 Windows 发布版本..." -ForegroundColor Cyan
Set-Location $ProjectDir
cargo build --release

Write-Host "📦 准备安装包结构..." -ForegroundColor Cyan
Remove-Item -Path $BuildDir -Recurse -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

# 复制二进制文件
Copy-Item "$ProjectDir\target\release\rps.exe" "$BinDir\$AppName.exe"

Write-Host "📝 创建安装脚本..." -ForegroundColor Cyan

# 创建安装脚本
$InstallScript = @"
@echo off
echo 正在安装 rps 到系统 PATH...

set "INSTALL_DIR=%USERPROFILE%\.cargo\bin"
set "BINARY=%INSTALL_DIR%\rps.exe"

:: 创建目录
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: 复制文件
copy /Y "%~dp0bin\rps.exe" "%BINARY%"

:: 添加到 PATH（如果不存在）
setx PATH "%PATH%;%INSTALL_DIR%" >nul 2>&1

echo.
echo ✅ 安装完成！
echo.
echo rps 已安装到: %BINARY%
echo.
echo ⚠️  请重新打开终端窗口以使 PATH 更改生效
echo.
pause
"@

$InstallScript | Out-File -FilePath "$BuildDir\install.bat" -Encoding ASCII

# 创建卸载脚本
$UninstallScript = @"
@echo off
echo 正在卸载 rps...

set "INSTALL_DIR=%USERPROFILE%\.cargo\bin"
set "BINARY=%INSTALL_DIR%\rps.exe"

if exist "%BINARY%" (
    del "%BINARY%"
    echo ✅ rps 已卸载
) else (
    echo ⚠️  rps 未找到，可能已经卸载
)

echo.
pause
"@

$UninstallScript | Out-File -FilePath "$BuildDir\uninstall.bat" -Encoding ASCII

Write-Host "✅ Windows 安装包准备完成: $BuildDir" -ForegroundColor Green
Write-Host "   运行 install.bat 进行安装" -ForegroundColor Yellow

# 如果安装了 Inno Setup，创建安装程序
if ($CreateInstaller -and (Get-Command "iscc" -ErrorAction SilentlyContinue)) {
    Write-Host "📦 创建 Inno Setup 安装程序..." -ForegroundColor Cyan
    
    $InnoScript = @"
[Setup]
AppName=Package Runner CLI
AppVersion=$Version
AppPublisher=Package Runner CLI
DefaultDirName={userpf}\.cargo\bin
DefaultGroupName=Package Runner CLI
OutputDir=$BuildDir
OutputBaseFilename=$PkgName-$Version-setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest

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
begin
  if CurStep = ssPostInstall then
  begin
    Path := ExpandConstant('{app}');
    RegWriteStringValue(HKEY_CURRENT_USER, 'Environment', 'Path', 
      GetEnvironmentString('PATH') + ';' + Path);
  end;
end;
"@

    $InnoScriptPath = "$BuildDir\installer.iss"
    $InnoScript | Out-File -FilePath $InnoScriptPath -Encoding ASCII
    
    & iscc $InnoScriptPath
    
    Write-Host "✅ 安装程序创建完成: $BuildDir\$PkgName-$Version-setup.exe" -ForegroundColor Green
} elseif ($CreateInstaller) {
    Write-Host "⚠️  未找到 Inno Setup Compiler (iscc)" -ForegroundColor Yellow
    Write-Host "   可以从 https://jrsoftware.org/isinfo.php 下载安装" -ForegroundColor Yellow
    Write-Host "   或者直接使用 install.bat 进行安装" -ForegroundColor Yellow
}

