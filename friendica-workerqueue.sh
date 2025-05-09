#!/bin/bash
sudo mariadb friendica --execute="select distinct command, count(*) from workerqueue where done = 0 group by command; select count(*) from workerqueue where done = 0; select count(*) from workerqueue where command = \"ProcessQueue\" and pid = 0 and done = 0"
sudo redis-cli -n 1 keys '*' | cut -d":" -f2 | cut -d "-" -f 1-3 | sort | uniq -c | sort -n
