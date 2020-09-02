#!/bin/bash
# author: Soroke

#设置环境变量
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:$PATH
export PATH

#全局属性
DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
CONFIG_PATH="${DIR}/config/config.ini"
TLBB_CONFIG_PATH="${DIR}/config/tlbb"
BILLING_PATH="${DIR}/tools/billing_Release_v1.2.2.zip"
PORTAINER_CN_PATH="${DIR}/tools/Portainer-CN.zip"

#读取配置获取服务安装路径
source ${DIR}/tools/readIni.sh $CONFIG_PATH System LOCAL_DIR
SERVER_DIR=${iniValue}

mkdir -p $SERVER_DIR



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
	fi
	
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PORT
	echo "WEB_MYSQL_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PORT
	echo "TLBB_MYSQL_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PASSWORD
	echo "WEB_MYSQL_PASSWORD=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD
	echo "TLBB_MYSQL_PASSWORD=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server LOGIN_PORT
	echo "LOGIN_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server SERVER_PORT
	echo "SERVER_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server BILLING_PORT
	echo "BILLING_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tomcat PORT
	echo "TOMCAT_PORT=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH portainer PORT
	echo "PORTAINER_PORT=${iniValue}" >> ${DIR}/.env
	#配置所用3个镜像的名称
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBB_SERVER_IMAGE_NAME
	echo "TLBB_SERVER_IMAGE_NAME=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBBDB_IMAGE_NAME
	echo "TLBBDB_IMAGE_NAME=${iniValue}" >> ${DIR}/.env
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image WEBDB_IMAGE_NAME
	echo "WEBDB_IMAGE_NAME=${iniValue}" >> ${DIR}/.env
	
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
		colorEcho ${GREEN} "billing服务已存在,不做处理。。。"
	elif [ -f "$BILLING_PATH" ];then
		unzip $BILLING_PATH -d $SERVER_DIR/billing
		chmod -R a+x $SERVER_DIR/billing/*
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

#修改配置文件为指定内容
function modf_config() {
	#读取所有配置
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD
	tlbbdb_password=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PASSWORD
	webdb_password=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PORT
	tlbbdb_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql WEB_MYSQL_PORT
	webdb_port=${iniValue}
	
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server LOGIN_PORT
	login_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server SERVER_PORT
	server_port=${iniValue}
	source ${DIR}/tools/readIni.sh $CONFIG_PATH tlbb_server BILLING_PORT
	billing_port=${iniValue}
	
	#替换billing配置文件db_host
	while read line
	do
	  if [[ "$line" =~ "port" ]] && [[ ! "$line" =~ "db_port" ]];then
		sed -i "s/${line}/\"port\": ${billing_port},/g" $SERVER_DIR/billing/config.json
	  elif [[ "$line" =~ "db_port" ]];then
		sed -i "s/${line}/\"db_port\": ${webdb_port},/g" $SERVER_DIR/billing/config.json
	  elif [[ "$line" =~ "db_host" ]];then
		sed -i "s/${line}/\"db_host\": \"webdb\",/g" $SERVER_DIR/billing/config.json
	  elif [[ "$line" =~ "db_password" ]];then
		sed -i "s/${line}/\"db_password\": \"${webdb_password}\",/g" $SERVER_DIR/billing/config.json
	  fi
	done < $SERVER_DIR/billing/config.json
	#修改换行结尾为unix的RF
	sed -i 's/\r//g' $SERVER_DIR/billing/config.json
	
	#解压后tlbb服务文件地址
	tlbb_path=$SERVER_DIR/server/tlbb
	#替换ServerInfo.ini
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/ServerInfo.ini Billing Port0 ${billing_port}
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/ServerInfo.ini Server0 Port0 ${server_port}
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/ServerInfo.ini Server1 Port0 ${login_port}
	
	#替换LoginInfo.ini
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/LoginInfo.ini System DBPort ${tlbbdb_port}
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/LoginInfo.ini System DBPassword ${tlbbdb_password}
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/LoginInfo.ini System DBIP tlbbdb
	
	#替换ShareMemInfo.ini
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/ShareMemInfo.ini System DBPort ${tlbbdb_port}
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/ShareMemInfo.ini System DBPassword ${tlbbdb_password}
	source ${DIR}/tools/readIni.sh -w ${tlbb_path}/Server/Config/ShareMemInfo.ini System DBIP tlbbdb
}

#本地生成镜像
function build_image() {

	#替换odbc.ini的数据库端口和root密码配置
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PORT
	tlbbdb_port=${iniValue}
	source ${DIR}/tools/readIni.sh -w $CONFIG_PATH tlbbdb PORT ${tlbbdb_port}
	source ${DIR}/tools/readIni.sh -w $CONFIG_PATH Default PORT ${tlbbdb_port}
	
	source ${DIR}/tools/readIni.sh $CONFIG_PATH mysql TLBB_MYSQL_PASSWORD
	tlbbdb_password=${iniValue}
	source ${DIR}/tools/readIni.sh -w $CONFIG_PATH tlbbdb Password ${tlbbdb_password}
	source ${DIR}/tools/readIni.sh -w $CONFIG_PATH Default Password ${tlbbdb_password}
	#修改host为docker内部标识
	source ${DIR}/tools/readIni.sh -w $CONFIG_PATH Default SERVER tlbbdb
	source ${DIR}/tools/readIni.sh -w $CONFIG_PATH tlbbdb SERVER tlbbdb

	
	#tlbb_server 镜像构建(可能耗时较长)
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBB_SERVER_IMAGE_NAME
	docker build -f ${DIR}/docker/server/Dockerfile -t ${iniValue}:v0.1 ${DIR}/docker/server
	#tlbbdb数据库
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image TLBBDB_IMAGE_NAME
	docker build -f ${DIR}/docker/tlbbdb/Dockerfile -t ${iniValue}:v0.1 ${DIR}/docker/tlbbdb
	#webdb数据库
	source ${DIR}/tools/readIni.sh $CONFIG_PATH docker_image WEBDB_IMAGE_NAME
	docker build -f ${DIR}/docker/webdb/Dockerfile -t ${iniValue}:v0.1 ${DIR}/docker/webdb
	
	
	colorEcho ${GREEN} "私服服务/tlbbsb数据库/webdb数据库三个镜像构建完成。。。"
}

function server_start(){
	#启动镜像
	cd ${DIR} && docker-compose up -d
	#启动billing认证
	cd ${DIR} && docker-compose exec server /bin/bash /opt/billing up -d
	#启动私服
	cd ${DIR} && docker-compose exec server /bin/bash run.sh
}

function server_stop(){
	#停止私服
	cd ${DIR} && docker-compose down
}



#问询
clear
colorEcho ${GREEN} "##########################请操作项目##########################"
colorEcho ${GREEN} "######################Powered by Soroke#######################"
colorEcho ${GREEN} "#(1)配置环境参数(未配置使用默认值)                           #"
colorEcho ${GREEN} "#(2)环境安装                                                 #"
colorEcho ${GREEN} "#(3)启动私服(步骤2完成后)                                    #"
colorEcho ${GREEN} "#(4)关闭私服                                                 #"
colorEcho ${GREEN} "#(5)重启私服                                                 #"
colorEcho ${GREEN} "#(6)我要换端                                                 #"
colorEcho ${GREEN} "#(7)我修改了配置文件(私服已启动成功,需要重新生成配置)        #"
colorEcho ${GREEN} "#(8)监控资源状态                                             #"
colorEcho ${GREEN} "#(0)退出脚本                                                 #"
colorEcho ${GREEN} "######################Powered by Soroke#######################"
colorEcho ${GREEN} "##############################################################"
colorEcho_noline ${GREEN} "输入对应数字回车:"
read chose

case $chose in
	0)
		exit -1
		;;
	1)
		colorEcho ${FUCHSIA} "请修改${DIR}/config/config.ini配置文件" && vim ${DIR}/config/config.ini && clear && ${DIR}/run.sh
		;;
	2)
		colorEcho ${BLUE} "开始执行基础环境安装"
		if [[ -f "/root/tlbb.tar.gz" ]] || [[ -f "/root/tlbb.zip" ]]; then
			init_clock
			replace_install_plugins
			install_docker
			install_swap
			build_image
			colorEcho ${BLUE} "基础环境安装完毕"
		else 
			colorEcho ${FUCHSIA} "服务端文件不存在，或者位置上传错误，请上传至 [/root] 目录下" && exit -1
		fi
		;;
	3)
		init_env
		unzip_server
		modf_config
		server_start
		colorEcho ${BLUE} "私服启动完毕"
		;;
	4)
		server_stop
		colorEcho ${BLUE} "私服已关闭"
		;;
	5)
		server_stop
		server_start
		colorEcho ${BLUE} "私服已重启完成"
		;;
	6)
		if [[ -f "/root/tlbb.tar.gz" ]] || [[ -f "/root/tlbb.zip" ]]; then
			init_env
			unzip_server
			modf_config
			server_start
			colorEcho ${BLUE} "换端操作执行完毕"
		else
			colorEcho ${FUCHSIA} "服务端文件不存在，或者位置上传错误，请先上传至 [/root] 目录下,再来执行换端操作把"
		fi
		;;
	7)
		server_stop
		init_env
		build_image
		modf_config
		server_start
		colorEcho ${BLUE} "新修改配置文件已加载完毕,私服已重启"
		;;
	8)
		colorEcho ${BLUE} "请访问http://${IP}:81 查看状态。"
		;;
	*)
		colorEcho ${FUCHSIA} "未知选项" && exit -1
	;;
esac
