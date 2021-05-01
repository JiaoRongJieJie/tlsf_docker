#!/usr/bin/env bash

#====================================================
#	System Request:Debian 9+/Ubuntu 18.04+/Centos 7+
#	Author:	Soroke
#	Dscription: tlbb_sf
#====================================================

#设置环境变量
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
stty erase ^?

#配置文件和安装包
DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
CONFIG_PATH="${DIR}/config/config.ini"
TLBB_CONFIG_PATH="${DIR}/config/tlbb"
BILLING_PATH="${DIR}/tools/billing_Release_v1.2.2.zip"
PORTAINER_CN_PATH="${DIR}/tools/Portainer-CN.zip"
GW_PATH="${DIR}/tools/gw.zip"
DOCKER_COMPOSR="${DIR}/tools/docker-compose"

#######color code########
RED="31m"
GREEN="32m"
YELLOW="33m"
BLUE="36m"
FUCHSIA="35m"
# 字体颜色配置
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Blue="\033[36m"
Font="\033[0m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
OK="${Green}[OK]${Font}"
ERROR="${Red}[ERROR]${Font}"

function colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}
function colorEcho_noline(){
    COLOR=$1
    echo -n -e "\033[${COLOR}${@:2}\033[0m"
}

function print_ok() {
  echo -e "${OK} ${Blue} $1 ${Font}"
}

function print_error() {
  echo -e "${ERROR} ${RedBG} $1 ${Font}"
}

#检测执行结果
judge() {
  if [[ 0 -eq $? ]]; then
    print_ok "$1 完成"
    sleep 1
  else
    print_error "$1 失败"
    exit 1
  fi
}

#调用readIni脚本读取配置获取服务安装路径
source ${DIR}/tools/readIni.sh $CONFIG_PATH System LOCAL_DIR
SERVER_DIR=${iniValue}
print_ok "开始创建系统文件夹位置为：" + $SERVER_DIR
mkdir -p $SERVER_DIR

#检测是否为root用户执行
function is_root() {
  if [[ 0 == "$UID" ]]; then
    print_ok "当前用户是 root 用户，开始安装流程"
  else
    print_error "当前用户不是 root 用户，请切换到 root 用户后重新执行脚本"
    exit 1
  fi
}

# 初始化校验服务器时间
function init_clock(){
    \cp -a -r /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    echo 'init system time..'
    ntpdate 0.asia.pool.ntp.org
    print_ok "同步服务器时间"
    hwclock -w
}


#检测并添加虚拟内存
function install_swap() {
	#获取实际内存大小(大于4G不添加虚拟内存)
	mem=`free | awk '($1 == "Mem:"){print $2/1048576}'`
	isBig=`expr $mem \> 4.0`
	if [[ $isBig -eq 0 ]] && [ ! -f /usr/swap/swapfile ];then
		print_ok "当前系统内存为`free -hm | awk -F " " 'NR==2{print $2}'`,开始执行虚拟内存添加"
		mkdir -p /usr/swap && dd if=/dev/zero of=/usr/swap/swapfile bs=100M count=40 && \
		mkswap /usr/swap/swapfile && \
		chmod -R 600 /usr/swap/swapfile && swapon /usr/swap/swapfile && \
		echo "/usr/swap/swapfile swap swap defaults 0 0" >> /etc/fstab
		print_ok "虚拟内存添加4G，总内存提升到 (`free -hm | awk -F " " 'NR==2{print $2}'` + 4.0G) 成功！"
	else
		print_ok "虚拟内存已经提升到 (`free -hm | awk -F " " 'NR==3{print $2}'`)"
	fi
}

#替换debian系统源为阿里源
function replace_debian_sources() {
	#备份源
	mv /etc/apt/sources.list /etc/apt/sources.list.backup
	cat > /etc/apt/sources.list <<EOF
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/debian/ $1 main non-free contrib
#deb-src http://mirrors.aliyun.com/debian/ $1 main non-free contrib
deb http://mirrors.aliyun.com/debian-security $1/updates main
#deb-src http://mirrors.aliyun.com/debian-security $1/updates main
deb http://mirrors.aliyun.com/debian/ $1-updates main non-free contrib
#deb-src http://mirrors.aliyun.com/debian/ $1-updates main non-free contrib
deb http://mirrors.aliyun.com/debian/ $1-backports main non-free contrib
#deb-src http://mirrors.aliyun.com/debian/ $1-backports main non-free contrib
EOF
	apt update -y
	apt upgrade -y
}

#替换ubuntu系统源为阿里源
function replace_ubuntu_sources() {
	cat > /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/ubuntu/ $1 main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $1-backports main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $1-proposed main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $1-security main multiverse restricted universe
deb http://mirrors.aliyun.com/ubuntu/ $1-updates main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $1 main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $1-backports main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $1-proposed main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $1-security main multiverse restricted universe
deb-src http://mirrors.aliyun.com/ubuntu/ $1-updates main multiverse restricted universe
EOF
	apt-get update
}

#安装docker和docker-compose
function install_docker() {
	if [[ "$1" == "centos" ]]; then
		#安装必要的一些系统工具
		sudo yum install -y yum-utils device-mapper-persistent-data lvm2
		#添加软件源信息
		sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
		#更新并安装 Docker-CE
		sudo yum makecache fast
		sudo yum -y install docker-ce docker-compose
		#service docker start
	elif [[ "$1" == "debian" ]]; then
		apt install apt-transport-https ca-certificates curl gnupg2 lsb-release software-properties-common -y
		# 添加软件源的 GPG 密钥
		curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | sudo apt-key add -
		# 向 source.list 中添加 Docker CE 软件源
		add-apt-repository "deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/debian $(lsb_release -cs) stable"
		apt-get update -y
		apt-get install docker-ce docker-compose -y
		
	elif [[ "$1" == "ubuntu" ]]; then
		#statements
		apt-get -y install apt-transport-https ca-certificates curl software-properties-common
		curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
		add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
		apt-get -y update
		apt-get -y install docker-ce docker-compose
	fi
	
	#cp $DOCKER_COMPOSR /usr/bin/ && chmod +x /usr/bin/docker-compose
	systemctl start docker
	#阿里云镜像加速
	sudo mkdir -p /etc/docker
	sudo tee /etc/docker/daemon.json <<-'EOF'
	{
	  "registry-mirrors": ["https://f0tv1cst.mirror.aliyuncs.com"]
	}
	EOF
	sudo systemctl daemon-reload
	sudo systemctl restart docker
}

#检测系统并执行源替换和docker安装
function system_check() {
  source '/etc/os-release'

  if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
    print_ok "当前系统为 Centos ${VERSION_ID} ${VERSION}"
    INS="yum install -y"

    #备份源镜像
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    #更换为清华源
    sed -e 's|^mirrorlist=|#mirrorlist=|g' \
        -e 's|^#baseurl=http://mirror.centos.org|baseurl=https://mirrors.tuna.tsinghua.edu.cn|g' \
        -i.bak \
        /etc/yum.repos.d/CentOS-*.repo
    judge "替换为清华源"
    yum makecache
    $INS crontabs
    
  elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 9 ]]; then
    print_ok "当前系统为 Debian ${VERSION_ID} ${VERSION}"
    INS="apt install -y"
    #替换源
    replace_debian_sources $VERSION_CODENAME
    judge "替换为阿里源"
    $INS cron
  elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 18 ]]; then
    print_ok "当前系统为 Ubuntu ${VERSION_ID} ${UBUNTU_CODENAME}"
    INS="apt install -y"
    #替换源
    replace_ubuntu_sources $VERSION_CODENAME
    judge "替换为阿里源"
    $INS cron
  else
    print_error "当前系统为 ${ID} ${VERSION_ID} 不在支持的系统列表内"
    exit 1
  fi

  if [[ $(grep "nogroup" /etc/group) ]]; then
    cert_group="nogroup"
  fi

  #安装docker和一些所需工具
  docker_version=`docker --version`
  if [[ $docker_version =~ "Docker version" ]]; then
  	print_ok "docker服务已安装"
  else
  	install_docker ${ID}
  	judge "docker和docker-compose安装"
  fi
  
  $INS dbus wget jq git vim zip unzip lsof ntpdate

  # 关闭各类防火墙
  systemctl stop firewalld
  systemctl disable firewalld
  systemctl stop nftables
  systemctl disable nftables
  systemctl stop ufw
  systemctl disable ufw
}


#初始化docker-compose环境变量
function init_env() {
	if [ -f "${DIR}/.env" ];then
		rm -rf ${DIR}/.env
	fi
	
	#source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PORT >/dev/null
	#echo "WEB_MYSQL_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PORT >/dev/null
	echo "TLBB_MYSQL_PORT=${iniValue}" >> ${DIR}/.env
	#source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PASSWORD >/dev/null
	#echo "WEB_MYSQL_PASSWORD=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD >/dev/null
	echo "TLBB_MYSQL_PASSWORD=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server LOGIN_PORT >/dev/null
	echo "LOGIN_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server SERVER_PORT >/dev/null
	echo "SERVER_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server BILLING_PORT >/dev/null
	echo "BILLING_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tomcat PORT >/dev/null
	echo "TOMCAT_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH portainer PORT >/dev/null
	echo "PORTAINER_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tomcat PORT >/dev/null
	echo "TOMCAT_PORT=${iniValue}" >> ${DIR}/.env
	#配置所用2个镜像的名称和版本号
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBB_SERVER_IMAGE_NAME >/dev/null
	echo "TLBB_SERVER_IMAGE_NAME=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBBDB_IMAGE_NAME >/dev/null
	echo "TLBBDB_IMAGE_NAME=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image IMAGE_VERSION >/dev/null
	echo "IMAGE_VERSION=${iniValue}" >> ${DIR}/.env
	
	echo "SERVER_DIR=${SERVER_DIR}" >> ${DIR}/.env
	echo "PORTAINER_CN=${SERVER_DIR}/Portainer-CN" >> ${DIR}/.env
	

}


#解压服务包
function unzip_server() {
	if [ ! -d "$SERVER_DIR/billing" ];then 
		mkdir -p $SERVER_DIR/billing
	fi
	if [ ! -d "$SERVER_DIR/server" ];then 
		mkdir -p $SERVER_DIR/server
	fi
	#billing
	if [[ -f "$SERVER_DIR/billing/billing" ]] && [[ -f "$SERVER_DIR/billing/config.json" ]];then
		print_error "billing服务已存在,不做处理。。。"
	elif [ -f "$BILLING_PATH" ];then
		unzip $BILLING_PATH -d $SERVER_DIR/billing > /dev/null 2>&1
		chmod -R a+x $SERVER_DIR/billing/*
		print_ok "billing服务解压完成。。。"
	else
		print_error ${GREEN} "${BILLING_PATH}文件不存在,请重新下载该项目"
	fi
	
	#tlbb
	if [ -f "/root/tlbb.tar.gz" ]; then
		rm -rf $SERVER_DIR/server/tlbb && tar zxf /root/tlbb.tar.gz -C $SERVER_DIR/server && chown -R root:root $SERVER_DIR/server/tlbb && rm -rf /root/tlbb.tar.gz
		print_ok "服务端文件【/root/tlbb.tar.gz】已经解压成功！！"
	elif [ -f "/root/tlbb.zip" ]; then
		rm -rf $SERVER_DIR/server/tlbb && unzip /root/tlbb.zip -d $SERVER_DIR/server > /dev/null 2>&1 
		chown -R root:root $SERVER_DIR/server/tlbb && rm -rf /root/tlbb.zip
		print_ok "服务端文件【/root/tlbb.zip】已经解压成功！！"
	else
		print_error "服务端文件不存在，或者位置上传错误，请上传至 [/root] 目录下面！！"
	fi
	
	#Portainer-CN 汉化包
	if [[ -f "${SERVER_DIR}/Portainer-CN/index.html" ]] && [[ -d "${SERVER_DIR}/Portainer-CN/fonts" ]];then
		print_ok "Portainer-CN 汉化包已存在,不做处理。。。"
	elif [ -f "${PORTAINER_CN_PATH}" ]; then
		rm -rf $SERVER_DIR/Portainer-CN && unzip $PORTAINER_CN_PATH -d $SERVER_DIR/Portainer-CN > /dev/null 2>&1 
		chown -R root:root $SERVER_DIR/Portainer-CN
		print_ok "Portainer-CN 汉化包解压完成。。。"
	else
		print_error "${PORTAINER_CN_PATH}汉化包文件不存在,请重新下载该项目"
	fi
	
	#官网
	#if [[ -f "${SERVER_DIR}/tomcat/index.html" ]] && [[ -d "${SERVER_DIR}/tomcat/gg" ]];then
	#	colorEcho ${GREEN} "官网文件已存在,不做处理。。。"
	#elif [ -f "${GW_PATH}" ]; then
	#	rm -rf $SERVER_DIR/tomcat/gg $SERVER_DIR/tomcat/index.html $SERVER_DIR/tomcat/static && unzip -d $SERVER_DIR/tomcat/ $GW_PATH > /dev/null 2>&1 
	#	chown -R root:root $SERVER_DIR/tomcat
		
		#修改官网index文件中的游戏名称
	#	source ${DIR}/tools/readIni.sh $CONFIG_PATH game NAME >/dev/null
	#	game_name=${iniValue}
	#	sed -i "s/紫襟天龙/${game_name}/g" $SERVER_DIR/tomcat/index.html
	#	sed -i "s/紫襟天龍/${game_name}/g" $SERVER_DIR/tomcat/index.html
	#	colorEcho ${GREEN} "官网文件解压完成。。。"
	#else
	#	colorEcho ${GREEN} "官网文件文件不存在,请重新下载该项目"
	#fi
}

#修改游戏的列表
function modList() {
	listPath=${DIR}/config/serverlist.txt
	iconv -f=GBK -t=UTF-8 $listPath > /tmp/tmp.txt
	source ${DIR}/tools/readIni.sh $CONFIG_PATH game NAME >/dev/null
	game_name=${iniValue}
	#获取本机真实IP
	IP=`curl -s https://httpbin.org/ip | jq '.origin'`
	game_ip=${IP//\"/}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server LOGIN_PORT >/dev/null
	game_port=${iniValue}
	
	sed -i "s/测试天龙/${game_name}/g" /tmp/tmp.txt
	sed -i "s/127.0.0.1/${game_ip}/g" /tmp/tmp.txt
	sed -i "s/7377/${game_port}/g" /tmp/tmp.txt
	iconv -f=UTF-8 -t=GBK /tmp/tmp.txt > /tmp/serverlist.txt
	#修改列表文件的换行符格式
	sed -i ":a;N;s/\n/HHFTHZW/g;ta" /tmp/serverlist.txt
	sed -i "s/HHFTHZW/\r\n/g" /tmp/serverlist.txt
	
	if [ -d "$SERVER_DIR/tomcat" ];then
		rm -rf $SERVER_DIR/tomcat/serverlist.txt
		cp /tmp/serverlist.txt $SERVER_DIR/tomcat/
		cp ${DIR}/tools/dlpzq.exe $SERVER_DIR/tomcat/
	else
		mkdir -p $SERVER_DIR/tomcat
		cp /tmp/serverlist.txt $SERVER_DIR/tomcat/
		cp ${DIR}/tools/dlpzq.exe $SERVER_DIR/tomcat/
	fi
}


#修改配置文件为指定内容
function modf_config() {

	modList
	#读取所有配置
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD >/dev/null
	tlbbdb_password=${iniValue}
	#source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PASSWORD >/dev/null
	#webdb_password=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PORT >/dev/null
	tlbbdb_port=${iniValue}
	#source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PORT >/dev/null
	#webdb_port=${iniValue}
	
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server LOGIN_PORT >/dev/null
	login_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server SERVER_PORT >/dev/null
	server_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server BILLING_PORT >/dev/null
	billing_port=${iniValue}
	
	#替换billing配置文件
	while read line
	do
	  if [[ "$line" =~ "port" ]] && [[ ! "$line" =~ "db_port" ]];then
		sed -i "s/${line}/\"port\": ${billing_port},/g" $SERVER_DIR/billing/config.json
	  elif [[ "$line" =~ "db_port" ]];then
		sed -i "s/${line}/\"db_port\": 3306,/g" $SERVER_DIR/billing/config.json
	  elif [[ "$line" =~ "db_host" ]];then
		sed -i "s/${line}/\"db_host\": \"tlbbdb\",/g" $SERVER_DIR/billing/config.json
	  elif [[ "$line" =~ "db_password" ]];then
		sed -i "s/${line}/\"db_password\": \"${tlbbdb_password}\",/g" $SERVER_DIR/billing/config.json
	  fi
	done < $SERVER_DIR/billing/config.json
	#修改换行结尾为unix的RF
	sed -i 's/\r//g' $SERVER_DIR/billing/config.json
	
	#解压天龙服务换端配置文件
	tar zxf ${DIR}/config/tlbb_config/ini.tar.gz -C ${DIR}/config/tlbb_config
	
	#替换LoginInfo ServerInfo ShareMemInfo三个文件内容
	if [ ${tlbbdb_password} != "123456" ]; then
		sed -i "s/DBPassword=123456/DBPassword=${tlbbdb_password}/g" ${DIR}/config/tlbb_config/LoginInfo.ini
		sed -i "s/DBPassword=123456/DBPassword=${tlbbdb_password}/g" ${DIR}/config/tlbb_config/ShareMemInfo.ini
	fi
	if [ ${billing_port} != "21818" ]; then
		sed -i "s/Port0=21818/Port0=${billing_port}/g" ${DIR}/config/tlbb_config/ServerInfo.ini
	fi

	if [ "${login_port}" != "13580" ]; then
		sed -i "s/Port0=13580/Port0=${login_port}/g" ${DIR}/config/tlbb_config/ServerInfo.ini
	fi

	if [ "${server_port}" != "15680" ]; then
		sed -i "s/Port0=15680/Port0=${server_port}/g" ${DIR}/config/tlbb_config/ServerInfo.ini
	fi
	
	#获取本机真实IP
	IP=`curl -s https://httpbin.org/ip | jq '.origin'`
	IP=${IP//\"/}
	#替换Server0的角色转发IP为服务器的真实IP
	sed -i "s/IP0=127.123.321.123/IP0=${IP}/g" ${DIR}/config/tlbb_config/ServerInfo.ini
	

	
	#复制修改完成的文件到TLBB服务端
	\cp -rf ${DIR}/config/tlbb_config/*.ini $SERVER_DIR/server/tlbb/Server/Config/
	rm -rf ${DIR}/config/tlbb_config/*.ini
	#修改run脚本
	sed -i 's/exit$/tail -f \/dev\/null/g' $SERVER_DIR/server/tlbb/run.sh
}

#本地生成镜像
function build_image() {

	#替换odbc.ini的数据库端口和root密码配置
	source ${DIR}/tools/readIni.sh -w ${DIR}/docker/server/config/odbc.ini tlbbdb PORT 3306 >/dev/null
	source ${DIR}/tools/readIni.sh -w ${DIR}/docker/server/config/odbc.ini Default PORT 3306 >/dev/null
	
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD >/dev/null
	tlbbdb_password=${iniValue}
	source ${DIR}/tools/readIni.sh -w ${DIR}/docker/server/config/odbc.ini tlbbdb Password ${iniValue} >/dev/null
	source ${DIR}/tools/readIni.sh -w ${DIR}/docker/server/config/odbc.ini Default Password ${iniValue} >/dev/null
	#修改host为docker内部标识
	source ${DIR}/tools/readIni.sh -w ${DIR}/docker/server/config/odbc.ini Default SERVER tlbbdb >/dev/null
	source ${DIR}/tools/readIni.sh -w ${DIR}/docker/server/config/odbc.ini tlbbdb SERVER tlbbdb >/dev/null
	
	#获取镜像的版本号
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image IMAGE_VERSION >/dev/null
	image_version=${iniValue}

	#判断镜像是否存在如果不存在，默认为首次生成，打印生成日志
	tlbb_server_count=`docker image ls tlbb_server |wc -l`
	if [ $tlbb_server_count -ge 2 ];then
	 	#tlbb_server 镜像构建(可能耗时较长)
		source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBB_SERVER_IMAGE_NAME >/dev/null
		docker build -f ${DIR}/docker/server/Dockerfile -t ${iniValue}:${image_version} ${DIR}/docker/server > /dev/null 2>&1 
		#tlbbdb数据库
		source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBBDB_IMAGE_NAME >/dev/null
		docker build -f ${DIR}/docker/tlbbdb/Dockerfile -t ${iniValue}:${image_version} ${DIR}/docker/tlbbdb > /dev/null 2>&1 
		#webdb数据库
		source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image WEBDB_IMAGE_NAME >/dev/null
		docker build -f ${DIR}/docker/webdb/Dockerfile -t ${iniValue}:${image_version} ${DIR}/docker/webdb > /dev/null 2>&1
	else
		#tlbb_server 镜像构建(可能耗时较长)
		source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBB_SERVER_IMAGE_NAME >/dev/null
		docker build -f ${DIR}/docker/server/Dockerfile -t ${iniValue}:${image_version} ${DIR}/docker/server
		#tlbbdb数据库
		source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBBDB_IMAGE_NAME >/dev/null
		docker build -f ${DIR}/docker/tlbbdb/Dockerfile -t ${iniValue}:${image_version} ${DIR}/docker/tlbbdb
		#webdb数据库
		source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image WEBDB_IMAGE_NAME >/dev/null
		docker build -f ${DIR}/docker/webdb/Dockerfile -t ${iniValue}:${image_version} ${DIR}/docker/webdb
	fi

	print_ok "私服服务和数据库两个个镜像构建完成。。。"
}



#检查镜像是否为启动状态
function server_is_start() {
	var=`cd ${DIR} && docker-compose ps server`
	array=(${var// /})
	st=0
	for me in ${array[@]}
	do
	  if [[ "$me" =~ "server" ]] && [[ "$me" =~ "Up" ]];then
			st=1
	  fi
	done
	return $st
}

#获取当前docker-compose，是否启动。返回启动容器数量
function dockerCompose_startCount(){
	#sum=-2
	#oldifs="$IFS"
	#IFS=$'\n'
	#for line in `cd ${DIR} && docker-compose ps`;
	#do
	#	let sum=$sum+1
	#done
	#IFS="$oldifs"
	count=`cd ${DIR} && docker-compose ps | wc -l`
	let count=$count-2
	return $count
}

#启动容器组
function start_dockerCompose() {
	#检查容器组是否已启动
	dockerCompose_startCount
	dc_sc=$?
	if [ $dc_sc -eq 0 ];then
		#启动镜像
		cd ${DIR} && docker-compose up -d 
		print_ok "容器组已启动。。"
	else
		print_ok "容器组已经启动。。"
	fi
	
}

#关闭容器组
function stop_dockerCompose() {
	#检查容器组是否已启动
	dockerCompose_startCount
	dc_sc=$?
	if [ $dc_sc -eq 0 ];then
		print_ok "容器组已经关闭。。"
	else
		#关闭镜像
		cd ${DIR} && docker-compose down
		print_ok "容器组已关闭。。"
	fi
}

#启动天龙服务
function start_tlbb_server(){
	#环境不存在，先初始化环境
	if [ ! -f ${DIR}/.env ];then
		init_env
	fi
	
	#检查容器组是否启动
	dockerCompose_startCount
	dc_sc=$?
	if [ $dc_sc -eq 0 ];then
		start_dockerCompose
	fi

	#检查服务容器是否为停止状态，如果停止先启动
	server_is_start
	st=$?
	if [ $st -eq 0 ];then
		cd ${DIR} && docker-compose start server
	fi
	#启动billing认证
	cd ${DIR} && docker-compose exec -d server /opt/billing up
	#启动私服
	cd ${DIR} && docker-compose exec -d server /bin/bash run.sh
}

#关闭天龙服务
function stop_tlbb_server(){
	if [ -f ${DIR}/.env ];then
		cd ${DIR} && docker-compose stop server
	else
		init_env
		cd ${DIR} && docker-compose stop server
	fi
}


function look_config() {
	#读取所有配置
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD >/dev/null
	tlbbdb_password=${iniValue}
	#source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PASSWORD >/dev/null
	#webdb_password=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PORT >/dev/null
	tlbbdb_port=${iniValue}
	#source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PORT >/dev/null
	#webdb_port=${iniValue}
	
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server LOGIN_PORT >/dev/null
	login_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server SERVER_PORT >/dev/null
	server_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server BILLING_PORT >/dev/null
	billing_port=${iniValue}
	
	source ${DIR}/tools/readIni.sh $CONFIG_PATH portainer PORT >/dev/null
	portainer_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tomcat PORT >/dev/null
	tomcat_port=${iniValue}
	
	#获取本机真实IP
	IP=`curl -s https://httpbin.org/ip | jq '.origin'`
	IP=${IP//\"/}

	echo "====================================="
	echo -e "\e[44m TLSF环境配置 \e[0m"
	echo -e "====================================="
	#echo -e "账号数据库端口: :\e[44m $webdb_port \e[0m "
	#echo -e "账号数据库密码: :\e[44m $webdb_password \e[0m "
	echo -e "数据库IP: :\e[44m $IP \e[0m "
	echo -e "数据库端口: :\e[44m $tlbbdb_port \e[0m "
	echo -e "数据库密码: :\e[44m $tlbbdb_password \e[0m "
	echo -e "Billing端口: :\e[44m $billing_port \e[0m "
	echo -e "登录网关端口: :\e[44m $login_port \e[0m "
	echo -e "游戏网关端口: :\e[44m $server_port \e[0m "
	echo -e "tomcat平台访问地址: :\e[44m http://${IP}:$tomcat_port \e[0m "
	echo -e "portainer平台访问地址: :\e[44m http://${IP}:$portainer_port \e[0m "
	echo -e "登陆器配置列表地址: :\e[44m http://${IP}:$tomcat_port/serverlist.txt \e[0m "
	echo -e "登陆器配置器下载地址: :\e[44m http://${IP}:$tomcat_port/dlpzq.exe \e[0m "
	echo -e "启用网站请把域名解析到IP:${IP}上，然后把网站文件放到\e[44m ${SERVER_DIR}/tomcat/ \e[0m目录里面即可。"
	echo -e "====================================="
	print_ok "服务状态"
	echo "-------------------------------------"
	print_ok "容器组状态: :"
	dockerCompose_startCount
	dc_st=$?
	if [ $dc_st -ge 4 ];then
		echo -e "\e[44m 已启动 \e[0m "
	else
		echo -e "\e[45m 已关闭 \e[0m "
	fi
	
	print_ok "私服服务状态: :"
	server_is_start
	server_st=$?
	if [ $server_st -eq 1 ];then
		echo -e "\e[44m 已启动 \e[0m "
	else
		echo -e "\e[45m 已关闭 \e[0m "
	fi
	echo -e "-------------------------------------"
}

#portainer平台访问地址输出
function print_portainer_url() {
	source ${DIR}/tools/readIni.sh $CONFIG_PATH portainer PORT >/dev/null
	portainer_port=${iniValue}
	#获取本机真实IP
	IP=`curl -s https://httpbin.org/ip | jq '.origin'`
	IP=${IP//\"/}
	echo -e "portainer平台访问地址: :\e[44m http://${IP}:$portainer_port \e[0m "
}

#tomcat平台访问地址输出
function print_tomcat_url() {
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tomcat PORT >/dev/null
	tomcat_port=${iniValue}
	#获取本机真实IP
	IP=`curl -s https://httpbin.org/ip | jq '.origin'`
	IP=${IP//\"/}
	echo -e "tomcat平台访问地址: :\e[44m http://${IP}:$tomcat_port \e[0m "
}

#问询
clear
colorEcho ${GREEN} "##########################天龙私服安装#########################"
colorEcho ${GREEN} "######################Powered by Soroke########################"
colorEcho ${GREEN} "#(1)端口密码配置(未配置使用默认值)                            #"
colorEcho ${GREEN} "#(2)环境安装                                                  #"
colorEcho ${GREEN} "#(3)启动私服(步骤2完成后)                                     #"
colorEcho ${GREEN} "#(4)关闭私服                                                  #"
colorEcho ${GREEN} "#(5)重启私服                                                  #"
colorEcho ${GREEN} "#(6)我要换端                                                  #"
colorEcho ${GREEN} "#(7)修改配置/重新生成                                         #"
colorEcho ${GREEN} "#(8)删除服务且删除项目                                        #"
colorEcho ${GREEN} "#(9)查看配置/服务状态                                         #"
colorEcho ${GREEN} "#(0)退出脚本                                                  #"
colorEcho ${GREEN} "######################Powered by Soroke########################"
colorEcho ${GREEN} "###############################################################"
colorEcho_noline ${GREEN} "输入对应数字回车:"
read chose

case $chose in
	0)
		exit -1
		;;
	1)
		colorEcho ${FUCHSIA} "请修改${DIR}/config/config.ini配置文件" && vim ${DIR}/config/config.ini && clear && sh ${DIR}/run.sh
		;;
	2)
		startTime=`date +%s`
		is_root
		init_clock
		install_swap
		system_check
		build_image
		init_env
		start_dockerCompose
		endTime=`date +%s`
		((outTime=($endTime-$startTime)/60))
		colorEcho_noline ${BLUE} "基础环境安装完毕," && echo -e "总耗时:\e[44m $outTime \e[0m 分钟! "
		;;
	3)
		if [[ -f "$SERVER_DIR/server/tlbb/run.sh" ]]; then
			start_tlbb_server
			colorEcho_noline ${BLUE} "服务端已存在,启动完毕。建议访问portainer平台在线监控启动状态。"
			print_portainer_url
		elif [[ -f "/root/tlbb.tar.gz" ]] || [[ -f "/root/tlbb.zip" ]]; then
			unzip_server
			modf_config
			start_tlbb_server
			colorEcho ${BLUE} "私服启动完毕,建议访问portainer平台在线监控启动状态。"
			look_config
		else 
			colorEcho ${FUCHSIA} "服务端文件不存在，或者位置上传错误，请上传服务端至【/root】目录下再来启动服务" && exit -1
		fi
		;;
	4)
		stop_tlbb_server
		colorEcho ${BLUE} "天龙私服服务已关闭"
		;;
	5)
		stop_tlbb_server
		start_tlbb_server
		colorEcho ${BLUE} "天龙私服服务已重启完成"
		;;
	6)
		if [[ -f "/root/tlbb.tar.gz" ]] || [[ -f "/root/tlbb.zip" ]]; then
			stop_tlbb_server
			unzip_server
			modf_config
			colorEcho_noline ${BLUE} "换端操作执行完毕,是否需要启动新的服务端(0=直接启动,1=不启动):"
			read is_start_server
			case $is_start_server in
				0)
					start_tlbb_server
					colorEcho ${BLUE} "新端服务已启动,建议访问portainer平台在线监控启动状态。"
					;;
				1)
					exit -1
					;;
				*)
					colorEcho ${FUCHSIA} "未知选项" && exit -1
					;;
			esac
			look_config
		else
			colorEcho ${FUCHSIA} "服务端文件不存在，或者位置上传错误，请先上传服务端至【/root】目录下,再来执行换端操作"
		fi
		;;
	7)
		colorEcho_noline ${BLUE} "当前操作会删除所有正在运行的服务并重新生成，确认要继续吗？(0=确认执行,1=返回主菜单):"
		read is_jixu
		case $is_jixu in
			0)
				#环境不存在，先初始化环境
				if [ ! -f ${DIR}/.env ];then
					init_env
				fi
				stop_dockerCompose
				init_env
				build_image
				modf_config
				start_dockerCompose
				start_tlbb_server
				colorEcho ${BLUE} "修改配置已加载完毕,服务已重新启动,建议访问portainer平台在线监控启动状态。"
				look_config
				;;
			1)
				clear && sh ${DIR}/run.sh
				;;
			*)
				colorEcho ${FUCHSIA} "未知选项" && exit -1
				;;
		esac
		;;
	8)
		#环境不存在，先初始化环境
		if [ ! -f ${DIR}/.env ];then
			init_env
		fi
		stop_dockerCompose
		rm -rf ${SERVER_DIR}
		;;
	9)
		look_config
		;;
	*)
		colorEcho ${FUCHSIA} "未知选项" && exit -1
	;;
esac