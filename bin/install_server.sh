#!/bin/bash

export LANG=en_US.UTF-8

set -e
trap 'echo "发生错误。请检查上面的错误消息并重试。"; exit 1' ERR

prompt() {
    local message=$1
    local default_value=$2
    local user_input
    read -e -p "$message" -i "$default_value" user_input
    echo "${user_input:-$default_value}"
}

mypkm() {
    if command -v dnf &> /dev/null; then
        dnf $@
    elif command -v apt &> /dev/null; then
        apt $@
    elif command -v yum &> /dev/null; then
        yum $@
    else
        echo "没有可用包管理器"
        exit 1
    fi
}

echo -e "\033[36m(oﾟvﾟ)ノ\033[0m 欢迎使用一键安装脚本！"
echo -e "\033[36m(oﾟvﾟ)ノ\033[0m 根据下列每个提示\033[36m输入内容并回车\033[0m或\033[36m直接按回车跳过非必填\033[0m即可完成安装！"
echo -e "\033[36m(oﾟvﾟ)ノ\033[0m 当提示出现[y/n]时，请\033[36m输入y或n来选择是或否\033[0m！"
echo -e "\033[36m(oﾟvﾟ)ノ\033[0m 部分选项提供了默认值，确认无误后可直接按回车！"
echo -e "\033[36m(oﾟvﾟ)ノ\033[0m 安装启动成功后，密码仅在容器内，请手动保存客户端连接信息！"
exit 1
if ! command -v docker &> /dev/null
then
    can_ins_docker=$(prompt "未安装Docker，是否安装？[y/n] : " "")
    if [ "$can_ins_docker" == "y" ]; then
        echo -e "\033[32m⁘\033[0m 开始安装 Docker..."
        if command -v dnf &> /dev/null; then
            dnf install docker -y
            sudo systemctl start docker
            sudo systemctl enable docker
        else
            curl -fsSL https://get.docker.com | sh
        fi
        echo -e "\033[32m⁘\033[0m 开始安装 Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose

        if ! command -v docker &> /dev/null
        then
            echo -e "\033[31m⁘\033[0m 安装Docker失败"
            exit 1
        fi
    else
        echo -e "\033[31m⁘\033[0m 请先安装Docker"
        exit 1
    fi
fi

if ! command -v git &> /dev/null
then
    echo "正在安装Git"
    mypkm install -y git-all
fi

if ! command -v crontab &> /dev/null
then
    echo "正在安装cron定时任务管理"
    mypkm install -y cron
    sudo systemctl start cron
    sudo systemctl enable cron
fi

PROJECT_NAME='trojan-docker'

if [ -d "./$PROJECT_NAME" ]; then
    echo -e "当前目录下存在同名目录 \033[0;31m$PROJECT_NAME\033[0m ！如果是此项目，请删除后重试或进入该目录下执行此脚本，反之更换到其他目录执行脚本"
    #exit 1
fi

# 确定脚本位置，如果空则可能是远程脚本
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$DIR" ]; then
    PROJECT_DIR="$(pwd)"
else
    PROJECT_DIR="$(dirname "$DIR")"
fi

echo -e "\033[32m::\033[0m 开始部署项目..."

# 如果不在项目目录下则创建项目
if [[ "$(basename "$DIR")" != "bin" ]] && [[ ! -d "$PROJECT_DIR/.git" ]]; then
    git clone "https://github.com/yimmr/$PROJECT_NAME.git" $PROJECT_NAME
    cd "$PROJECT_NAME"
    PROJECT_DIR=$(pwd)
    DIR="$PROJECT_DIR/bin"
fi

cd $PROJECT_DIR

sudo chmod +x bin/*

domain=$(prompt "[必填]请输入客户端访问域名: " "")

if [ -z "$domain" ]; then
    echo -e "\033[0;31m未提供域名\033[0m "
    exit 1
fi

cf_token=$(prompt "Cloudflare API令牌（或留空回车跳过申请证书）: " "")

if [ -n "$cf_token" ]; then
    ssl_domain=$(prompt "申请证书的域名（多域名用,分隔）: " "$domain")
    ssl_domain=${ssl_domain:-$domain}
fi

if [ -n "$cf_token" ] && [ -n "$ssl_domain" ]; then
    mail=$(prompt "订阅域名通知的邮箱地址（或留空回车拒绝通知）: " "")
    if [ -n "$mail" ]; then
        mail="-m $mail"
    fi
    echo -e "\033[32m::\033[0m 正在申请证书..."
    sudo rm -rf certbot
    ./bin/cert auto -d $ssl_domain -t $cf_token $mail -r false
    echo -e "\033[32m✓\033[0m 申请证书成功！"
else
    echo -e "\033[32m::\033[0m 已跳过申请证书"
fi

args="-h $domain"

ws_disalbed=$(prompt "是否开启WS协议连接？[y/n] : " "y")
if [ "$ws_disalbed" == "n" ]; then
    args="$args --no-ws"
fi

password=$(prompt "请输入客户端访问密码（或留空回车用随机密码）: " "")
if [ -n "$password" ]; then
    args="$args -P $(generate_password)"
fi

./bin/start $args --build