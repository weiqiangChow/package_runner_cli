# Package Runner CLI

一个用 Rust 编写的终端工具，用于读取当前目录下的 `package.json` 文件，交互式选择并运行 npm/yarn scripts。

## 功能特性

- 📦 自动读取当前目录下的 `package.json` 文件
- 🎯 交互式选择要运行的 script
- 🚀 自动检测并使用 npm 或 yarn
- 🌍 跨平台支持（Windows、macOS、Linux）

## 安装

### 从源码构建

```bash
git clone <repository-url>
cd package_runner_cli
cargo build --release
```

编译后的可执行文件位于 `target/release/rps`（Linux/macOS）或 `target/release/rps.exe`（Windows）。

### 构建可安装的安装包

项目提供了脚本用于构建各平台的可安装包：

#### macOS

```bash
./scripts/build-macos.sh
```

这会生成：
- `.pkg` 安装包：`dist/macos/package-runner-cli-<version>.pkg`（双击安装）
- `.dmg` 磁盘映像：`dist/macos/package-runner-cli-<version>.dmg`（如果安装了 `create-dmg` 或系统支持）

安装后，`rps` 会被安装到 `/usr/local/bin/rps`，可以直接在终端使用。

#### Windows

```powershell
.\scripts\build-windows.ps1
```

或者创建 Inno Setup 安装程序：

```powershell
.\scripts\build-windows.ps1 -CreateInstaller
```

这会生成：
- 安装文件夹：`dist/windows/`（包含 `install.bat` 和 `uninstall.bat`）
- 如果安装了 Inno Setup，还会生成 `.exe` 安装程序

**使用方式：**
- 双击 `install.bat` 进行安装（需要管理员权限）
- 或者双击生成的 `.exe` 安装程序（如果已创建）

安装后，`rps.exe` 会被安装到 `%USERPROFILE%\.cargo\bin\rps.exe`，并自动添加到 PATH。

#### Linux

```bash
./scripts/build-linux.sh
```

这会生成安装文件夹 `dist/linux/`，运行其中的 `install.sh` 进行安装：

```bash
cd dist/linux
./install.sh
```

安装后，`rps` 会被安装到 `~/.local/bin/rps`。

### 使用 Cargo 安装

```bash
cargo install --path .
```

安装后可以使用 `rps` 命令运行工具。

**注意：** `cargo install` 会将二进制文件安装到 Cargo 的 bin 目录：
- **macOS/Linux**: `~/.cargo/bin/rps`
- **Windows**: `%USERPROFILE%\.cargo\bin\rps.exe`

如果安装后无法直接使用 `rps` 命令，请确保 Cargo 的 bin 目录已添加到 PATH 环境变量中：

- **macOS/Linux**: 通常安装 Rust 时会自动配置，如果没有，在 `~/.bashrc` 或 `~/.zshrc` 中添加：
  ```bash
  export PATH="$HOME/.cargo/bin:$PATH"
  ```

- **Windows**: 在系统环境变量中添加 `%USERPROFILE%\.cargo\bin` 到 PATH，或使用 PowerShell：
  ```powershell
  [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:USERPROFILE\.cargo\bin", "User")
  ```
  
  然后重新打开终端窗口。

## 使用方法

在包含 `package.json` 的目录下运行：

```bash
rps
```

或者：

```bash
cargo run
```

工具会：
1. 读取当前目录下的 `package.json` 文件
2. 显示所有可用的 scripts
3. 让你交互式选择一个 script
4. 运行选中的 script

### 命令行选项

```bash
rps                 # 交互式选择并运行 script（默认行为）
rps --uninstall     # 卸载 rps 命令
rps --help          # 显示帮助信息
rps -u              # --uninstall 的简写
rps -h              # --help 的简写
```

### 卸载

**方法 1：使用内置卸载命令（推荐）**

```bash
rps --uninstall
```

这会自动：
- 清理 macOS 安装记录（如果通过 .pkg 安装）
- 删除二进制文件
- 提示需要管理员权限时会自动使用 sudo

**方法 2：使用卸载脚本**

```bash
./scripts/uninstall-macos.sh
```

**方法 3：手动删除**

```bash
# 查找文件位置
which rps

# 删除文件（可能需要 sudo）
sudo rm /usr/local/bin/rps

# 删除安装记录（可选）
sudo pkgutil --forget com.package-runner-cli.rps
```

## 示例

假设你的 `package.json` 包含以下 scripts：

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "test": "vitest"
  }
}
```

运行工具后，你会看到一个交互式菜单：

```
请选择要运行的 script:
❯ dev: vite
  build: tsc && vite build
  test: vitest
```

使用方向键选择，按回车确认运行。

## 依赖

- `serde` / `serde_json`: 用于解析 JSON
- `inquire`: 用于交互式 CLI 界面
- `which`: 用于检测包管理器

## 开发者说明

### 构建要求

- Rust 1.70+
- 各平台特定工具：
  - **macOS**: `pkgbuild`（系统自带），可选 `create-dmg`（`brew install create-dmg`）
  - **Windows**: PowerShell，可选 Inno Setup（用于创建安装程序）
  - **Linux**: bash

### 打包流程

1. 运行对应平台的构建脚本
2. 在 `dist/` 目录下找到生成的安装包
3. 分发安装包给用户

## 系统要求

- Rust 1.70+（仅开发时需要）
- npm 或 yarn（用于实际运行 scripts）

## 许可证

MIT

