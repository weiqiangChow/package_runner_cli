#!/bin/bash
# macOS 卸载脚本
# 用于卸载通过 .pkg 安装的 rps 命令

set -e

# 安装包的标识符（与 build-macos.sh 中的 --identifier 一致）
PKG_ID="com.package-runner-cli.rps"

# 二进制文件路径
BINARY_PATH="/usr/local/bin/rps"

echo "🔍 检查安装状态..."

# 方法1：使用 pkgutil 检查安装记录（推荐方法）
if pkgutil --pkgs | grep -q "^${PKG_ID}$"; then
    echo "✅ 找到安装包记录: $PKG_ID"
    
    # 显示安装的文件列表
    echo ""
    echo "📋 已安装的文件:"
    pkgutil --files "$PKG_ID" | sed 's/^/   /'
    
    echo ""
    read -p "是否要卸载 rps? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  正在卸载..."
        
        # 删除安装的文件
        # pkgutil --files 会列出所有安装的文件
        # 我们需要从根目录开始删除
        pkgutil --files "$PKG_ID" | while read -r file; do
            # 跳过目录（只删除文件）
            if [ -f "/$file" ]; then
                echo "   删除: /$file"
                rm -f "/$file"
            fi
        done
        
        # 删除空目录（从最深到最浅）
        pkgutil --files "$PKG_ID" | grep -E "^usr/local/bin$" | while read -r dir; do
            if [ -d "/$dir" ] && [ -z "$(ls -A /$dir 2>/dev/null)" ]; then
                echo "   删除空目录: /$dir"
                rmdir "/$dir" 2>/dev/null || true
            fi
        done
        
        # 删除安装包记录
        pkgutil --forget "$PKG_ID"
        
        echo "✅ 卸载完成！"
    else
        echo "❌ 取消卸载"
        exit 0
    fi

# 方法2：如果找不到安装记录，直接删除文件（简单方法）
elif [ -f "$BINARY_PATH" ]; then
    echo "⚠️  未找到安装包记录，但找到了二进制文件"
    echo "   文件位置: $BINARY_PATH"
    
    read -p "是否要删除文件? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$BINARY_PATH"
        echo "✅ 文件已删除: $BINARY_PATH"
    else
        echo "❌ 取消删除"
        exit 0
    fi
else
    echo "❌ 未找到 rps 安装"
    echo "   检查路径: $BINARY_PATH"
    exit 1
fi

