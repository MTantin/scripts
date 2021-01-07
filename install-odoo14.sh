#!/bin/bash
# Install Odoo 14.0 on Ubuntu Server 20.0

# Define colors
NORMAL="\e[39m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"

if [[ $EUID -ne 0 ]]; then
   printf "${RED}This script must be run as root!${NORMAL}\n"
   exit 1
fi

ENVIRONMENT_DIR=/opt/odoo14
ODOO_PATH=/opt/odoo
ODOO_DIR=odoo14

ODOO_DB_USER=odoo
ODOO_DB_PWD=odoo
ODOO_DB_HOST=localhost

UUID=$(cat /proc/sys/kernel/random/uuid)

# Update environment and install prerequisites
apt-get update
apt-get install -y git wget postgresql virtualenv nginx \
                libxml2-dev libxslt1-dev libsasl2-dev libldap2-dev libssl-dev libpq-dev \
                libtiff5-dev libjpeg8-dev libopenjp2-7-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev tcl8.6-dev tk8.6-dev python3-tk libharfbuzz-dev libfribidi-dev libxcb1-dev \
                python3 python3-ldap python3-lxml python3-psycopg2 python3-pip python3-dev python3-setuptools

# Create Odoo linux user
if ! id -u "odoo"; then
    printf "${GREEN}###### linux user odoo doesn't exist, create it...${NORMAL}\n"
    useradd -r -s /bin/false odoo
else
    printf "${YELLOW}###### linux user odoo already exists, skip...${NORMAL}\n"
fi

# Create Odoo postgres user
if ! psql -d "postgresql://$ODOO_DB_USER:$ODOO_DB_PWD@$ODOO_DB_HOST/postgres" -c "select now()" &> /dev/null; then
    printf "${GREEN}###### postgres user odoo doesn't exist, create it...${NORMAL}\n"
    sudo -u postgres psql -c "CREATE ROLE $ODOO_DB_USER WITH CREATEDB LOGIN PASSWORD '$ODOO_DB_PWD'"
else
    printf "${YELLOW}###### postgres user odoo already exists, skip...${NORMAL}\n"
fi

# Install nodeJS
curl -sL https://deb.nodesource.com/setup_15.x | sudo -E bash -
apt-get install -y nodejs
npm install -g rtlcss

# Install wkhtmltopdf
if ! dpkg-query -l wkhtmltox &> /dev/null; then
    printf "${GREEN}###### wkhtmltox not installed, installation...${NORMAL}n"
    wget https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.focal_amd64.deb
    apt install -y ./wkhtmltox_0.12.5-1.focal_amd64.deb
    rm wkhtmltox_0.12.5-1.focal_amd64.deb
else
    printf "${YELLOW}###### wkhtmltox already installed, skip...${NORMAL}\n"
fi

# Add Odoo sources
mkdir -p $ODOO_PATH
if [ ! -d "$ODOO_PATH/$ODOO_DIR" ]; then
    printf "${GREEN}###### Odoo 14 directory doesn't exists, create it...${NORMAL}\n"
    git clone https://github.com/odoo/odoo -b 14.0 --depth 1 $ODOO_PATH/$ODOO_DIR
else
    printf "${YELLOW}###### Odoo 14 directory already exists, skip...${NORMAL}\n"
fi

# Create environment with addons directory and virtual environment
mkdir -p $ENVIRONMENT_DIR $ENVIRONMENT_DIR/addons
virtualenv -p python3 $ENVIRONMENT_DIR/venv

# Install Odoo in virtual environment
CFLAGS="-O0" $ENVIRONMENT_DIR/venv/bin/pip install lxml==4.3.2
$ENVIRONMENT_DIR/venv/bin/pip install -r $ODOO_PATH/$ODOO_DIR/requirements.txt

if [ $? -ne 0 ]; then
   printf "${RED}###### Odoo 14 requirements installation failed!${NORMAL}\n"
   exit 1
fi

$ENVIRONMENT_DIR/venv/bin/pip install $ODOO_PATH/$ODOO_DIR

# Launch for the first time Odoo to create configuration file
sudo -u odoo $ENVIRONMENT_DIR/venv/bin/python $ENVIRONMENT_DIR/venv/bin/odoo -c $ENVIRONMENT_DIR/odoo.conf -s --data-dir=$ENVIRONMENT_DIR/data_dir --addons-path=$ODOO_PATH/$ODOO_DIR/odoo/addons,$ODOO_PATH/$ODOO_DIR/addons --db-filter=^%h$ --db_user=$ODOO_DB_USER --db_password=$ODOO_DB_PWD --db_host=$ODOO_DB_HOST --proxy-mode --stop-after-init
sed -i "s/admin_passwd = admin/admin_passwd = $UUID/g" $ENVIRONMENT_DIR/odoo.conf

# Set Odoo as service
ODOO_SERVICE_FILE=/etc/init.d/odoo14
if [ ! -f "$ODOO_SERVICE_FILE" ]; then
    printf "${GREEN}###### Odoo 14 service file doesn't exists, create it...${NORMAL}\n"
    cp $ODOO_PATH/$ODOO_DIR/debian/init $ODOO_SERVICE_FILE
    sed -i "s#^PATH\=.*#PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:$ENVIRONMENT_DIR/venv/bin#"  $ODOO_SERVICE_FILE
    sed -i "s#^DAEMON\=.*#DAEMON=$ENVIRONMENT_DIR/venv/bin/odoo#"  $ODOO_SERVICE_FILE
    sed -i "s#^NAME\=.*#NAME=$ODOO_DIR#"  $ODOO_SERVICE_FILE
    sed -i "s#^DESC\=.*#DESC=$ODOO_DIR#"  $ODOO_SERVICE_FILE
    sed -i "s#^CONFIG\=.*#CONFIG=$ENVIRONMENT_DIR/odoo.conf#"  $ODOO_SERVICE_FILE
    sed -i "s#^LOGFILE\=.*#LOGFILE=/var/log/odoo/$ODOO_DIR-server.log#"  $ODOO_SERVICE_FILE
    sed -i "s#^USER\=.*#USER=odoo#"  $ODOO_SERVICE_FILE
    chmod +x $ODOO_SERVICE_FILE
else
    printf "${YELLOW}###### Odoo 14 service file already exists, skip...${NORMAL}\n"
fi

if ! service --status-all | grep -Fq 'odoo14'; then
    update-rc.d odoo14 defaults
    update-rc.d odoo14 enable
fi

# Add cron to restart Odoo service every day at 04:00
{ echo "0 4 * * * service odoo14 restart"; } | crontab -

# Set Nginx
NGINX_DIR=/etc/nginx
NGINX_AVAILABLE_DIR=$NGINX_DIR/sites-available
NGINX_ENABLED_DIR=$NGINX_DIR/sites-enabled

cp -f ./files/nginx-default-* $NGINX_AVAILABLE_DIR
if [ ! -f "$NGINX_ENABLED_DIR/nginx-default-odoo-upstreams" ]; then
    printf "${GREEN}###### Nginx upstreams for Odoo14 doesn't exists, create it...${NORMAL}\n"
    ln -s $NGINX_AVAILABLE_DIR/nginx-default-odoo-upstreams $NGINX_ENABLED_DIR
else
    printf "${YELLOW}###### Nginx upstreams for Odoo14 already exists, skip...${NORMAL}\n"
fi

# Clean all
apt-get clean

exit 0
