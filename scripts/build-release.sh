#!/bin/bash
# 构建发布版本

set -e

echo "🔨 构建发布版本..."
cargo build --release

echo "✅ 构建完成！"
echo "二进制文件位置: target/release/rps"

