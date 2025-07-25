#!/bin/bash
limit=1000
ca=${limit}
camax=0
until [[ ${ca} -lt ${limit} ]]; do
	ca=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`)) and \`command\` = \"UpdateContact\" and \`done\` = 0 limit ${ca}; select row_count();")
	camax=$((camax + ca))
	printf "\rUpdateContact\t\t%s\r" "${camax}"
done
printf "\rUpdateContact\t\t%s\n\r" "${camax}"
#echo "UpdateContact      $camax"

cb=${limit}
cbmax=0
until [[ ${cb} -lt ${limit} ]]; do
	cb=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`)) and \`command\` = \"ContactDiscovery\" and \`done\` = 0 limit ${cb}; select row_count();")
	cbmax=$((cbmax + cb))
	printf "\rContactDiscovery\t%s\r" "${cbmax}"
done
printf "\rContactDiscovery\t%s\n\r" "${cbmax}"
#echo "ContactDiscovery   $cbmax"

cc=${limit}
ccmax=0
sudo mariadb friendica -B -N -q -e "create table tmp_url (select \`url\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`));"
until [[ ${cc} -lt ${limit} ]]; do
	cc=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`command\`= \"AddContact\" and regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${cc}; select row_count();")
	ccmax=$((ccmax + cc))
	printf "\rAddContact      \t%s\r" "${ccmax}"
done
printf "\rAddContact      \t%s\n\r" "${ccmax}"
#echo "AddContact $ccmax"

cd=${limit}
cdmax=0
#sudo mariadb friendica -B -N -q -e "create table tmp_updategserver (select \`url\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`));"
until [[ ${cd} -lt ${limit} ]]; do
	cd=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`command\` = \"UpdateGServer\" and regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${cd}; select row_count();")
	cdmax=$((cdmax + cd))
	printf "\rUpdateGServer\t\t%s\r" "${cdmax}"
done
printf "\rUpdateGServer\t\t%s\n\r" "${cdmax}"
#echo "UpdateGServer      $cdmax"

ce=${limit}
cemax=0
until [[ ${ce} -lt ${limit} ]]; do
	ce=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`command\`= \"FetchFeaturedPosts\" and regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${ce}; select row_count();")
	cemax=$((cemax + ce))
	printf "\rFetchFeaturedPosts\t%s\r" "${cemax}"
done
sudo mariadb friendica -B -N -q -e "drop table tmp_url"
printf "\rFetchFeaturedPosts\t%s\n\r" "${cemax}"
#echo "FetchFeaturedPosts $cemax"

cf=${limit}
cfmax=0
until [[ ${cf} -lt ${limit} ]]; do
	cf=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where command=\"ProcessQueue\" and pid=0 and done=0 limit ${cf}; select row_count();")
	cfmax=$((cfmax + cf))
	printf "\rProcessQueue\t\t%s\r" "${cfmax}"
done
printf "\rProcessQueue\t\t%s\n\r" "${cfmax}"
#echo "ProcessQueue       $cfmax"

cg=${limit}
cgmax=0
until [[ ${cg} -lt ${limit} ]]; do
	cg=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`parameter\` not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`)) and \`command\` = \"OnePoll\" and \`done\` = 0 limit ${cg}; select row_count();")
	cgmax=$((cgmax + cg))
	printf "\rOnePoll\t\t\t%s\r" "${cgmax}"
done
printf "\rOnePoll\t\t\t%s\n\r" "${cgmax}"
#echo "OnePoll           $cgmax"

ch=${limit}
chmax=0
until [[ ${ch} -lt ${limit} ]]; do
	ch=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`id\` in (select distinct w2.\`id\` from workerqueue w1 inner join workerqueue w2 where w1.\`id\` > w2.\`id\` and w1.\`parameter\` = w2.\`parameter\` and w1.command = \"UpdateContact\" and w1.\`pid\` = 0 and w1.\`done\` = 0) limit ${ch}; select row_count();")
	chmax=$((chmax + ch))
	printf "\rWorkerQueue\t\t%s\r" "${chmax}"
done
printf "\rWorkerQueue\t\t%s\n\r" "${chmax}"
#echo "WorkerQueue       $chmax"
