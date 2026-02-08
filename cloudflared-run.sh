#!/bin/bash

# cloudflared自动安装和静默启动脚本
# 文件名：cloudflared-install.sh

echo "=========================================="
echo "Cloudflared 自动安装和静默启动脚本"
echo "=========================================="

# 检查是否已安装cloudflared
if ! command -v cloudflared &> /dev/null; then
    echo "检测到系统中未安装 cloudflared，开始安装..."
    
    # 检测系统架构
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) ARCH_TYPE="amd64" ;;
        aarch64|arm64) ARCH_TYPE="arm64" ;;
        armv7l|armhf) ARCH_TYPE="arm" ;;
        *) echo "不支持的架构: $ARCH"; exit 1 ;;
    esac
    
    echo "检测到系统架构: $ARCH_TYPE"
    
    # 下载最新版cloudflared
    echo "正在下载 cloudflared..."
    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH_TYPE" -O cloudflared
    
    if [ $? -ne 0 ]; then
        echo "下载失败，尝试备用下载源..."
        wget -q "https://wydc.dpdns.org/https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$ARCH_TYPE" -O cloudflared
    fi
    
    # 检查下载是否成功
    if [ ! -f "cloudflared" ]; then
        echo "下载失败，请检查网络连接或手动下载"
        exit 1
    fi
    
    # 授予执行权限并安装到系统路径
    echo "正在安装 cloudflared..."
    chmod +x cloudflared
    sudo mv cloudflared /usr/local/bin/
    
    echo "cloudflared 安装完成！版本信息："
    cloudflared --version
else
    echo "cloudflared 已安装，版本信息："
    cloudflared --version
fi

echo ""
echo "=========================================="
echo "现在需要您提供 cloudflared tunnel 启动命令"
echo "=========================================="
echo "请粘贴完整的命令（包括token）："
echo "示例：cloudflared tunnel run --token eyJhIjoi..."
echo ""

# 读取用户输入的命令
read -p "请输入完整的 cloudflared tunnel 命令: " USER_COMMAND

# 验证输入是否包含必要的关键词
if [[ ! "$USER_COMMAND" =~ cloudflared.*tunnel.*run.*token ]]; then
    echo "错误：输入的命令格式不正确，必须包含 'cloudflared tunnel run --token'"
    echo "请重新运行脚本并输入正确的命令"
    exit 1
fi

echo ""
echo "正在静默启动 cloudflared 隧道服务..."

# 停止可能正在运行的cloudflared进程
echo "停止现有 cloudflared 进程..."
pkill -f "cloudflared" 2>/dev/null || true
sleep 2

# 使用nohup静默启动，确保终端关闭后仍然运行
echo "启动新的 cloudflared 隧道服务..."
nohup $USER_COMMAND > /dev/null 2>&1 &

# 等待几秒让服务启动
sleep 3

# 检查服务是否启动成功
if pgrep -f "cloudflared" > /dev/null; then
    echo "✓ cloudflared 隧道服务已成功启动！"
    echo "进程ID: $(pgrep -f "cloudflared")"
    echo ""
    echo "重要提示："
    echo "1. 服务已在后台静默运行"
    echo "2. 终端关闭后服务将继续运行"
    echo "3. 要停止服务，请运行: pkill -f 'cloudflared'"
    echo "4. 查看日志: tail -f nohup.out"
else
    echo "✗ 启动失败，请检查命令是否正确"
    echo "尝试手动启动以查看错误信息:"
    echo "$USER_COMMAND"
fi

echo ""
echo "脚本执行完成！"
