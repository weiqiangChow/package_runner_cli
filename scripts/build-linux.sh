#!/bin/bash
# 构建 Linux 安装包

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION=$(grep '^version' "$PROJECT_DIR/Cargo.toml" | cut -d '"' -f 2)
APP_NAME="rps"
PKG_NAME="package-runner-cli"
BUILD_DIR="$PROJECT_DIR/dist/linux"
BIN_DIR="$BUILD_DIR/usr/local/bin"

echo "🔨 构建 Linux 发布版本..."
cd "$PROJECT_DIR"
cargo build --release

echo "📦 准备安装包结构..."
rm -rf "$BUILD_DIR"
mkdir -p "$BIN_DIR"

# 复制二进制文件
cp "$PROJECT_DIR/target/release/rps" "$BIN_DIR/$APP_NAME"
chmod +x "$BIN_DIR/$APP_NAME"

echo "📝 创建安装脚本..."
cat > "$BUILD_DIR/install.sh" << 'EOF'
#!/bin/bash
set -e

INSTALL_DIR="$HOME/.local/bin"
BINARY="$INSTALL_DIR/rps"

echo "正在安装 rps 到 $INSTALL_DIR..."

# 创建目录
mkdir -p "$INSTALL_DIR"

# 复制文件
cp "$(dirname "$0")/usr/local/bin/rps" "$BINARY"
chmod +x "$BINARY"

# 添加到 PATH（如果不存在）
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo ""
    echo "⚠️  请将以下内容添加到 ~/.bashrc 或 ~/.zshrc:"
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
    echo "然后运行: source ~/.bashrc 或 source ~/.zshrc"
fi

echo "✅ 安装完成！"
echo "rps 已安装到: $BINARY"
EOF

chmod +x "$BUILD_DIR/install.sh"

# 创建卸载脚本
cat > "$BUILD_DIR/uninstall.sh" << 'EOF'
#!/bin/bash
INSTALL_DIR="$HOME/.local/bin"
BINARY="$INSTALL_DIR/rps"

if [ -f "$BINARY" ]; then
    rm "$BINARY"
    echo "✅ rps 已卸载"
else
    echo "⚠️  rps 未找到，可能已经卸载"
fi
EOF

chmod +x "$BUILD_DIR/uninstall.sh"

echo "✅ Linux 安装包准备完成: $BUILD_DIR"
echo "   运行 ./install.sh 进行安装"

