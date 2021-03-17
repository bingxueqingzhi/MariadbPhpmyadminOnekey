#!/bin/bash
#
#********************************************************************
#Author:                chendafu
#QQ:                    31423684864576
#Date:                  2019-05-15
#FileName：             myadmin.sh
#URL:                   http://www.derong.info
#Description：          The test script
#Copyright (C):        2019 All rights reserved
#********************************************************************
# 设置变量
base_dir='/app'
pack_dir='/data'
data_dir='/data/mysql'
my_conf='/etc/mysql'
httpd_ver='2.4.39'
apr_ver='1.7.0'
apr_util_ver='1.6.1'
mariadb_ver='10.2.23'
php_ver='7.3.5'
mariadb_arch='linux-x86_64'
tar_type1='tar.gz'
tar_type2='tar.bz2'
tar_type3='tar.xz'
zip_type='zip'

# 创建用户
getent passwd apache &> /dev/null
if [ ! $? -eq 0 ];then
        useradd -r -s /sbin/nologin apache
fi

getent passwd mysql &> /dev/null
if [ ! $? -eq 0 ];then
        useradd -r -s /sbin/nologin mysql
fi
# 创建数据库目录
if [ ! -d $data_dir ];then
        mkdir $data_dir
        chown -R mysql.mysql $data_dir
fi

if [ ! -d $my_conf ];then                                                                                                                                         
        mkdir $my_conf
fi

# 设置$PATH
echo 'PATH=/app/httpd/bin:$PATH' > /etc/profile.d/httpd-`date +%F`.sh
echo 'PATH=/usr/local/mysql/bin:$PATH' > /etc/profile.d/mysql-`date +%F`.sh
. /etc/profile.d/httpd-`date +%F`.sh
. /etc/profile.d/mysql-`date +%F`.sh
# 安装httpd$httpd_ver
yum install pcre-devel openssl-devel expat-devel gcc gcc-c++ libtool libxml2-devel bzip2-devel libmcrypt-devel -y

cd $pack_dir
tar xf httpd-${httpd_ver}.${tar_type2}
tar xf apr-${apr_ver}.${tar_type1}
tar xf apr-util-${apr_util_ver}.${tar_type1}

cp -r apr-${apr_ver} httpd-$httpd_ver/srclib/apr
cp -r apr-util-${apr_util_ver} httpd-$httpd_ver/srclib/apr-util

cd httpd-$httpd_ver
./configure \
--prefix=/app/httpd \
--enable-so \
--enable-ssl \
--enable-cgi \
--enable-rewrite \
--with-zlib \
--with-pcre \
--with-included-apr \
--enable-modules=most \
--enable-mpms-shared=all \
--with-mpm=prefork

make && make install

echo '/app/httpd/bin/apachectl start' >> /etc/rc.d/rc.local
chmod +x  /etc/rc.d/rc.local

sed -ir 's/User daemon/User apache/g' /app/httpd/conf/httpd.conf
sed -ir 's/Group daemon/Group apache/g' /app/httpd/conf/httpd.conf
sed -ir 's/    DirectoryIndex index.html/    DirectoryIndex index.html index.php/g' /app/httpd/conf/httpd.conf
apachectl start
echo -e '报告！apache安装完毕！'
sleep 5

# 二进制安装mariadb10.2

cd $pack_dir
tar xf mariadb-${mariadb_ver}-${mariadb_arch}.${tar_type1} -C /usr/local/
cd /usr/local
ln -s mariadb-${mariadb_ver}-${mariadb_arch} mysql
chown -R root.root mysql/
cd mysql
./scripts/mysql_install_db --datadir=/data/mysql --user=mysql
cp ./support-files/my-huge.cnf $my_conf/my.cnf
sed -ir '/\[mysqld\]/a datadir=/data/mysql' $my_conf/my.cnf
cp ./support-files/mysql.server /etc/init.d/mysqld
chkconfig --add mysqld

service mysqld start
sleep 5
echo "grant all on *.* to 'admin'@'localhost' identified by 'admin';" > $pack_dir/myadmin.sql
mysql < $pack_dir/myadmin.sql

echo -e '报告！mysql安装完毕'

sleep 5

# 安装phpmyadmin4.8.5
cd $pack_dir
unzip phpMyAdmin-4.8.5-all-languages.${zip_type}
cp -r phpMyAdmin-4.8.5-all-languages $base_dir/httpd/htdocs/myadmin
cd $base_dir/httpd/htdocs/myadmin
cp config.sample.inc.php config.inc.php 
sed -ir '/localhost/a $cfg['Servers'][$i]['port'] = '3306';\n$cfg['Servers'][$i]['user'] = 'admin';\n$cfg['Servers'][$i]['password'] = 'admin';' config.inc.php

# 安装PHP7.3.5
cd $pack_dir
tar xf php-${php_ver}.${tar_type2}
cd php-${php_ver}/
./configure --prefix=/app/php \
--enable-mysqlnd \
--with-mysqli=mysqlnd \
--with-pdo-mysql=mysqlnd \
--with-openssl \
--with-freetype-dir \
--with-jpeg-dir \
--with-png-dir \
--with-zlib \
--with-libxml-dir=/usr \
--with-config-file-path=/etc \
--with-config-file-scan-dir=/etc/php.d \
--enable-mbstring \
--enable-xml \
--enable-sockets \
--enable-fpm \
--enable-maintainer-zts \
--disable-fileinfo

make && make install

cp php.ini-production /etc/php.ini
cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
chmod +x /etc/init.d/php-fpm
chkconfig --add php-fpm
chkconfig php-fpm on
cp $base_dir/php/etc/php-fpm.conf.default $base_dir/php/etc/php-fpm.conf
cp $base_dir/php/etc/php-fpm.d/www.conf.default $base_dir/php/etc/php-fpm.d/www.conf

service php-fpm start

# 配置httpd支持PHP
cat >> $base_dir/httpd/conf/httpd.conf <<EOF
LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so
LoadModule proxy_module modules/mod_proxy.so
AddType application/x-httpd-php .php
AddType application/x-httpd-php-source .phps
ProxyRequests Off
ProxyPassMatch ^/(.*\.php)$ fcgi://127.0.0.1:9000/app/httpd/htdocs/$1
EOF

echo done!
