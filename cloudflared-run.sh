#!/bin/bash

# cloudflared自动安装和静默启动脚本
# 文件名：cloudflared-run.sh

echo "=========================================="
echo "Cloudflared 自动安装和静默启动脚本"
echo "=========================================="

# 检查是否已安装cloudflared
if ! command -v cloudflared &> /dev/null; then
    echo "❌ 检测到系统中未安装 cloudflared"
    
    # 询问用户是否使用加速下载
    read -p "是否使用国内加速下载？(y/n): " USE_PROXY
    echo ""
    
    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH_TYPE="amd64" ;;
        aarch64|arm64) ARCH_TYPE="arm64" ;;
        armv7l|armhf) ARCH_TYPE="arm" ;;
        *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
    esac
    
    echo "📱 检测到系统架构: $ARCH_TYPE"
    echo "⬇️  正在下载 cloudflared..."
    
    # 根据用户选择使用不同下载源
    if [[ $USE_PROXY =~ [Yy] ]]; then
        echo "🌐 使用国内加速下载源..."
        DOWNLOAD_URL="http://wydc.dpdns.org/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH_TYPE"
    else
        echo "🌍 使用GitHub官方下载源..."
        DOWNLOAD_URL="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH_TYPE"
    fi
    
    # 下载cloudflared
    if ! wget -q "$DOWNLOAD_URL" -O cloudflared; then
        echo "❌ 下载失败，尝试备用下载源..."
        # 如果主下载源失败，尝试备用源
        wget -q "http://wydc.dpdns.org/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH_TYPE" -O cloudflared || {
            echo "❌ 所有下载源均失败，请检查网络连接"
            exit 1
        }
    fi
    
    # 检查下载是否成功
    if [ ! -f "cloudflared" ]; then
        echo "❌ 下载失败，文件不存在"
        exit 1
    fi
    
    # 授予执行权限并安装到用户目录（无需sudo）
    echo "📦 正在安装 cloudflared..."
    chmod +x cloudflared
    
    # 安装到用户本地bin目录（无需root权限）
    USER_BIN_DIR="$HOME/.local/bin"
    mkdir -p "$USER_BIN_DIR"
    mv cloudflared "$USER_BIN_DIR/"
    
    # 添加到用户PATH（如果尚未添加）
    if [[ ":$PATH:" != *":$USER_BIN_DIR:"* ]]; then
        echo 'export PATH="$PATH:'"$USER_BIN_DIR"'"' >> "$HOME/.bashrc"
        export PATH="$PATH:$USER_BIN_DIR"
    fi
    
    echo "✅ cloudflared 安装完成！"
else
    echo "✅ cloudflared 已安装"
fi

echo ""
echo "📡 cloudflared 版本信息："
cloudflared --version || echo "⚠️  无法获取版本信息，但可执行文件存在"

echo ""
echo "=========================================="
echo "🚀 准备启动 Cloudflare Tunnel 服务"
echo "=========================================="

# 从参数获取token命令，如果没有则提示输入
if [ -n "$1" ]; then
    USER_COMMAND="$1"
    echo "使用提供的命令: $USER_COMMAND"
else
    echo "请粘贴完整的 cloudflared tunnel 命令："
    echo "示例: cloudflared tunnel run --token eyJhIjoi..."
    echo ""
    read -p "请输入命令: " USER_COMMAND
fi

# 验证命令格式
if [[ ! "$USER_COMMAND" =~ cloudflared.*tunnel.*run.*token ]]; then
    echo "❌ 错误：命令格式不正确"
    echo "必须包含 'cloudflared tunnel run --token'"
    exit 1
fi

echo ""
echo "正在静默启动 Cloudflare Tunnel 服务..."

# 停止可能正在运行的cloudflared进程
echo "🛑 停止现有 cloudflared 进程..."
pkill -f "cloudflared" 2>/dev/null || true
sleep 2

# 使用nohup静默启动，确保终端关闭后仍然运行
echo "🚀 启动新的 cloudflared 隧道服务..."
echo "执行命令: $USER_COMMAND"
echo ""

# 后台启动
nohup $USER_COMMAND > /dev/null 2>&1 &
START_PID=$!

# 等待几秒让服务启动
sleep 5

# 检查服务是否启动成功
if ps -p $START_PID > /dev/null 2>&1; then
    echo "✅ Cloudflare Tunnel 服务已成功启动！"
    echo "📊 进程ID: $START_PID"
    echo ""
    echo "📝 重要提示："
    echo "1. 服务已在后台静默运行"
    echo "2. 终端关闭后服务将继续运行"
    echo "3. 要停止服务，请运行: pkill -f 'cloudflared'"
    echo "4. 要查看进程状态: ps aux | grep cloudflared"
else
    echo "❌ 启动失败，可能的原因："
    echo "   - Token 已过期或无效"
    echo "   - 网络连接问题"
    echo "   - 端口冲突"
    echo ""
    echo "🔍 请尝试手动运行以下命令查看错误信息："
    echo "$USER_COMMAND"
fi

echo ""
echo "=========================================="
echo "脚本执行完成！"
echo "=========================================="
