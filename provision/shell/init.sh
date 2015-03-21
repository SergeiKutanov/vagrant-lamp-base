#!/bin/bash

MYSQL_PASSWORD="123"
MYSQL_CONFIG_FILE="/etc/mysql/my.cnf"
PHP_CONFIG_FILE="/etc/php5/apache2/php.ini"
XDEBUG_CONFIG_FILE="/etc/php5/mods-available/xdebug.ini"

apt-get update
apt-get -y upgrade

apt-get install -y apache2
rm -rf /var/www
ln -fs /vagrant /var/www

echo "mysql-server mysql-server/root_password password" $MYSQL_PASSWORD | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again password" $MYSQL_PASSWORD | sudo debconf-set-selections

apt-get install -y mysql-server

sed -i "s/bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" ${MYSQL_CONFIG_FILE}

# Allow root access from any host
echo "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' WITH GRANT OPTION" | mysql -u root --password=$MYSQL_PASSWORD
echo "GRANT PROXY ON ''@'' TO 'root'@'%' WITH GRANT OPTION" | mysql -u root --password=$MYSQL_PASSWORD

IPADDR=$(/sbin/ifconfig eth0 | awk '/inet / { print $2 }' | sed 's/addr://')
sed -i "s/^${IPADDR}.*//" /etc/hosts
echo $IPADDR ubuntu.localhost >> /etc/hosts

# Install basic tools
apt-get -y install build-essential binutils-doc git

apt-get -y install php5 php5-curl php5-mysql php5-sqlite php5-xdebug

sed -i "s/display_startup_errors = Off/display_startup_errors = On/g" ${PHP_CONFIG_FILE}
sed -i "s/display_errors = Off/display_errors = On/g" ${PHP_CONFIG_FILE}

cat << EOF > ${XDEBUG_CONFIG_FILE}
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.remote_port=9000
xdebug.remote_host=10.0.2.2
EOF

# install phpmyadmin and give password(s) to installer
# for simplicity I'm using the same password for mysql and phpmyadmin
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean true"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_PASSWORD"
sudo debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
sudo apt-get -y install phpmyadmin

# Restart Services
service apache2 restart
service mysql restart