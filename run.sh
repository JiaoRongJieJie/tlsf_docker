#!/bin/bash
# author: soroke

#设置环境变量
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:$PATH
export PATH

#全局属性
DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
CONFIG_PATH="${DIR}/config/config.ini"
TLBB_CONFIG_PATH="${DIR}/config/tlbb"
BILLING_PATH="${DIR}/toole/billing_Release_v1.2.2.zip"
PORTAINER_CN_PATH="${DIR}/toole/Portainer-CN.zip"

#读取配置获取服务安装路径
source ./${DIR}/tools/readIni.sh $CONFIG_PATH System LOCAL_DIR
SERVER_DIR=${iniValue}



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
    echo -n -e "\033[${COLOR}${@:2}\033[0m"
}


#问询
colorEcho ${GREEN} "##########################请操作项目##########################"
colorEcho ${GREEN} "##############################################################"
colorEcho ${GREEN} "#(1)配置端口和数据库(未配置使用默认值)                       #"
colorEcho ${GREEN} "#(2)环境安装                                                 #"
colorEcho ${GREEN} "#(3)启动私服(步骤2完成后,启动前上传服务端到/root目录)        #"
colorEcho ${GREEN} "#(4)关闭私服(步骤2完成后)                                    #"
colorEcho ${GREEN} "#(5)私服重启(步骤2完成后)                                    #"
colorEcho ${GREEN} "#(6)我要换端(步骤2完成后)                                    #"
colorEcho ${GREEN} "#(0)退出脚本                                                 #"
colorEcho ${GREEN} "##############################################################"
colorEcho ${GREEN} "##############################################################"
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
		echo "环境安装"
		init_clock
		replace_install_plugins
		install_docker
		install_swap
		;;
	3)
		echo "启动私服"
		init_env
		unzip_server
		
		;;
	4)
		echo "关闭私服"
		;;
	5)
		echo "私服重启"
		;;
	6)
		echo "执行换端操作"
		init_env
		unzip_server
		
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
	#检查docker docker-compose是否安装
	docker_version=`docker --version`
	dockerCompose_version=`docker-compose --version`
	if [[ $docker_version =~ "Docker version" ]] && [[ $dockerCompose_version =~ "docker-compose version" ]];then
		colorEcho ${GREEN} "docker-ce 和 docker-compose都已安装，不做重复部署"
	elif [[ $docker_version =~ "Docker version" ]] && [[ ! $dockerCompose_version =~ "docker-compose version" ]];then
		colorEcho ${GREEN} "docker-ce已安装, docker-compose未安装，执行docker-compose安装"
		sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
		sudo yum makecache fast && sudo yum -y install docker-compose && sudo systemctl enable docker && sudo systemctl start docker
	elif [[! $docker_version =~ "Docker version" ]] && [[ $dockerCompose_version =~ "docker-compose version" ]];then
		colorEcho ${GREEN} "docker-compose已安装, docker-ce未安装，执行docker-ce安装"
		sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
		sudo yum makecache fast && sudo yum -y install docker-ce && sudo systemctl enable docker && sudo systemctl start docker
	elif [[! $docker_version =~ "Docker version" ]] && [[ ! $dockerCompose_version =~ "docker-compose version" ]];then
		colorEcho ${GREEN} "docker-ce 和 docker-compose都未安装，开始执行安装部署"
	    sudo yum-config-manager --add-repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
		sudo yum makecache fast && sudo yum -y install docker-ce docker-compose && sudo systemctl enable docker && sudo systemctl start docker
	else
		colorEcho ${GREEN} "未知状态，请检查docker的安装情况。。。"
	fi
    #阿里云镜像加速
	sudo mkdir -p /etc/docker
	sudo tee /etc/docker/daemon.json <<-'EOF'
	{
	  "registry-mirrors": ["https://f0tv1cst.mirror.aliyuncs.com"]
	}
	EOF
	sudo systemctl daemon-reload
	sudo systemctl restart docker
	colorEcho ${GREEN} "docker 安装完毕"
}

#添加虚拟内存
function install_swap() {
	#获取实际内存大小(大于4G不添加虚拟内存)
	mem=`free | awk '($1 == "Mem:"){print $2/1048576}'`
	isBig=`expr $mem \> 4.0`
	if [[ $isBig -eq 0 ]] && [ ! -f /usr/swap/swapfile ];then
		colorEcho ${GREEN} "当前系统内存为`free -hm | awk -F " " 'NR==2{print $2}'`,开始执行虚拟内存添加"
		mkdir -p /usr/swap && dd if=/dev/zero of=/usr/swap/swapfile bs=100M count=40 && \
		mkswap /usr/swap/swapfile && \
		chmod -R 600 /usr/swap/swapfile && swapon /usr/swap/swapfile && \
		echo "/usr/swap/swapfile swap swap defaults 0 0" >> /etc/fstab
		colorEcho ${GREEN} "虚拟内存添加4G，总内存提升到 (`free -hm | awk -F " " 'NR==2{print $2}'` + 4.0G) 成功！"
	else
		colorEcho ${GREEN} "虚拟内存已经提升到 (`free -hm | awk -F " " 'NR==3{print $2}'`)"
	fi
}

#初始化docker-compose环境变量
function init_env() {
	if [ -f "${DIR}/.env" ];then
		rm -rf ${DIR}/.env
		mkdir -p ${DIR}/.env
	fi
	
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PORT
	echo "WEB_MYSQL_PORT=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PORT
	echo "TLBB_MYSQL_PORT=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PASSWORD
	echo "WEB_MYSQL_PASSWORD=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD
	echo "TLBB_MYSQL_PASSWORD=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server LOGIN_PORT
	echo "LOGIN_PORT=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server SERVER_PORT
	echo "SERVER_PORT=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server BILLING_PORT
	echo "BILLING_PORT=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH tomcat PORT
	echo "TOMCAT_PORT=${iniValue}" >> ${DIR}/.env
	source ./${DIR}/tools/readIni.sh $CONFIG_PATH portainer PORT
	echo "PORTAINER_PORT=${iniValue}" >> ${DIR}/.env
	
	echo "SERVER_DIR=${SERVER_DIR}" >> ${DIR}/.env
	echo "PORTAINER_CN=${SERVER_DIR}/Portainer-CN" >> ${DIR}/.env
}

#解压服务包
function unzip_server() {

	#billing
	if [[ -f "$SERVER_DIR/billing/billing" ]] && [[ -f "$SERVER_DIR/billing/config.json" ]];then
		colorEcho ${GREEN} "billing服务已存在,不做处理。。。"
	elif [ -f "$BILLING_PATH" ];	
		unzip -d $BILLING_PATH $SERVER_DIR/billing
		chmod -R +x $SERVER_DIR/billing/*
		colorEcho ${GREEN} "billing服务解压完成。。。"
	else
		colorEcho ${GREEN} "${BILLING_PATH}下billing服务文件不存在,请重新下载该项目"
	fi
	
	#tlbb
	if [ -f "/root/tlbb.tar.gz" ]; then
		rm -rf $SERVER_DIR/tlbb && tar zxf /root/tlbb.tar.gz -C $SERVER_DIR/server && chown -R root:root $SERVER_DIR/server/tlbb && rm -rf /root/tlbb.tar.gz
		colorEcho ${GREEN} "服务端文件【/root/tlbb.tar.gz】已经解压成功！！"
	elif [ -f "/root/tlbb.zip" ]; then
		rm -rf $SERVER_DIR/tlbb && unzip /root/tlbb.zip -d $SERVER_DIR/server && chown -R root:root $SERVER_DIR/server/tlbb && rm -rf /root/tlbb.zip
		colorEcho ${GREEN} "服务端文件【/root/tlbb.zip】已经解压成功！！"
	else
		colorEcho ${GREEN} "服务端文件不存在，或者位置上传错误，请上传至 [/root] 目录下面！！"
	fi
	
	#Portainer-CN 汉化包
	if [[ -f "${SERVER_DIR}/Portainer-CN/index.html" ]] && [[ -d "${SERVER_DIR}/Portainer-CN/fonts" ]];then
		colorEcho ${GREEN} "Portainer-CN 汉化包已存在,不做处理。。。"
	elif [ -f "${PORTAINER_CN_PATH}" ]; then
		rm -rf $SERVER_DIR/Portainer-CN && unzip $PORTAINER_CN_PATH -d $SERVER_DIR/Portainer-CN && chown -R root:root $SERVER_DIR/Portainer-CN
		colorEcho ${GREEN} "Portainer-CN 汉化包解压完成。。。"
	else
		colorEcho ${GREEN} "${PORTAINER_CN_PATH}下Portainer-CN汉化包文件不存在,请重新下载该项目"
	fi
}


function build_image() {
	#
}