#!/bin/sh

# This has been tested on a T1 Micro Instance using AMI ID : amzn-ami-pv-2014.03.1.x86_64-ebs (ami-fb8e9292)

echo 'Installing nginx...'
yum -y install nginx

echo 'Fixing nginx configuration'
sed -i 's/worker_processes  1;/worker_processes  4;/g' /etc/nginx/nginx.conf
rm -f /etc/nginx/conf.d/virtual.conf

echo 'Creating configuration files'
echo 'proxy_redirect            off;
proxy_set_header          Host            $host;
proxy_set_header          X-Real-IP       $remote_addr;
proxy_set_header          X-Forwarded-For $proxy_add_x_forwarded_for;
client_max_body_size      10m;
client_body_buffer_size   128k;
client_header_buffer_size 64k;
proxy_connect_timeout     90;
proxy_send_timeout        90;
proxy_read_timeout        90;
proxy_buffer_size         16k;
proxy_buffers             32              16k;
proxy_busy_buffers_size   64k;' > /etc/nginx/conf.d/proxy.conf

echo 'server {
 listen 80;
 server_name _;
 access_log /var/log/httpd/elasticbeanstalk-access_log;
 error_log /var/log/httpd/elasticbeanstalk-error_log;

 #set the default location
 location / {
  proxy_pass         http://127.0.0.1:9000/;
 }

 # make sure the hostmanager works
 location /_hostmanager/ {
  proxy_pass         http://127.0.0.1:8999/;
 }
}' > /etc/nginx/conf.d/beanstalk.conf

echo 'Making sure that nginx starts on startup'
/sbin/chkconfig nginx on

echo 'Removing apache...'
yum remove httpd

echo 'Starting nginx'
sudo service nginx start

echo 'Nginx is installed'

echo 'Creating app directory'
mkdir /var/app

echo 'Downloading Playframework'
wget -P /opt/ https://playframework-assets.s3.amazonaws.com/play-2.2.3.zip
unzip /opt/play-2.2.3.zip
rm -f /opt/play-2.2.3.zip

echo 'Adding Play to the PATH'
echo 'export PATH=$PATH:/opt/play-2.2.3' > /etc/profile.d/play.sh
source /etc/profile.d/play.sh

echo 'Adding play startup script'

echo '#! /bin/sh

### BEGIN INIT INFO
# Provides:          play
# Required-Start:    $all
# Required-Stop:     $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description:
# Description:
### END INIT INFO

. /etc/rc.d/init.d/functions

APP="playapp"
APP_PATH="/var/app/$APP"

start() {
  if [ -f $APP_PATH.zip ]; then
    rm -fR $APP_PATH/*
    unzip "$APP_PATH.zip" -d $APP_PATH
    rm "$APP_PATH.zip"
    ln -s $APP_PATH/*/ /var/app/current
  fi

	BIN=`find $APP_PATH/*/bin -not -name "*.bat" -not -type d`
  $BIN -J-Xms64M -J-Xmx256m -Dpidfile.path=/var/run/play.pid >/dev/null 2>&1 &
  return 0
}

stop() {
    kill `cat /var/run/play.pid`
    return 0
}

status() {
  if [ -f /var/run/play.pid ]; then
    success
    exit 0;
  else 
    success
    exit 1;
  fi
}

case "$1" in
  start)
    start
    exit 0
    ;;
  stop)
    stop
    ;;
  restart)
    echo  "Restarting $APP."
    stop
    sleep 2
    start
    echo "$APP restarted."
    ;;
  status)
    echo  "Checking status"
    status
    ;;
  *)
    N=/etc/init.d/play.$APP
    echo "Usage: $N {start|stop|restart}" >&2
    exit 1
    ;;
esac

exit 0' > /etc/init.d/play
chmod +x /etc/init.d/play

echo 'Making sure that play starts on startup'
/sbin/chkconfig play on

echo 'Removing tomcat...'
yum remove tomcat7

echo 'Downloading sample test app for play'
wget -P /var/app/ https://playframework-assets.s3.amazonaws.com/playapp.zip

echo 'Starting up play'
sudo service play start

# TODO: add in monit.conf
sudo service monit restart
