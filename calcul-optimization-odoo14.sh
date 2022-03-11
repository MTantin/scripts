#/bin/bash

RAM_MB=`free -m | awk '/^Mem:/ {print $2}'`
NB_PROC=`nproc --all`

ODOO_WORKERS_CPU_LIMITED=$(($NB_PROC*2+1))
ODOO_WORKERS_RAM_LIMITED=`/opt/odoo14/venv/bin/python -c "print(str($RAM_MB/((0.8*150)+(0.2*1024))).split('.')[0])"`
if [ "$ODOO_WORKERS_CPU_LIMITED" -gt "$ODOO_WORKERS_RAM_LIMITED" ]; then
    ODOO_WORKERS=$ODOO_WORKERS_RAM_LIMITED
else
    ODOO_WORKERS=$ODOO_WORKERS_CPU_LIMITED
fi

DB_SHARED_BUFFERS=$(($RAM_MB*20/100))
DB_CACHE_SIZE=$(($RAM_MB*50/100))
ODOO_LIMIT_HARD=$(($RAM_MB*80/100*1024*1024))
ODOO_LIMIT_SOFT=$(($RAM_MB*67/100*1024*1024))


echo "RAM_MB: ${RAM_MB}MB"
echo "NB_PROC: $NB_PROC"
echo "DB_SHARED_BUFFERS: ${DB_SHARED_BUFFERS}MB"
echo "DB_CACHE_SIZE: ${DB_CACHE_SIZE}MB"
echo "ODOO_WORKERS_CPU_LIMITED: $ODOO_WORKERS_CPU_LIMITED"
echo "ODOO_WORKERS_RAM_LIMITED: $ODOO_WORKERS_RAM_LIMITED"
echo "ODOO_WORKERS: $ODOO_WORKERS"

echo ""
echo "PostgreSQL configuration advised is:"
echo "shared_buffers = ${DB_SHARED_BUFFERS}MB"
echo "effective_cache_size = ${DB_CACHE_SIZE}MB"

echo ""
echo "Odoo configuration advised is:"
if [ "$ODOO_WORKERS" -lt 5 ]; then
    echo "Not enough CPU or RAM to use workers, need atleast 2 CPU and enough RAM by CPU as RAM=(2*CPU+1)*324,8"
    echo "limit_memory_hard = $ODOO_LIMIT_HARD"
    echo "limit_memory_soft = $ODOO_LIMIT_SOFT"
    echo "workers = 0"
else
    echo "limit_memory_hard = $ODOO_LIMIT_HARD"
    echo "limit_memory_soft = $ODOO_LIMIT_SOFT"
    echo "workers = $ODOO_WORKERS"
fi

exit 0
