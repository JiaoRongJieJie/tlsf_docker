#!/bin/bash
# author: soroke

#设置环境变量
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:$PATH
export PATH

#全局属性
CONFIG_PATH="./config/config.ini"
TLBB_CONFIG_PATH="./config/tlbb"


startTime=`date +%s`

#######color code########
RED="31m"
GREEN="32m"
YELLOW="33m"
BLUE="36m"
FUCHSIA="35m"

colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}
colorEcho_noline(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}


#问询
colorEcho ${GREEN} "#####################请操作项目#####################"
colorEcho ${GREEN} "####################################################"
colorEcho ${GREEN} "#(1)配置端口和数据库(未配置使用默认值)             #"
colorEcho ${GREEN} "#(2)安装环境                                       #"
colorEcho ${GREEN} "#(3)我要换端                                       #"
colorEcho ${GREEN} "#(4)我要重启                                       #"
colorEcho ${GREEN} "#(0)退出脚本                                       #"
colorEcho ${GREEN} "####################################################"
colorEcho ${GREEN} "####################################################"
colorEcho_noline ${GREEN} "输入对应数字回车:"
read chose

case $chose in
	0)
		exit -1
		;;
	1)
		colorEcho ${FUCHSIA} "请修改./config/config.ini配置文件" && exit -1
		;;
	2)
		echo "安装"
		;;
	3)
		echo "换端"
		;;
	4)
		echo "重启"
		;;
	*)
		colorEcho ${FUCHSIA} "选项不存在" && exit -1
	;;
esac


# 初始化校验服务器时间
function init_clock(){
    yum -y install ntp
    \cp -a -r /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo 'init system time..'
    ntpdate 0.asia.pool.ntp.org
    hwclock -w
}

# 替换源并安装环境所需组件
function replace_install_plugins() {
	yum install -y wget
    rm -f /var/run/yum.pid
    mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup
    mv /etc/yum.repos.d/epel-testing.repo /etc/yum.repos.d/epel-testing.repo.backup
    wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    wget -O /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
    yum makecache
    PLUGINS="dos2unix epel-release yum-utils wget git vim zip unzip zlib zlib-devel freetype freetype-devel lsof pcre pcre-devel vixie-cron crontabs"
    yum -y install ${PLUGINS} && yum -y update
}

# 配置与安装Docker-ce docker-compose
function install_docker() {
    sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
    sudo yum makecache fast && sudo yum -y install docker-ce docker-compose && sudo systemctl enable docker && sudo systemctl start docker
    #阿里云镜像加速
	sudo mkdir -p /etc/docker
	sudo tee /etc/docker/daemon.json <<-'EOF'
	{
	  "registry-mirrors": ["https://tn82t4d5.mirror.aliyuncs.com"]
	}
	EOF
	sudo systemctl daemon-reload
	sudo systemctl restart docker
}

function install_swap() {
	if [ ! -f /usr/swap/swapfile ]; then
		mkdir -p /usr/swap && dd if=/dev/zero of=/usr/swap/swapfile bs=100M count=40 && \
		mkswap /usr/swap/swapfile && \
		chmod -R 600 /usr/swap/swapfile && swapon /usr/swap/swapfile && \
		echo "/usr/swap/swapfile swap swap defaults 0 0" >> /etc/fstab
		echo -e "\e[44m 虚拟缓存提升到 (`free -hm | awk -F " " 'NR==2{print $2}'` + 4.0G) 成功！ \e[0m"
	else
		echo -e "\e[44m 虚拟缓存已经提升到 (`free -hm | awk -F " " 'NR==3{print $2}'`) \e[0m"
	fi
}

function build_image() {
	#
}