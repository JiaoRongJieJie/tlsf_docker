# tlsf_docker
## 轻松部署某大型网游天X八部私服
## 仅支持centos7及以上的64位系统，其他系统未测试
## 已测试腾讯云1H2G1M,运行稳定
# 使用说明
### 1、获取所需代码
```shell
yum install -y git vim && git clone https://github.com/Soroke/tlsf_docker.git .tlsf && sh .tlsf/.init && source ~/.bashrc
```
#### 或者
```shell
yum install -y git vim && git clone https://gitee.com/soroke/tlsf_docker.git .tlsf && sh .tlsf/.init && source ~/.bashrc
```
### 2、安装基础环境
##### 执行下面的命令
```shell
tlbb
```

##### 2.1、根据提示,输入1回车 进入修改本次部署的配置，包括（数据库端口、密码、游戏服务的端口以及其他项配置）

```
输入'i'进入编辑模式，编辑配置项,编辑完成后输入':wq'保存配置
```
 ![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_1.png)
##### 2.2、输入2回车,开始安装所有所需环境,等待大约5-10分钟安装完毕 (期间会更新包/安装docker/提示虚拟内存/生成镜像)
    
 ![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_2.png)
### 3、启动服务
##### 执行下面的命令
```shell
tlbb
```
##### 输入3,开始启动服务。(注：如果未上传服务端文件按照提示上传即可;格式仅支持tar.gz和zip)
 ![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run.png)


### 4、其他项说明

#### 4.1 portainer在线监控平台
##### portainer启动有一定的延迟，请在服务启动成功5分钟后访问
##### 1、访问http://IP:PORT, 输入8位数字密码，点击创建用户。
##### 2、然后选择最左侧的LOCAL点击Connect确认进入系统.
##### 3、进入系统后选择local，然后选择左侧的容器，选择名字为“tlsf_server_1”的容器点击进入
##### 4、页面上容器状态下主要使用【统计】【控制台】，其中统计可以查看启动的进程和服务器占用情况。控制台可以直接连接容器执行命令
 ![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/portainer_1.png)
 ![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/portainer_2.png)
#### 4.2 tomcat
安装成功后会提示解压目录,或运行tlbb并选择9查看具体目录。解压完成后直接可以访问