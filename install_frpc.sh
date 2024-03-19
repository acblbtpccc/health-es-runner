#!/bin/bash

# 检查是否以sudo权限运行脚本
if [ "$(id -u)" != "0" ]; then
   echo "该脚本需要以root权限运行" 1>&2
   exit 1
fi

# 检查参数个数
if [ "$#" -ne 4 ]; then
    echo "使用方法: $0 -u <username> -p <password>"
    exit 1
fi

# 解析命令行参数
while getopts "u:p:" opt; do
  case $opt in
    u) USERNAME=$OPTARG ;;
    p) PASSWORD=$OPTARG ;;
    *) echo "使用方法: $0 -u <username> -p <password>"
       exit 1 ;;
  esac
done

# 检查curl是否安装
if ! command -v curl > /dev/null; then
    echo "curl未安装，正尝试安装curl..."
    apt-get update && apt-get install -y curl
    if [ $? -ne 0 ]; then
        echo "安装curl失败，请手动安装后重试。"
        exit 1
    fi
fi

# 创建/etc/frpc目录
mkdir -p /etc/frpc

# 使用curl下载frpc二进制文件包
curl -u $USERNAME:$PASSWORD -o frpc_linux.tar.gz https://cdn.1f2.net/cdn_auth/frpc/linux

# 如果下载失败，退出脚本
if [ $? -ne 0 ]; then
    echo "下载frpc失败"
    exit 1
fi

# 解压frpc
tar -zxvf frpc_linux.tar.gz

# 如果解压失败，退出脚本
if [ $? -ne 0 ]; then
    echo "解压frpc失败"
    exit 1
fi

# 移动配置文件frpc.ini到/etc/frpc/
mv frpc.ini /etc/frpc/frpc.ini

# 移动服务文件frpc.service到/etc/systemd/system/
mv frpc.service /etc/systemd/system/

# 移动frpc二进制文件到/usr/local/bin/
mv frpc /usr/local/bin/frpc

# 使frpc服务可执行
chmod +x /usr/local/bin/frpc

# 重新加载systemd管理的服务配置
systemctl daemon-reload

# 启用frpc.service自启动
systemctl enable frpc.service

# 启动frpc服务
systemctl start frpc.service

# 检查frpc服务的状态
systemctl status frpc.service