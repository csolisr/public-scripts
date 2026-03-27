#!/bin/bash
job_limit=${1:-"10000"}
loop_limit=${2:-"1000"}
dbengine=""
if [[ -n $(type mariadb) ]]; then
    dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
    dbengine="mysql"
else
    exit
fi
db=friendica
if [[ $("${dbengine}" "${db}" -B -N -q -e "select count(*) from workerqueue where \`done\` = 0") -gt ${job_limit} ]]; then
	ca=${loop_limit}
	camax=0
	until [[ ${ca} -lt ${loop_limit} ]]; do
		ca=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`)) and \`command\` = \"UpdateContact\" and \`done\` = 0 limit ${ca}; select row_count();")
		camax=$((camax + ca))
		printf "\rUpdateContact\t\t%s\r" "${camax}" #&> /dev/null
	done
	printf "\rUpdateContact\t\t%s\n\r" "${camax}" #&> /dev/null

	cb=${loop_limit}
	cbmax=0
	"${dbengine}" "${db}" -B -N -q -e 'drop table if exists tmp_url; create table tmp_url (select `url` from `contact` where `id` in (select `contact-id` from `group_member`) or `id` in (select `cid` from `user-contact`) or `id` in (select `uid` from `user`));'
	until [[ ${cb} -lt ${loop_limit} ]]; do
		cb=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where \`command\` = \"ContactDiscovery\" and regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', ''), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${cb}; select row_count();")
		cbmax=$((cbmax + cb))
		printf "\rContactDiscovery\t%s\r" "${cbmax}" #&> /dev/null
	done
	printf "\rContactDiscovery\t%s\n\r" "${cbmax}" #&> /dev/null

	cc=${loop_limit}
	ccmax=0
	until [[ ${cc} -lt ${loop_limit} ]]; do
		cc=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where \`command\`= \"AddContact\" and regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${cc}; select row_count();")
		ccmax=$((ccmax + cc))
		printf "\rAddContact      \t%s\r" "${ccmax}" #&> /dev/null
	done
	printf "\rAddContact      \t%s\n\r" "${ccmax}" #&> /dev/null

	cd=${loop_limit}
	cdmax=0
	#"${dbengine}" "${db}" -B -N -q -e "create table tmp_updategserver (select \`url\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`));"
	until [[ ${cd} -lt ${loop_limit} ]]; do
		cd=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where \`command\` = \"UpdateGServer\" and regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${cd}; select row_count();")
		cdmax=$((cdmax + cd))
		printf "\rUpdateGServer\t\t%s\r" "${cdmax}" #&> /dev/null
	done
	printf "\rUpdateGServer\t\t%s\n\r" "${cdmax}" #&> /dev/null

	ce=${loop_limit}
	cemax=0
	until [[ ${ce} -lt ${loop_limit} ]]; do
		ce=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where \`command\`= \"FetchFeaturedPosts\" and regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from tmp_url) and \`done\` = 0 limit ${ce}; select row_count();")
		cemax=$((cemax + ce))
		printf "\rFetchFeaturedPosts\t%s\r" "${cemax}" #&> /dev/null
	done
	printf "\rFetchFeaturedPosts\t%s\n\r" "${cemax}" #&> /dev/null

	cf=${loop_limit}
	cfmax=0
	until [[ ${cf} -lt ${loop_limit} ]]; do
		#cf=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', ''), '\\\\\\\\', ''), '.*\"actor\"\:\"', ''), '\".*', '') not in (select \`url\` from \`tmp_url\`) and \`command\` = \"FetchMissingReplies\" and \`done\` = 0 limit ${cf}; select row_count();")
		cf=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where not (regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\\\\\\', ''), '.*\"actor\"\:\"', ''), '\".*', '') in (select \`url\` from \`tmp_url\`) or regexp_replace(regexp_replace(regexp_replace(\`parameter\`, '\\\\\\\\', ''), '.*\"audience\"\:\"', ''), '\".*', '') in (select \`url\` from \`tmp_url\`)) and \`command\` = \"FetchMissingReplies\" and \`done\` = 0 limit ${cf}; select row_count();")
		cfmax=$((cfmax + cf))
		printf "\rFetchMissingReplies\t%s\r" "${cfmax}" #&> /dev/null
	done
	"${dbengine}" "${db}" -B -N -q -e "drop table if exists tmp_url"
	printf "\rFetchMissingReplies\t%s\n\r" "${cfmax}" #&> /dev/null

	cg=${loop_limit}
	cgmax=0
	until [[ ${cg} -lt ${loop_limit} ]]; do
		cg=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where command=\"ProcessQueue\" and regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`workerqueue\`) and pid=0 and done=0 limit ${cg}; select row_count();")
		cgmax=$((cgmax + cg))
		printf "\rProcessQueue\t\t%s\r" "${cgmax}" #&> /dev/null
	done
	printf "\rProcessQueue\t\t%s\n\r" "${cgmax}" #&> /dev/null

	ch=${loop_limit}
	chmax=0
	until [[ ${ch} -lt ${loop_limit} ]]; do
		ch=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`)) and \`command\` = \"OnePoll\" and \`done\` = 0 limit ${ch}; select row_count();")
		chmax=$((chmax + ch))
		printf "\rOnePoll\t\t\t%s\r" "${chmax}" #&> /dev/null
	done
	printf "\rOnePoll\t\t\t%s\n\r" "${chmax}" #&> /dev/null

	ci=${loop_limit}
	cimax=0
	until [[ ${ci} -lt ${loop_limit} ]]; do
		#ci=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where \`id\` in (select distinct w2.\`id\` from workerqueue w1 inner join workerqueue w2 where w1.\`id\` > w2.\`id\` and w1.\`parameter\` = w2.\`parameter\` and w1.command = \"UpdateContact\" and w1.\`pid\` = 0 and w1.\`done\` = 0) limit ${ci}; select row_count();")
		ci=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where \`id\` in (select distinct w2.\`id\` from workerqueue w1 inner join workerqueue w2 where w1.\`id\` > w2.\`id\` and w1.\`parameter\` = w2.\`parameter\` and w1.command = w2.command and w1.\`done\` = 0) limit ${ci}; select row_count();")
		cimax=$((cimax + ci))
		printf "\rWorkerQueue\t\t%s\r" "${cimax}" #&> /dev/null
	done
	printf "\rWorkerQueue\t\t%s\n\r" "${cimax}" #&> /dev/null

	cj=${loop_limit}
	cjmax=0
	until [[ ${cj} -lt ${loop_limit} ]]; do
		cj=$("${dbengine}" "${db}" -B -N -q -e "delete from workerqueue where \`command\` = \"FetchMissingActivity\" and (\`parameter\` like \"%relay.%/actor%\" or \`parameter\` like \"%relay.fedi.buzz%\") and done = 0 limit ${cj}; select row_count();")
		cjmax=$((cjmax + cj))
		printf "\rFetchMissingActivity\t%s\r" "${cjmax}" #&> /dev/null
	done
	printf "\rFetchMissingActivity\t%s\n\r" "${cjmax}" #&> /dev/null
fi
