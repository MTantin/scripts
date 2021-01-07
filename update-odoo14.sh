#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

ODOO_VENV=/opt/odoo14/venv
ODOO_CONF=/opt/odoo14/odoo.conf
ODOO_DATABASES=("odoo14")
ODOO_LOGS=`awk '/logfile/{print $NF}' $ODOO_CONF`

# Stop Odoo service
service odoo14 stop

# Update Odoo sources
pushd /opt/odoo >> /dev/null
git fetch --depth 1 >> /dev/null
git reset --hard origin/14.0 >> /dev/null
popd >> /dev/null

# Update Odoo databases
for database_name in ${ODOO_DATABASES[*]}; do
     sudo -u odoo $ODOO_VENV/bin/odoo -c $ODOO_CONF -u all -d $database_name --stop-after-init
done

# Restart Odoo service
service odoo14 start

exit 0
