FROM centos:7
MAINTAINER soroke "soroke@qq.com"
WORKDIR /home/tlbb

COPY ./config/mysql-connector-odbc-8.0.25-1.el7.i686.rpm /tmp/mysql-connector-odbc-8.0.25-1.el7.i686.rpm

RUN yum -y install glibc.i686 libstdc++-4.4.7-4.el6.i686 libstdc++-4.8.5-44.el7.i686 gcc unixODBC.i686 && \
   ln -s /usr/lib64/libz.so.1 /usr/lib/lib && \
   ln -s /usr/lib/libodbc.so /usr/lib/libodbc.so.1 && \
   yum localinstall -y /tmp/mysql-connector-odbc-8.0.25-1.el7.i686.rpm && \
   ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' > /etc/timezone && \
   rm -f /tmp/mysql-connector-odbc-8.0.25-1.el7.i686.rpm

COPY ./config/odbc.ini /etc/odbc.ini

CMD tail -f /dev/null

STOPSIGNAL SIGQUIT
