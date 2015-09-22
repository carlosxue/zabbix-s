#!/bin/bash
#########################################################################
# File Name: zabbixserver.sh
# Author: @oneas1a
# Email: carlosxue@oneas1a.com
# Version:
# Created Time: Tus Sep 22 00:00:00 CST 2015
#########################################################################
 
#########################################################################
##本脚本的作用：
##    在一个全新的CentOS系统上编译安装nginx1.9.4 cmake3.3.2 php5.6.13 
##    MariaDB10.1.7 zabbix2.4.6 或者 安装zabbix Agent端
##
##    实现一个基于LNMP环境的zabbix server端配置 或zabbix agent端配置
#########################################################################
 
nginxDir="/usr/local/nginx/"
phpDir="/usr/local/php/"
mysqlDir="/usr/local/mysql/"
mysqlPass="@oneas1a"
zbmysqlName="zabbix"
zbmysqlUser="zabbixuser"
zbmysqlPass="zabbixpass"
zbserverconf="/etc/zabbix/zabbix_server.conf"
 
 
##下面的源码下载地址请勿在不理解脚本的前提下做修改
nginxUrl="http://nginx.org/download/nginx-1.9.4.tar.gz"
phpUrl="http://cn2.php.net/get/php-5.6.13.tar.gz/from/this/mirror"
cmakeUrl="http://www.cmake.org/files/v3.3/cmake-3.3.2.tar.gz"
mariadbUrl="https://downloads.mariadb.org/interstitial/mariadb-10.1.7/source/mariadb-10.1.7.tar.gz"
 
#检测是否是root用户执行脚本
[ $(id -u) != "0" ] && echo "Error: You must be root to run this script" && exit 1 
if ! which whiptail &>/dev/null; then yum install newt;fi
if ! which wget &>/dev/null; then yum install wget;fi
 
install_nginx() {
    #添加nginx的系统用户和系统组
    findUidGid nginx
    #下载 解压 编译 安装nginx
    cd && [ ! -f nginx-1.9.4.tar.gz ] && downFile "$1" "nginx-1.9.4.tar.gz" "Dwonload Nginx 1.9.4"
    tar xf nginx-1.9.4.tar.gz 
    cd nginx-1.9.4
    ./configure \
--prefix=$nginxDir \
--error-log-path=/home/wwwlogs/nginx/error.log \
--http-log-path=/home/wwwlogs/nginx/access.log \
--pid-path=/var/run/nginx/nginx.pid  \
--lock-path=/var/lock/nginx.lock \
--user=nginx \
--group=nginx \
--with-http_ssl_module \
--with-http_flv_module \
--with-http_spdy_module \
--with-http_gzip_static_module \
--with-http_stub_status_module \
--http-client-body-temp-path=${nginxDir}client/ \
--http-proxy-temp-path=${nginxDir}proxy/ \
--http-fastcgi-temp-path=${nginxDir}fcgi/ \
--http-uwsgi-temp-path=${nginxDir}uwsgi \
--http-scgi-temp-path=${nginxDir}scgi \
--with-pcre
    make -j $(awk '{if($1=="processor"){i++}}END{print i}' /proc/cpuinfo) && make install
    [ $? != 0 ] && exit 1
    sed -i '$i\\t include vhost/*.conf;' ${nginxDir}conf/nginx.conf
    mkdir ${nginxDir}conf/vhost/
    #设置环境变量
    echo "export PATH=${nginxDir}sbin:\$PATH" > /etc/profile.d/nginx194.sh
    . /etc/profile.d/nginx194.sh
    #下载nginx启动脚本和设置开机启动
    downFile "https://github.com/carlosxue/zabbix-s/blob/master/script-init-centos6" "/etc/rc.d/init.d/nginx" "Download Nginx Init File"
    chmod +x /etc/rc.d/init.d/nginx
    chkconfig --add nginx
    chkconfig nginx on
}
 
install_php() {
    #下载 解压 编译 安装PHP5.6.13
    cd && [ ! -f php-5.6.13.tar.gz ] && downFile "$1" "php-5.6.13.tar.gz" "Download PHP 5.6.13" 
    tar xf php-5.6.13.tar.gz 
    cd php-5.6.13
    ./configure  --prefix=${phpDir} \
--with-config-file-path=${phpDir}etc \
--with-bz2 \
--with-curl \
--enable-ftp \
--enable-dom \
--enable-xml \
--enable-fpm \
--enable-ipv6 \
--enable-bcmath \
--enable-sockets \
--enable-mbstring \
--enable-calendar \
--enable-gd-native-ttf \
--with-gd \
--with-zlib \
--with-gettext \
--with-libdir=lib64 \
--with-mysql=mysqlnd \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--with-png-dir=/usr/local \
--with-jpeg-dir=/usr/local \
--with-iconv-dir=/usr/local \
--with-libxml-dir=/usr/local \
--with-freetype-dir=/usr/local
    make -j $(awk '{if($1=="processor"){i++}}END{print i}' /proc/cpuinfo) && make install
    [ $? != 0 ] && exit 1
    #设置环境变量
    echo "export PATH=${phpDir}bin:\$PATH" > /etc/profile.d/php5613.sh
    . /etc/profile.d/php5613.sh
    #检测php是否安装成功
    [ -z $(which php) ] && exit 1
    #拷贝配置文件
    cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
    cp php.ini-production ${phpDir}etc/php.ini
    cp ${phpDir}etc/php-fpm.conf.default ${phpDir}etc/php-fpm.conf
    #修改配置文件
    sed -ri 's/^(max_execution_time = ).*/\1300/' ${phpDir}etc/php.ini
    sed -ri 's/^(memory_limit = ).*/\1128M/' ${phpDir}etc/php.ini
    sed -ri 's/^(post_max_size = ).*/\116M/' ${phpDir}etc/php.ini
    sed -ri 's/^(upload_max_filesize = ).*/\12M/' ${phpDir}etc/php.ini
    sed -ri 's/^(max_input_time = ).*/\1300/' ${phpDir}etc/php.ini
    sed -ri '/date.timezone =/a date.timezone = PRC' ${phpDir}etc/php.ini
    #添加启动项
    chmod +x /etc/init.d/php-fpm
    chkconfig --add php-fpm
    chkconfig php-fpm on
    #启动php-fpm 且检测是否启动成功
    service php-fpm restart
    ss -tnl | grep ':9000' &>/dev/null
    [ $? != 0 ] && exit 1
}
 
install_cmake() {
    #下载 解压 编译 安装cmake
    cd && [ ! -f cmake-3.3.2.tar.gz ] && downFile "$1" "cmake-3.3.2.tar.gz" "Download CMAKE 3.3.2"
    tar xf cmake-3.3.2.tar.gz
    cd cmake-3.3.2
    ./configure --prefix=/usr/local/cmake --mandir=/usr/local/share/man --datadir=/usr/share/ --docdir=/usr/share/doc --no-system-libs --system-curl --no-system-libarchive --system-bzip2 --system-expat
    make -j $(awk '{if($1=="processor"){i++}}END{print i}' /proc/cpuinfo) && make install
    [ $? != 0 ] && exit 1
    #检测cmake是否ok，不ok 退出脚本
    [ $? != 0 ] && exit 1
    echo "export PATH=/usr/local/cmake/bin:\$PATH" > /etc/profile.d/cmake332.sh
    . /etc/profile.d/cmake332.sh
}
 
install_mariadb() {
    #添加mysql系统用户和系统组
    findUidGid mysql
    #下载 解压 编译 安装MariaDB
    cd && [ ! -f mariadb-10.1.7.tar.gz ] && downFile "$1" "mariadb-10.1.7.tar.gz" "Download MariaDB 10.1.7"
    [ -f mariadb-10.1.7 ] && rm -rf mariadb-10.1.7
    tar xf mariadb-10.1.7.tar.gz && cd mariadb-10.1.7
    cmake . -DCMAKE_INSTALL_PREFIX=$mysqlDir \
-DMYSQL_DATADIR=${mysqlDir}data/ \
-DWITH_SSL=system \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_SPHINX_STORAGE_ENGINE=1 \
-DWITH_ARIA_STORAGE_ENGINE=1 \
-DWITH_XTRADB_STORAGE_ENGINE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DWITH_FEDERATEDX_STORAGE_ENGINE=1 \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
-DENABLED_LOCAL_INFILE=1 \
-DWITH_EMBEDDED_SERVER=1 \
-DWITH_READLINE=1 \
-DWITH_ZLIB=system \
-DWITH_LIBWRAP=0 \
-DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
-DWITH_EXTRA_CHARSETS=all \
-DEXTRA_CHARSETS=all \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci
    make -j $(awk '{if($1=="processor"){i++}}END{print i}' /proc/cpuinfo) && make install
    [ $? != 0 ] && exit 1
    #重置编译
    #make clean
    #rm CMakeCache.txt
 
    #设置启动脚本
    cp ${mysqlDir}support-files/mysql.server /etc/rc.d/init.d/mysqld
    chmod +x /etc/rc.d/init.d/mysqld
    #配置配置文件
    \cp ${mysqlDir}support-files/my-large.cnf /etc/my.cnf
    sed -i "/query_cache_size/a datadir = ${mysqlDir}data/" /etc/my.cnf
    #初始化MariaDB
    cd ${mysqlDir}
    ${mysqlDir}scripts/mysql_install_db --user=mysql --datadir=${mysqlDir}data/
    #设置MariaDB的环境变量
    echo "export PATH=${mysqlDir}bin:\$PATH" > /etc/profile.d/mariadb1017.sh
    . /etc/profile.d/mariadb1017.sh
    chkconfig --add mysqld
    chkconfig mysqld on
    #启动MariaDB
    service mysqld start
    #检测MariaDB启动正常否，不正常就退出脚本
    ss -tnl | grep ':3306' &>/dev/null && [ $? != 0 ] && exit 1
 
    #删除MariaDB中的空账户和设置root帐户密码
    mysql <<< "USE mysql;
update user set password=PASSWORD('$mysqlPass') WHERE USER='root';
DELETE FROM user WHERE User='';
SELECT USER,PASSWORD,HOST FROM user;
FLUSH PRIVILEGES;"
 
    #打印mysql status信息，不成功则退出脚本
    mysql -uroot -p$mysqlPass <<< status && [ $? != 0 ] && exit 1
     
    #添加zabbix的数据库和用户
    mysql -uroot -p$mysqlPass <<< "USE mysql;
CREATE DATABASE $zbmysqlName CHARACTER SET utf8;
GRANT ALL on $zbmysqlName.* TO '$zbmysqlUser'@'localhost' IDENTIFIED BY '$zbmysqlPass';
GRANT ALL on $zbmysqlName.* TO '$zbmysqlUser'@'127.0.0.1' IDENTIFIED BY '$zbmysqlPass';
GRANT ALL on $zbmysqlName.* TO '$zbmysqlUser'@'::1' IDENTIFIED BY '$zbmysqlPass';
GRANT ALL on $zbmysqlName.* TO '$zbmysqlUser'@'192.168.%.%' IDENTIFIED BY '$zbmysqlPass';
GRANT ALL on $zbmysqlName.* TO '$zbmysqlUser'@'172.16.%.%' IDENTIFIED BY '$zbmysqlPass';
GRANT ALL on $zbmysqlName.* TO '$zbmysqlUser'@'$(hostname)' IDENTIFIED BY '$zbmysqlPass';
SELECT USER,PASSWORD,HOST FROM user;
FLUSH PRIVILEGES;"
}
 
install_JDK() {
    if [ "64" = "$(getconf LONG_BIT)" ]; then
        downFile "http://www.05hd.com/wp-content/uploads/2014/12/jdk-8u25-linux-x64.rpm" "jdk-8u25-linux-x64.rpm" "Download JDK 8u25 RPM"
        rpm -ivh jdk-8u25-linux-x64.rpm && [ $? != 0 ] && exit 1
    elif [ "32" = "$(getconf LONG_BIT)" ]; then
        downFile "http://www.05hd.com/wp-content/uploads/2014/12/jdk-8u25-linux-i586.rpm" "jdk-8u25-linux-i586.rpm" "Download JDK 8u25 RPM"
        rpm -ivh jdk-8u25-linux-i586.rpm && [ $? != 0 ] && exit 1
    else
        echo "I don't know your OS BIT" && exit 1
    fi
    cat > /etc/profile.d/java.sh << EOF
JAVA_HOME=/usr/java/latest
PATH=\$JAVA_HOME/bin:\$PATH
export JAVA_HOME PATH
EOF
    source /etc/profile.d/java.sh
}
 
install_zabbix() {
    #添加zabbix系统用户和系统组
    findUidGid zabbix
    #让zabbix支持使用jmx方式监控tomcat，安装JDK环境
    install_JDK
    #下载 解压 编译 安装zabbix
    cd && [ ! -f zabbix-2.4.6.tar.gz ] && downFile "$1" "zabbix-2.4.6.tar.gz" "Download Zabbix 2.4.6"
    [ ! -f zabbix-2.4.6 ] && tar xf zabbix-2.4.6.tar.gz 
    cd zabbix-2.4.6
    ./configure --prefix=/usr/local/zabbix/ \
--sysconfdir=$(dirname $zbserverconf) \
--enable-server \
--enable-agent \
--enable-ipv6 \
--enable-java \
--with-mysql=$(find ${mysqlDir} -name "mysql_config") \
--with-net-snmp \
--with-libcurl \
--with-openipmi \
--with-libxml2
    make -j $(awk '{if($1=="processor"){i++}}END{print i}' /proc/cpuinfo) && make install
    [ $? != 0 ] && exit 1
    echo "export PATH=/usr/local/zabbix/sbin:\$PATH" > /etc/profile.d/zabbix246.sh
    . /etc/profile.d/zabbix246.sh
    zabbixsrcDir="/root/zabbix-2.4.6"
    . /etc/profile.d/mariadb1017.sh
    for i in schema.sql images.sql data.sql; do mysql -uroot -p$mysqlPass $zbmysqlName < ${zabbixsrcDir}/database/mysql/$i;done
    #[ -f /etc/zabbix ] || mkdir /etc/zabbix/
    zbserverconf="/etc/zabbix/zabbix_server.conf"
    cp ${zabbixsrcDir}/conf/zabbix_server.conf /etc/zabbix/
    sed -ri /^DBName=/d $zbserverconf
    sed -ri /^DBUser=/d $zbserverconf
    sed -ri /^DBPassword=/d $zbserverconf
    sed -ri "s/(DBName=)/&\n\1$zbmysqlName/" $zbserverconf
    sed -ri "s/(DBUser=)/&\n\1$zbmysqlUser/" $zbserverconf
    sed -ri "s/.*(DBPassword=).{0,}/&\n\1$zbmysqlPass/" $zbserverconf
    sed -i '/JavaGateway=/a JavaGateway=127.0.0.1\nJavaGatewayPort=10052\nStartJavaPollers=5' $zbserverconf
    sed -i '/LISTEN_IP="0.0.0.0"/a LISTEN_IP="0.0.0.0"' /usr/local/zabbix/sbin/zabbix_java/settings.sh
    sed -i '/LISTEN_PORT=10052/a LISTEN_PORT=10052' /usr/local/zabbix/sbin/zabbix_java/settings.sh
    sed -i '/START_POLLERS=5/a START_POLLERS=5' /usr/local/zabbix/sbin/zabbix_java/settings.sh
    #CATALINA_OPTS="-Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.port=12345 -Djava.rmi.server.hostname=192.168.0.102"
 
    ln -s ${mysqlDir}lib/libmysqlclient.so.18 /usr/lib
    ln -s ${mysqlDir}lib/libmysqlclient.so.18 /usr/lib64
    ldconfig
    cat >> /etc/services << EOF
zabbix-agent    10050/tcp       #ZabbixAgent
zabbix-agent    10050/udp       #Zabbix Agent
zabbix-trapper  10051/tcp       #ZabbixTrapper
zabbix-trapper  10051/udp       #Zabbix Trapper
EOF
 
    mkdir -p /home/wwwroot/zabaix
    sed -i '/zh_CN/{s/false/true/}' ${zabbixsrcDir}/frontends/php/include/locales.inc.php
    sed -i 's/DejaVuSans/simkai/g' ${zabbixsrcDir}/frontends/php/include/defines.inc.php
    cp -rp ${zabbixsrcDir}/frontends/php/* /home/wwwroot/zabaix/
    downFile "http://www.05hd.com/wp-content/uploads/2014/12/simkai.ttf" "/home/wwwroot/zabaix/fonts/simkai.ttf" "Download Simkai.TTF"
    cp -rp ${zabbixsrcDir}/misc/init.d/fedora/core/zabbix_server /etc/rc.d/init.d/
    cp -rp ${zabbixsrcDir}/misc/init.d/fedora/core/zabbix_agentd /etc/rc.d/init.d/
    sed -i 's@BASEDIR=/usr/local@&/zabbix@' /etc/rc.d/init.d/zabbix_server
    sed -i 's@BASEDIR=/usr/local@&/zabbix@' /etc/rc.d/init.d/zabbix_agentd
    chkconfig --add zabbix_server
    chkconfig --add zabbix_agentd
    chkconfig zabbix_server on
    chkconfig zabbix_agentd on
    service zabbix_server start
    service zabbix_agentd start
    echo -e "server {
listen       88;
\tserver_name www.abc.com;
\taccess_log  /home/wwwlogs/nginx/www.abc.com.access.log  combined;
 
\tindex index.html index.php index.html;
\troot /home/wwwroot/zabaix/;
 
\tlocation /
\t{
\t\ttry_files \$uri \$uri/ /index.php?\$args;
\t}
 
\tlocation ~ ^(.+.php)(.*)\$ {
\t\tfastcgi_split_path_info ^(.+.php)(.*)\$;
\t\tinclude fastcgi.conf;
\t\tfastcgi_pass  127.0.0.1:9000;
\t\tfastcgi_index index.php;
\t\tfastcgi_param  PATH_INFO          \$fastcgi_path_info;
\t\t}
\t}" > ${nginxDir}conf/vhost/zabbix.conf
    service nginx start
}
 
install_zabbix_agent() {
    findUidGid zabbix
    cd && [ ! -f zabbix-2.4.6.tar.gz ] && downFile "$1" "zabbix-2.4.6.tar.gz" "Download Zabbix 2.4.6"
    [ ! -f zabbix-2.4.6 ] && tar xf zabbix-2.4.6.tar.gz 
    cd zabbix-2.4.6
    ./configure --prefix=/usr/local/zabbix \
    --sysconfdir=$(dirname $zbserverconf) \
    --enable-agent \
    --enable-ipv6 
    make -j $(awk '{if($1=="processor"){i++}}END{print i}' /proc/cpuinfo) && make install
    [ $? != 0 ] && exit 1
    sed -ri "s/(Server=)127.0.0.1/\1$ZabbixServerIp/" $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri "s/(ServerActive=).*/\1$ZabbixServerIp/" $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri "s/(Hostname=).*/\1$(hostname)/" $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri '/BufferSize=/a BufferSize=1024' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri '/Timeout=/a Timeout=5' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri '/StartAgents=/a StartAgents=3' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri '/DebugLevel=/a DebugLevel=2' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri '/PidFile=/a PidFile=/var/tmp/zabbix_agentd.pid' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri 's@(LogFile=).*@\1/var/log/zabbix/zabbix_agentd.log@' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri '/LogFileSize=/a LogFileSize=10' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri '/EnableRemoteCommands=/a EnableRemoteCommands=1' $(dirname $zbserverconf)/zabbix_agentd.conf
    sed -ri "/Include=$/a Include=$(dirname $zbserverconf)/zabbix_command.conf" $(dirname $zbserverconf)/zabbix_agentd.conf
 
    mkdir /var/log/zabbix && chown -R zabbix:zabbix /var/log/zabbix/
    touch $(dirname $zbserverconf)/zabbix_command.conf
 
    cat >> /etc/services << EOF
zabbix-agent 10050/tcp #Zabbix Agent
zabbix-agent 10050/udp #Zabbix Agent
EOF
    cp /root/zabbix-2.4.6/misc/init.d/fedora/core/zabbix_agentd /etc/rc.d/init.d/
    sed -i 's@BASEDIR=/usr/local@&/zabbix@' /etc/rc.d/init.d/zabbix_agentd
    chmod +x /etc/rc.d/init.d/zabbix_agentd
    chkconfig --add zabbix_agentd
    chkconfig zabbix_agentd on
    service zabbix_agentd start
}
 
downFile() {
    wget "$1" -O "$2" 2>&1 | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ {print substr($0,63,3)}' | whiptail --gauge "$3" 6 80 0 && clear
}
 
findUidGid() {
    for i in `seq 400 500`;do
        if [ -z "$(awk -F: '{print$3,$4}' /etc/passwd | grep "$i")" -a -z "$(awk -F: '{print$3}' /etc/group | grep "$i")" ]; then
            ugidNo=$i
            break
        fi
    done
    groupadd -g $ugidNo $1 && useradd -M -u $ugidNo -g $ugidNo -s /sbin/nologin $1
}
 
donotDel() {
    if (whiptail --title "防止手贱误删除功能" --yesno "是否需要在本系统上实现防手贱误删除功能，\n开启之后在运行rm -rf 命令时会再次提醒是否确认删除。" 10 60); then
        #防手贱运行rm -rf
        downFile "http://www.05hd.com/wp-content/uploads/2014/12/securityremove" "/bin/securityremove" "Download securityremove"
        chmod 755 /bin/securityremove
        test -f /etc/bash.bashrc && sed -i "/securityremove/d" /etc/bash.bashrc && echo 'alias rm="/bin/securityremove"' >> /etc/bash.bashrc && . /etc/bash.bashrc
        test -f /etc/bashrc && sed -i "/securityremove/d" /etc/bashrc && echo 'alias rm="/bin/securityremove"' >> /etc/bashrc && . /etc/bashrc
        test -f /root/.bashrc && sed -i "/alias rm/d" /root/.bashrc && echo 'alias rm="/bin/securityremove"' >> /root/.bashrc && . /root/.bashrc
        echo "防止手贱误删除功能已经开启."
    else
        echo "不开启防手贱误删除功能."
    fi
}
 
changTime() {
    [ -z "$(grep -E '8.8.8.8|114.114.114.114' /etc/resolv.conf )" ] && sed -i '1i\nameserver 114.114.114.114\nnameserver 8.8.8.8' /etc/resolv.conf
    if (whiptail --title "网络自动校时" --yesno "是否需要在本系统上开启定时自动网络校时功能" 10 60); then
        #设置定制网络校时和关闭系统发邮件给用户
        [ -f /var/spool/cron/root ] && sed -i '/ntpdate/d' /var/spool/cron/root
        echo "*/5 * * * * /usr/sbin/ntpdate cn.pool.ntp.org >/dev/null 2>&1" >> /var/spool/cron/root
        /usr/sbin/ntpdate cn.pool.ntp.org >/dev/null 2>&1
        [ -z "$(grep 'unset MAILCHECK' /etc/profile)" ] && echo "unset MAILCHECK" >> /etc/profile && . /etc/profile
        echo "定时自动网络校时已经开启."
    else
        echo "不开启自动网络小时功能."
    fi
}
 
changYum() {
    if (whiptail --title "更改YUM源" --yesno "是否需将YUM源修改为阿里云镜像源" 10 60); then
        yumDir="/etc/yum.repos.d/"
        aliUrl="mirrors.aliyun.com"
        [ ! -d ${yumDir}backup -a ! -f ${yumDir}backup ] && mkdir ${yumDir}backup
        mv -f ${yumDir}*.repo ${yumDir}backup/
        if (whiptail --title "系统版本确认" --yes-button "CentOS 6.*" --no-button "CentOS 5.*"  --yesno "请谨慎选择您的系统版本" 10 60) then
            wget -q -O ${yumDir}CentOS-Base.repo "http://$aliUrl/repo/Centos-6.repo"
            wget -q -O ${yumDir}epel.repo "http://$aliUrl/repo/epel-6.repo"
            rpm -ivh http://www.05hd.com/wp-content/uploads/2014/12/axel-2.4-1.el6.rf.x86_64.rpm &>/dev/null
        else
            wget -O ${yumDir}CentOS-Base.repo "http://$aliUrl/repo/Centos-5.repo"
            wget -O ${yumDir}epel.repo "http://$aliUrl/repo/epel-5.repo"
            rpm -ivh http://www.05hd.com/wp-content/uploads/2014/12/axel-2.4-1.el5.rf.x86_64.rpm &>/dev/null
        fi
        echo "YUM源已经修改."
    else
        echo "YUM源不做修改."
    fi
}
 
addAlias() {
    #设置快捷命令
    if ! grep "alias vi='vim'" /root/.bashrc &>/dev/null; then
        cat >> /root/.bashrc << EOF
alias vi='vim'
alias grep='grep --color=auto'
export VISUAL=vim
export EDITOR=vim
EOF
        #取消vim搜索历史高亮
        sed -i 's/.*set hlsearch.*/"&/' /etc/vimrc
        #如果能联网则下载VIM配置文件
        wget -cq http://www.05hd.com/wp-content/uploads/2014/12/vim.tar.gz
        tar xf vim.tar.gz -C /root/ && rm -rf vim.tar.gz
    fi
}
 
clear && addAlias && donotDel && changTime && changYum
 
#开始安装
#清空yum 安装一些所需
OPTION=$(whiptail --title "Zabbix Server OR Agent Install" --menu "Choose your option" 15 60 4 \
"1" "Install Zabbix Server" \
"2" "Install Zabbix Agent" \
"3" "Exit Script" 3>&1 1>&2 2>&3)
   
exitstatus=$?
if [ $exitstatus = 0 ]; then
    if [ $OPTION = 1 ]; then
        yum clean all && yum makecache
        yum groupinstall "Development tools" "Server Platform Development" -y
        yum -y install gcc-c++ make perl libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel libxml2 libxml2-devel zlib zlib-devel glib2 glib2-devel bzip2 bzip2-devel ncurses ncurses-devel curl curl-devel xz xz-devel expat expat-devel e2fsprogs e2fsprogs-devel krb5-devel libidn libidn-devel libxslt-devel libevent-devel libtool libtool-ltdl bison gd-devel vim-enhanced pcre-devel zip unzip ntpdate sysstat patch expect automake autoconf libtool net-snmp-devel OpenIPMI OpenIPMI-devel vim perl-ZMQ-LibZMQ3
        for i in nginx php cmake mariadb zabbix; do
            if [ "$i" != "zabbix" ]; then
                if ! which $i &>/dev/null; then
                    install_$i "$(eval echo \$${i}Url)" 2>&1 | tee -a /root/${i}_install.log
                else
                    echo "$i Install Done!"
                fi
            else
                if ! which zabbix_server &>/dev/null; then
                    install_$i "$(eval echo \$${i}Url)" 2>&1 | tee -a /root/${i}_install.log
                else
                    echo "$i server Install Done!"
                fi
            fi
        done
    elif [ $OPTION = 2 ]; then
        PET=$(whiptail --title "Server IP Address Input" --inputbox "Please Input Zabbix Server IP Address" 10 60 172.16.41.163 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus = 0 ]; then
            ZabbixServerIp=$PET
        else
            echo "You chose Cancel."
        fi
        yum clean all && yum makecache
        yum groupinstall "Development tools" "Server Platform Development" -y
        yum install net-snmp-devel net-snmp -y
        install_zabbix_agent "$zabbixUrl" | tee -a /root/zabbix_agent_install.log
        service snmpd start
    elif [ $OPTION = 3 ]; then
        echo "Exit Script" && exit 1
    fi
else
    echo "You chose Cancel."
fi
 
#wget -q http://www.dwhd.org/wp-content/uploads/2015/05/zabbix_server_agent.sh && bash zabbix_server_agent.sh
