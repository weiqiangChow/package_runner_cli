#!/bin/bash
# 构建 macOS 安装包
# 这个脚本用于将 Rust 项目打包成 macOS 的 .pkg 安装包和 .dmg 磁盘映像

# set -e: 如果任何命令执行失败（返回非零退出码），脚本立即退出
# 这样可以避免在出错时继续执行，导致更严重的问题
set -e

# 获取脚本文件所在的目录的绝对路径
# ${BASH_SOURCE[0]} 是当前脚本的路径
# dirname 获取目录部分，cd 切换到该目录，pwd 获取绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 获取项目根目录（脚本目录的上一级）
# "$SCRIPT_DIR/.." 表示上一级目录
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# 从 Cargo.toml 文件中提取版本号
# grep '^version' 查找以 "version" 开头的行
# cut -d '"' -f 2 以双引号为分隔符，取第2个字段（版本号）
VERSION=$(grep '^version' "$PROJECT_DIR/Cargo.toml" | cut -d '"' -f 2)

# 应用程序名称（二进制文件名）
APP_NAME="rps"

# 安装包的名称
PKG_NAME="package-runner-cli"

# 构建输出目录，所有生成的文件都会放在这里
BUILD_DIR="$PROJECT_DIR/dist/macos"

# 安装包的根目录，这是 .pkg 安装包的内容结构
PKG_ROOT="$BUILD_DIR/pkgroot"

# 二进制文件的安装目录，对应系统中的 /usr/local/bin
BIN_DIR="$PKG_ROOT/usr/local/bin"

# 输出提示信息，开始构建 Rust 发布版本
echo "🔨 构建 macOS 发布版本..."

# 切换到项目根目录，确保在正确的位置执行 cargo 命令
cd "$PROJECT_DIR"

# 使用 cargo 构建发布版本（优化后的二进制文件）
# --release 标志会进行优化，生成的文件在 target/release/ 目录下
cargo build --release

# 输出提示信息，开始准备安装包结构
echo "📦 准备安装包结构..."

# 删除旧的构建目录（如果存在）
# rm -rf: 递归删除目录及其所有内容，不提示确认
rm -rf "$BUILD_DIR"

# 创建二进制文件目录
# mkdir -p: 递归创建目录，如果目录已存在不会报错
mkdir -p "$BIN_DIR"

# 复制编译好的二进制文件到安装包目录
# 从 target/release/rps 复制到安装包的 usr/local/bin/rps
cp "$PROJECT_DIR/target/release/rps" "$BIN_DIR/$APP_NAME"

# 给二进制文件添加执行权限
# chmod +x: 添加执行权限，这样文件才能被运行
chmod +x "$BIN_DIR/$APP_NAME"

# 输出提示信息，开始创建安装包信息
echo "📝 创建安装包信息..."

# 创建脚本目录，用于存放安装前后的脚本
mkdir -p "$BUILD_DIR/scripts"

# 创建 postinstall 脚本（安装后自动执行的脚本）
# cat > file << 'EOF': 使用 heredoc 语法将内容写入文件
# 'EOF' 中的单引号表示不进行变量替换，保持原样
# 这个脚本会在安装包安装后执行，用于验证安装和提示用户
# 注意：pkgbuild 会自动将文件安装到指定位置，不需要手动复制
cat > "$BUILD_DIR/scripts/postinstall" << 'EOF'
#!/bin/bash
# 验证安装是否成功
# 检查文件是否存在于安装位置
if [ -f "/usr/local/bin/rps" ]; then
    # 输出成功信息
    echo "✅ rps 已成功安装到 /usr/local/bin/"
    echo "💡 如果无法使用 rps 命令，请确保 /usr/local/bin 在您的 PATH 中"
    echo "   可以在 ~/.zshrc 或 ~/.bash_profile 中添加:"
    # \$PATH 中的反斜杠是为了在 heredoc 中保持字面量，不被替换
    echo "   export PATH=\"/usr/local/bin:\$PATH\""
fi
EOF

# 给 postinstall 脚本添加执行权限
chmod +x "$BUILD_DIR/scripts/postinstall"

# 输出提示信息，开始创建 .pkg 安装包
echo "📦 创建 .pkg 安装包..."

# 使用 macOS 的 pkgbuild 工具创建安装包
# 对于普通文件（非 bundle），我们使用 --root 直接指定文件目录
# 不使用 component.plist，让 pkgbuild 自动处理普通文件
# --root: 指定安装包内容的根目录（包含要安装的文件）
# --identifier: 安装包的唯一标识符（类似 Java 的包名），格式通常是反向域名
# --version: 安装包的版本号（从 Cargo.toml 中提取）
# --install-location: 安装位置，"/" 表示根目录
# --scripts: 指定包含安装前后脚本的目录，这些脚本会在安装过程中自动执行
# 最后一个参数：输出的 .pkg 文件路径和名称
pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "com.package-runner-cli.rps" \
    --version "$VERSION" \
    --install-location "/" \
    --scripts "$BUILD_DIR/scripts" \
    "$BUILD_DIR/$PKG_NAME-$VERSION.pkg"

# 输出成功信息，显示生成的安装包路径
echo "✅ macOS 安装包创建完成: $BUILD_DIR/$PKG_NAME-$VERSION.pkg"

# 可选步骤：创建 DMG 磁盘映像文件
# DMG 是 macOS 常用的磁盘映像格式，类似于 Windows 的 ISO 文件

# 检查系统是否安装了创建 DMG 的工具
# command -v: 检查命令是否存在，如果存在返回命令路径，否则返回空
# create-dmg: 第三方工具，功能更强大
# hdiutil: macOS 系统自带工具，也可以创建 DMG
# &> /dev/null: 将标准输出和错误输出都重定向到 /dev/null（丢弃）
if command -v create-dmg &> /dev/null || command -v hdiutil &> /dev/null; then
    # 如果找到了工具，开始创建 DMG
    echo "💿 创建 DMG 文件..."
    
    # DMG 临时目录，用于存放要打包到 DMG 中的文件
    DMG_DIR="$BUILD_DIR/dmg"
    
    # 创建 DMG 目录
    mkdir -p "$DMG_DIR"
    
    # 将 .pkg 文件复制到 DMG 目录中
    cp "$BUILD_DIR/$PKG_NAME-$VERSION.pkg" "$DMG_DIR/"
    
    # 使用 hdiutil 创建 DMG 文件
    # hdiutil: macOS 系统自带的磁盘工具
    # -volname: DMG 挂载后显示的卷名称
    # -srcfolder: 要打包的源文件夹
    # -ov: 如果输出文件已存在，覆盖它
    # -format UDZO: 使用 UDZO 格式（压缩的只读格式）
    # 最后一个参数：输出的 DMG 文件路径
    hdiutil create \
        -volname "$PKG_NAME" \
        -srcfolder "$DMG_DIR" \
        -ov \
        -format UDZO \
        "$BUILD_DIR/$PKG_NAME-$VERSION.dmg"
    
    # 输出成功信息
    echo "✅ DMG 文件创建完成: $BUILD_DIR/$PKG_NAME-$VERSION.dmg"
else
    # 如果没有找到创建 DMG 的工具，输出提示信息
    echo "⚠️  未找到 create-dmg 或 hdiutil，跳过 DMG 创建"
    echo "   可以使用以下命令安装 create-dmg:"
    echo "   brew install create-dmg"
fi

