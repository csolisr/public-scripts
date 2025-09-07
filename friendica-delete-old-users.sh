#!/bin/bash
#Check for mariadb vs. mysql
dbengine=""
dboptimizeengine=""
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
	dboptimizeengine="mariadb-optimize"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
	dboptimizeengine="mysqloptimize"
else
	exit
fi
intense_optimizations=${1:-"0"}
period_amount=${2:-"12"}
starterid=${3:-"0"}
db="friendica"
period="${period_amount} MONTH"
tmpfile=/tmp/friendica-delete-old-users.csv
tmplock=/tmp/friendica-delete-old-users.tmp
loopsize=10000

loop() {
	baseurltrimmed=$(echo "${baseurl}" | sed -e "s/http[s]*:\/\///g")
	#TODO: Parallelize in batches
	mapfile -t resultarray < <("${dbengine}" "${db}" -N -B -q -e "\
		create temporary table tmp_post_thread (select \`uri-id\` from \`post-thread\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete h.* from \`post-thread\` h inner join \`tmp_post_thread\` t where h.\`uri-id\` = t.\`uri-id\`; select row_count(); \
		create temporary table tmp_post_thread_user (select \`uri-id\` from \`post-thread-user\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete r.* from \`post-thread-user\` r inner join \`tmp_post_thread_user\` t where r.\`uri-id\` = t.\`uri-id\`; select row_count(); \
		create temporary table tmp_post_user (select \`id\` from \`post-user\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete u.* from \`post-user\` u inner join \`tmp_post_user\` t where u.\`id\` = t.\`id\`; select row_count(); \
		delete from \`post-tag\` where cid = ${id}; select row_count(); \
		create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete p.* from \`post-content\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count(); \
		delete p.* from \`post\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count(); \
	" || echo "0 0 0 0 0 0")
	read -r postthreadcount postthreadusercount postusercount posttagcount postcontentcount postcount < <(echo "${resultarray[*]}")
	#postthreadcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread (select \`uri-id\` from \`post-thread\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete h.* from \`post-thread\` h inner join \`tmp_post_thread\` t where h.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	#postthreadusercount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread_user (select \`uri-id\` from \`post-thread-user\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete r.* from \`post-thread-user\` r inner join \`tmp_post_thread_user\` t where r.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	#postusercount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_user (select \`id\` from \`post-user\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete u.* from \`post-user\` u inner join \`tmp_post_user\` t where u.\`id\` = t.\`id\`; select row_count();" || echo 0)
	#posttagcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`post-tag\` where cid = ${id}; select row_count();" || echo 0)
	#postcontentcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete p.* from \`post-content\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	#postcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete p.* from \`post\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	lastitemid="${id}"
	if [[ "${intense_optimizations}" -eq 0 || "${intense_optimizations}" -eq 1 ]]; then
		if [[ -n $(type flock) ]]; then
			isreadlocked=0
			while [[ "${isreadlocked}" -eq 0 ]]; do
				exec 9>"${tmplock}"
				if flock -n -e 9; then
					isreadlocked=1
					if [[ -f "${tmpfile}" ]]; then
						while read -r tmp_counter tmp_lastitemid tmp_postthreadcount tmp_postthreadusercount tmp_postusercount tmp_posttagcount tmp_postcontentcount tmp_postcount; do
							if [[ "${id}" -gt "${lastitemid}" ]]; then
								lastitemid="${id}"
							fi
							if [[ -n "${tmp_postthreadcount}" ]]; then
								postthreadcount=$((postthreadcount + tmp_postthreadcount))
							fi
							if [[ -n "${tmp_postthreadusercount}" ]]; then
								postthreadusercount=$((postthreadusercount + tmp_postthreadusercount))
							fi
							if [[ -n "${tmp_postusercount}" ]]; then
								postusercount=$((postusercount + tmp_postusercount))
							fi
							if [[ -n "${tmp_posttagcount}" ]]; then
								posttagcount=$((posttagcount + tmp_posttagcount))
							fi
							if [[ -n "${tmp_postcontentcount}" ]]; then
								postcontentcount=$((postcontentcount + tmp_postcontentcount))
							fi
							if [[ -n "${tmp_postcount}" ]]; then
								postcount=$((postcount + tmp_postcount))
							fi
						done <"${tmpfile}"
						flock -u 9
						iswritelocked=0
						while [[ "${iswritelocked}" -eq 0 ]]; do
							exec 9>"${tmplock}"
							if flock -n -e 9; then
								iswritelocked=1
								echo "${counter} ${lastitemid} ${postthreadcount} ${postthreadusercount} ${postusercount} ${posttagcount} ${postcontentcount} ${postcount}" >"${tmpfile}"
								flock -u 9
							fi
						done
					fi
				fi
			done
		else
			if [[ -f "${tmpfile}" ]]; then
				while read -r tmp_counter tmp_lastitemid tmp_postthreadcount tmp_postthreadusercount tmp_postusercount tmp_posttagcount tmp_postcontentcount tmp_postcount; do
					if [[ "${id}" -gt "${lastitemid}" ]]; then
						lastitemid="${id}"
					fi
					if [[ -n "${tmp_postthreadcount}" ]]; then
						postthreadcount=$((postthreadcount + tmp_postthreadcount))
					fi
					if [[ -n "${tmp_postthreadusercount}" ]]; then
						postthreadusercount=$((postthreadusercount + tmp_postthreadusercount))
					fi
					if [[ -n "${tmp_postusercount}" ]]; then
						postusercount=$((postusercount + tmp_postusercount))
					fi
					if [[ -n "${tmp_posttagcount}" ]]; then
						posttagcount=$((posttagcount + tmp_posttagcount))
					fi
					if [[ -n "${tmp_postcontentcount}" ]]; then
						postcontentcount=$((postcontentcount + tmp_postcontentcount))
					fi
					if [[ -n "${tmp_postcount}" ]]; then
						postcount=$((postcount + tmp_postcount))
					fi
				done <"${tmpfile}"
				echo "${counter} ${lastitemid} ${postthreadcount} ${postthreadusercount} ${postusercount} ${posttagcount} ${postcontentcount} ${postcount}" >"${tmpfile}"
			fi
		fi
	fi
	if [[ -n "${lastitem}" && "${#lastitem}" -gt 9 ]]; then
		response_left=$(printf "%s %s %s %s@%s " "${counter}" "${id}" "${lastitem::-9}" "${nick}" "${baseurltrimmed}")
		if [[ "${intense_optimizations}" -eq 0 || "${intense_optimizations}" -eq 1 ]]; then
			response=$(printf "%spost-thread:%s " "${response}" "${postthreadcount}")
			response=$(printf "%spost-thread-user:%s " "${response}" "${postthreadusercount}")
			response=$(printf "%spost-user:%s " "${response}" "${postusercount}")
			response=$(printf "%spost-tag:%s " "${response}" "${posttagcount}")
			response=$(printf "%spost-content:%s " "${response}" "${postcontentcount}")
			response=$(printf "%spost:%s " "${response}" "${postcount}")
		else
			response=""
		fi
		#Previous line clearance
		#Measure length of string, blank only the excess
		#Since this string is panned to both sides, we will need to account for two lengths
		final_string_length_left="${#response_left}"
		final_string_length_right="${#response}"
		final_string_length=$((final_string_length_left + final_string_length_right))
		#The string that will be used to insert the blanks
		blank_string=""
		columns_length="${COLUMNS}"
		#Account for the case where the string is more than a terminal line long
		while [[ "${final_string_length}" -gt "${columns_length}" ]]; do
			columns_length=$((columns_length + COLUMNS))
		done
		blank_string_length=$((columns_length - final_string_length))
		#Add enough blank spaces to fill the rest of the line
		for ((count = 0; count < "${blank_string_length}"; count++)); do
			blank_string=$(printf "%s " "${blank_string}")
		done
		#Add backspaces to align the next output
		for ((count = 0; count < $((final_string_length + blank_string_length)); count++)); do
			response_left=$(printf "\b%s" "${response_left}")
		done
		response=$(printf "%s%s%s" "${response_left}" "${blank_string}" "${response}")
		printf "%s\r" "${response}"
	fi
}

#Check if our dependencies are installed
if [[ -n $(type curl) && -n "${dbengine}" && -n $(type "${dbengine}") && -n $(type date) ]]; then
	date
	if [[ -f "${tmpfile}" ]]; then
		rm -rf "${tmpfile}"
	fi
	if [[ -f "${tmplock}" ]]; then
		rm -rf "${tmplock}"
	fi
	touch "${tmpfile}"
	echo "0 0 0 0 0 0 0 0" >"${tmpfile}"
	if [[ "${intense_optimizations}" -gt 0 ]]; then
		"${dbengine}" "${db}" -v -e "alter table \`contact\` add index if not exists \`tmp_contact_baseurl_addr\` (baseurl, addr)"
		"${dbengine}" "${db}" -v -e "alter table \`post-thread\` add index if not exists \`tmp_post_thread_id\` (\`owner-id\`, \`author-id\`, \`causer-id\`)"
		"${dbengine}" "${db}" -v -e "alter table \`post-thread-user\` add index if not exists \`tmp_post_thread_user_id\` (\`owner-id\`, \`author-id\`, \`causer-id\`)"
		"${dbengine}" "${db}" -v -e "alter table \`post-user\` add index if not exists \`tmp_post_user_id\` (\`owner-id\`, \`author-id\`, \`causer-id\`)"
		"${dbengine}" "${db}" -v -e "alter table \`post\` add index if not exists \`tmp_post_id\` (\`owner-id\`, \`author-id\`, \`causer-id\`)"
	fi
	counter=0
	was_empty=0
	while [[ "${was_empty}" -eq 0 ]]; do
		current_counter=0
		currentid="${starterid}"
		while read -r tmp_counter tmp_lastitemid tmp_postthreadcount tmp_postthreadusercount tmp_postusercount tmp_posttagcount tmp_postcontentcount tmp_postcount; do
			if [[ -n "${tmp_counter}" && -n "${tmp_lastitemid}" && "${currentid}" -lt "${tmp_lastitemid}" ]]; then
				currentid="${tmp_lastitemid}"
			fi
		done <"${tmpfile}"
		while read -r id nick baseurl lastitem; do
			#TODO: send in batches
			counter=$((counter + 1))
			current_counter=$((current_counter + 1))
			loop "${id}" "${nick}" "${baseurl}" "${lastitem}" "${counter}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
		done < <("${dbengine}" "${db}" -N -B -q -e \
			"select \`id\`, \`nick\`, \`baseurl\`, \`last-item\` from contact c where c.\`addr\` not in (\
				select \`addr\` from \`contact\` where \
				\`id\` in (select \`cid\` from \`user-contact\`) or \
				\`id\` in (select \`uid\` from \`user\`) or \
				\`id\` in (select \`contact-id\` from \`group_member\`) \
			) and \
			(c.\`id\` in (select \`owner-id\` from \`post\`)  or c.\`id\` in (select \`author-id\` from \`post\`) or c.\`id\` in (select \`causer-id\` from \`post\`)) and \
			c.\`contact-type\` != 4 and not pending and  \`last-item\` < CURDATE() - INTERVAL ${period} and \`last-item\` > '0001-01-01' and \
			c.\`id\` > ${currentid} limit ${loopsize}")
		wait
		if [[ "${current_counter}" -eq 0 || "${current_counter}" -lt "${loopsize}" ]]; then
			was_empty=1
		fi
	done
	printf "\n\r"
	if [[ "${intense_optimizations}" -gt 0 ]]; then
		"${dbengine}" "${db}" -v -e "\
			alter table \`post-thread\` auto_increment = 1; \
			alter table \`post-thread-user\` auto_increment = 1; \
			alter table \`post-user\` auto_increment = 1; \
			alter table \`post-tag\` auto_increment = 1; \
			alter table \`post\` auto_increment = 1; \
		"
		"${dbengine}" "${db}" -v -e "alter table \`contact\` drop index \`tmp_contact_baseurl_addr\`"
		"${dbengine}" "${db}" -v -e "alter table \`post-thread\` drop index  \`tmp_post_thread_id\`"
		"${dbengine}" "${db}" -v -e "alter table \`post-thread-user\` drop index \`tmp_post_thread_user_id\`"
		"${dbengine}" "${db}" -v -e "alter table \`post-user\` drop index \`tmp_post_user_id\`"
		"${dbengine}" "${db}" -v -e "alter table \`post\` drop index \`tmp_post_id\`"
		"${dboptimizeengine}" "${db}"
	fi
	if [[ -n $(type flock) ]]; then
		flock -u 9 2>/dev/null
	fi
	if [[ -f "${tmpfile}" ]]; then
		rm -rf "${tmpfile}"
	fi
	if [[ -f "${tmplock}" ]]; then
		rm -rf "${tmplock}"
	fi
	date
fi
