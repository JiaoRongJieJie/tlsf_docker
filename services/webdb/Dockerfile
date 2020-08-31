FROM mysql:5.7
MAINTAINER songrenkun "songrenkun@faxuan.net"

# 导入纯净天龙数据库
COPY ./initdb.d/*.sql /docker-entrypoint-initdb.d/

CMD ["mysqld"]

STOPSIGNAL SIGQUIT