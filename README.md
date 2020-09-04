# tlsf_docker
## 轻松部署某大型网游天X八部私服
## 仅支持centos7及以上的64位系统，其他系统未测试
## 已测试腾讯云1H2G1M,运行稳定
# 使用说明
### 1、获取所需代码
```bash
yum install -y git vim lrzsz && git clone https://github.com/Soroke/tlsf_docker.git .tlsf && sh .tlsf/.init && source ~/.bashrc
```
#### 或者
```bash
yum install -y git vim lrzsz && git clone https://gitee.com/soroke/tlsf_docker.git .tlsf && sh .tlsf/.init && source ~/.bashrc
```
### 2、安装基础环境
##### 执行下面的命令
```bash
tlbb
```

- 根据提示    输入1回车 进入修改本次部署的配置，包括（数据库端口、密码、游戏服务的端口以及其他项配置）

```bash
输入'i'进入编辑模式，编辑配置项,编辑完成后输入':wq'保存配置
```
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_1.png)
- 输入2回车   开始安装所有所需环境,等待大约5-10分钟安装完毕 (期间会更新包/安装docker/提示虚拟内存/生成镜像)

![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_2.png)
### 3、启动服务
##### 执行下面的命令
```bash
tlbb
```
- 输入3    开始启动服务。(注：如果未上传服务端文件按照提示上传即可;格式仅支持tar.gz和zip)
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_3.png)

### 4、关闭
##### 执行下面的命令
```bash
tlbb
```
- 输入4    执行关闭私服操作
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_4.png)

### 5、重启
##### 执行下面的命令
```bash
tlbb
```
- 输入5    私服服务重启
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_5.png)
 
### 6、换端
##### 执行下面的命令
```bash
tlbb
```
- 输入6    开始执行换端操作。(注：如果未上传服务端文件按照提示上传即可;格式仅支持tar.gz和zip)
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_6.png)
  
### 7、重新生成
##### 执行下面的命令
```bash
tlbb
```
- 输入7    修改配置后或者想要重新生成所有服务和镜像选择此项
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_7.png)
   
### 8、删除
##### 执行下面的命令
```bash
tlbb
```
- 输入8    关闭服务,关闭镜像组、删除服务端和所有页面(如果想要再次运行服务可执行步骤3)
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_8.png)

### 9、查看配置和服务状态
##### 执行下面的命令
```bash
tlbb
```
- 输入9    查看所有配置和服务状态
![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/run_9.png)

### 10、其他项说明

#### 10.1 portainer在线监控平台
- portainer启动有一定的延迟，请在服务启动成功5分钟后访问
- 1、访问http://IP:PORT, 输入8位数字密码，点击创建用户。
- 2、然后选择最左侧的LOCAL点击Connect确认进入系统.
- 3、进入系统后选择local，然后选择左侧的容器，选择名字为“tlsf_server_1”的容器点击进入
- 4、页面上容器状态下主要使用【统计】【控制台】，其中统计可以查看启动的进程和服务器占用情况。控制台可以直接连接容器执行命令
 ![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/portainer_1.png)
 ![image](https://raw.githubusercontent.com/Soroke/tlsf_docker/master/example_image/portainer_2.png)
#### 10.2 tomcat
- 解压官网页面文件到指定目录,解压完成后直接访问http://IP:PORT (IP:部署私服的服务器IP PORT:第一步配置端口,默认为80)
- 解压目录：1、服务启动后会提示解压路径。2、选择9查看解压目录