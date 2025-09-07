#!/bin/bash
dbname="friendica"
dbengine="mysql"
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
else
	echo "MySQL not found." && exit
fi
sudo "${dbengine}" "${dbname}" --execute="select distinct command, date(created), count(*) from workerqueue where done = 0 group by command, date(created); select distinct command, count(*) from workerqueue where done = 0 group by command having count(*) > 1; select count(*) as \"Full Count\" from workerqueue where done = 0; select count(*) as \"ProcessQueue Count\" from workerqueue where command = \"ProcessQueue\" and pid = 0 and done = 0"
if [[ -n $(type redis-cli) ]]; then
	sudo redis-cli -n 1 keys '*' | cut -d":" -f2 | cut -d "-" -f 1-3 | sort | uniq -c | sort -n | sed -e "/ 1 .*/d"
fi
