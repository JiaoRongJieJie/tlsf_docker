FROM centos:6.8
MAINTAINER songrenkun "songrenkun@faxuan.net"
WORKDIR /home/tlbb

COPY ./config/mysql-connector-odbc-5.1.5r1144-7.el6.i686.rpm /tmp/mysql-connector-odbc-5.1.5r1144-7.el6.i686.rpm

#2020年11月30日CentOS官方已经停止对CentOS6版本的维护，修改可用源
RUN sed -i "s|enabled=1|enabled=0|g" /etc/yum/pluginconf.d/fastestmirror.conf && \
        curl -o /etc/yum.repos.d/CentOS-Base.repo https://www.xmpan.com/Centos-6-Vault-Aliyun.repo && \
        yum clean all && yum makecache

RUN yum clean all && \
    yum update -y && \
    yum check && \
    yum install -y libstdc++.i686 unixODBC.i686 && \
    ln -s /usr/lib/libodbc.so /usr/lib/libodbc.so.1 && \
    yum localinstall -y /tmp/mysql-connector-odbc-5.1.5r1144-7.el6.i686.rpm && \
    ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' > /etc/timezone && \
    rm -f /tmp/mysql-connector-odbc-5.1.5r1144-7.el6.i686.rpm

COPY ./config/odbc.ini /etc/odbc.ini

CMD tail -f /dev/null

STOPSIGNAL SIGQUIT
