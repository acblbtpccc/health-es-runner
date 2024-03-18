#!/bin/bash

# 设置变量
REPO_URI="https://github.com/acblbtpccc/health-container.git"
ENV_FILE_URL="http://cdn.1f2.net/auth/health/.env"
LOCAL_ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"
CURL_USER=""
CURL_PASSWORD=""
HOST_PREFIX=""
SHOULD_APPEND_HOSTIP=false

# 从命令行参数中获取用户名和密码
while getopts h:p:u:s flag
do
    case "${flag}" in
        h) HOST_PREFIX=${OPTARG};;
        p) CURL_PASSWORD=${OPTARG};;
        s) SHOULD_APPEND_HOSTIP=true;;
        u) CURL_USER=${OPTARG};;
    esac
done

# 检查用户名和密码是否被提供
if [ -z "$CURL_USER" ] || [ -z "$CURL_PASSWORD" ]; then
    echo "ERROR: username and password is needed for the auth pull .env file, -u <username>，-p <password>."
    exit 1
fi

# 检查git是否安装，如果没有安装，则安装git
if ! command -v git &> /dev/null; then
    echo "INFO: git not installed, trying to install git..."
    sudo apt update && sudo apt install git -y
    if [ $? -ne 0 ]; then
        echo "ERROR: apt install git failed."
        exit 1
    fi
fi

# 检查curl是否安装，如果没有安装，则安装curl
if ! command -v curl &> /dev/null; then
    echo "INFO: cURL not installed, trying to install cURL..."
    sudo apt update && sudo apt install curl -y
    if [ $? -ne 0 ]; then
        echo "ERROR: apt install curl curl failed."
        exit 1
    fi
fi


# 检查是否存在health-container目录，如果存在则删除
if [ -d "health-container" ]; then
    echo "INFO: removing elder health-container... "
    rm -rf health-container
fi

# 使用HTTP克隆GitHub仓库
git clone $REPO_URI
cd health-container

# 检查是否存在docker-compose.yml文件
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "INFO: docker-compose.yml not exist."
    exit 1
fi

# 使用curl下载.env文件，包括用户名和密码
curl -u $CURL_USER:$CURL_PASSWORD -o $LOCAL_ENV_FILE $ENV_FILE_URL

# 检查.env文件是否下载成功
if [ ! -f "$LOCAL_ENV_FILE" ]; then
    echo "INFO: .env download failed."
    exit 1
fi

# 检查.env文件中是否包含api_key
if ! grep -q "ES_API_KEY" "$LOCAL_ENV_FILE"; then
    echo "ERROR: .env not include variable ES_API_KEY"
    exit 1
fi

HOST_IP=$(curl -s 4.ipw.cn)
FORMATTED_HOST_IP=$(echo $HOST_IP | sed 's/\./-/g')
CURRENT_DATE=$(date +%Y%m%d)
UUID_HASH=$(cat /proc/sys/kernel/random/uuid | sha256sum | head -c 12)

# 如果设置了拼接hostip标志，则获取外网 IP 地址并拼接
if $SHOULD_APPEND_HOSTIP; then
    COMBINED_HOSTNAME="${HOST_PREFIX}-${FORMATTED_HOST_IP}-${CURRENT_DATE}-${UUID_HASH}"
else
    COMBINED_HOSTNAME="${HOST_PREFIX}-${CURRENT_DATE}-${UUID_HASH}"
fi

echo "INFO:COMBINED_HOSTNAME: $COMBINED_HOSTNAME"
sed -i "s/^COMBINED_HOSTNAME=.*/COMBINED_HOSTNAME=${COMBINED_HOSTNAME}/" .env

# 使用docker-compose启动服务
docker compose up -d

# 结束脚本
echo "INFO: Health container started."