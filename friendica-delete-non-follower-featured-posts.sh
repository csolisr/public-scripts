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
sudo mariadb friendica -B -N -q -e "drop table if exists tmp_url; create table tmp_url (select \`url\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`));"
until [[ ${cb} -lt ${limit} ]]; do
	cb=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`command\` = \"ContactDiscovery\" and regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', ''), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${cb}; select row_count();")
	cbmax=$((cbmax + cb))
	printf "\rContactDiscovery\t%s\r" "${cbmax}"
done
printf "\rContactDiscovery\t%s\n\r" "${cbmax}"
#echo "ContactDiscovery   $cbmax"

cc=${limit}
ccmax=0
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
printf "\rFetchFeaturedPosts\t%s\n\r" "${cemax}"
#echo "FetchFeaturedPosts $cemax"

cf=${limit}
cfmax=0
until [[ ${cf} -lt ${limit} ]]; do
	#cf=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', ''), '\\\\\\\\', ''), '.*\"actor\"\:\"', ''), '\".*', '') not in (select \`url\` from \`tmp_url\`) and \`command\` = \"FetchMissingReplies\" and \`done\` = 0 limit ${cf}; select row_count();")
	cf=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where not (regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\\\\\\', ''), '.*\"actor\"\:\"', ''), '\".*', '') in (select \`url\` from \`tmp_url\`) or regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\\\\\\', ''), '.*\"audience\"\:\"', ''), '\".*', '') in (select \`url\` from \`tmp_url\`)) and \`command\` = \"FetchMissingReplies\" and \`done\` = 0 limit ${cf}; select row_count();")
	cfmax=$((cfmax + cf))
	printf "\rFetchMissingReplies\t%s\r" "${cfmax}"
done
sudo mariadb friendica -B -N -q -e "drop table if exists tmp_url"
printf "\rFetchMissingReplies\t%s\n\r" "${cfmax}"
#echo "FetchMissingReplies $cfmax"

cg=${limit}
cgmax=0
until [[ ${cg} -lt ${limit} ]]; do
	cg=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where command=\"ProcessQueue\" and pid=0 and done=0 limit ${cg}; select row_count();")
	cgmax=$((cgmax + cg))
	printf "\rProcessQueue\t\t%s\r" "${cgmax}"
done
printf "\rProcessQueue\t\t%s\n\r" "${cgmax}"
#echo "ProcessQueue       $cgmax"

ch=${limit}
chmax=0
until [[ ${ch} -lt ${limit} ]]; do
	ch=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`)) and \`command\` = \"OnePoll\" and \`done\` = 0 limit ${ch}; select row_count();")
	chmax=$((chmax + ch))
	printf "\rOnePoll\t\t\t%s\r" "${chmax}"
done
printf "\rOnePoll\t\t\t%s\n\r" "${chmax}"
#echo "OnePoll           $chmax"

ci=${limit}
cimax=0
until [[ ${ci} -lt ${limit} ]]; do
	#ci=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`id\` in (select distinct w2.\`id\` from workerqueue w1 inner join workerqueue w2 where w1.\`id\` > w2.\`id\` and w1.\`parameter\` = w2.\`parameter\` and w1.command = \"UpdateContact\" and w1.\`pid\` = 0 and w1.\`done\` = 0) limit ${ci}; select row_count();")
	ci=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`id\` in (select distinct w2.\`id\` from workerqueue w1 inner join workerqueue w2 where w1.\`id\` > w2.\`id\` and w1.\`parameter\` = w2.\`parameter\` and w1.command = w2.command and w1.\`done\` = 0) limit ${ci}; select row_count();")
	cimax=$((cimax + ci))
	printf "\rWorkerQueue\t\t%s\r" "${cimax}"
done
printf "\rWorkerQueue\t\t%s\n\r" "${cimax}"
#echo "WorkerQueue       $cimax"

cj=${limit}
cjmax=0
until [[ ${cj} -lt ${limit} ]]; do
	cj=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where \`command\` = \"FetchMissingActivity\" and (\`parameter\` like \"%relay.%/actor%\" or \`parameter\` like \"%relay.fedi.buzz%\") and done = 0 limit ${cj}; select row_count();")
	cjmax=$((cjmax + cj))
	printf "\rFetchMissingActivity\t%s\r" "${cjmax}"
done
printf "\rFetchMissingActivity\t%s\n\r" "${cjmax}"
#echo "FetchMissingActivity $cimax"
