#!/bin/bash
#Check for mariadb vs. mysql
dbengine=""
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
else
	exit
fi
intense_optimizations=${1:-"0"}
db="friendica"
period="1 MONTH"
tmpfile=/tmp/friendica-delete-old-users.csv
url=friendica.example.net
avatarfolder=/var/www/friendica/avatar
avatarfolderescaped=${avatarfolder////\\/}

loop() {
	baseurltrimmed=$(echo "${baseurl}" | sed -e "s/http[s]*:\/\///g")
	#Find the pictures in the avatar folders and delete them
	picturecount=0
	while read -r photo thumb micro; do
		#If stored in avatar folder
		if grep -v -q "${url}/avatar" <(echo "${photo}"); then
			#if [[ -z "${isavatar}" ]]
			phototrimmed=$(echo "${photo}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${phototrimmed}"
			thumbtrimmed=$(echo "${thumb}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${thumbtrimmed}"
			microtrimmed=$(echo "${micro}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${microtrimmed}"
			picturecount=1
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e "select \`photo\`, \`thumb\`, \`micro\` from \`contact\` where \`id\` = ${id}")
	postthreadcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread (select \`uri-id\` from \`post-thread\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete h.* from \`post-thread\` h inner join \`tmp_post_thread\` t where h.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	postthreadusercount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread_user (select \`uri-id\` from \`post-thread-user\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete r.* from \`post-thread-user\` r inner join \`tmp_post_thread_user\` t where r.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	postusercount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_user (select \`id\` from \`post-user\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete u.* from \`post-user\` u inner join \`tmp_post_user\` t where u.\`id\` = t.\`id\`; select row_count();" || echo 0)
	posttagcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`post-tag\` where cid = ${id}; select row_count();" || echo 0)
	postcontentcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete p.* from \`post-content\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	postcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${id} or \`author-id\` = ${id} or \`causer-id\` = ${id}); delete p.* from \`post\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();" || echo 0)
	photocount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`photo\` where \`contact-id\` = ${id}; select row_count();" || echo 0)
	contactcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`contact\` where \`id\` = ${id}; select row_count();" || echo 0)
	apcontactcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`apcontact\` where \`uri-id\` = ${id}; select row_count();" || echo 0)
	diasporacontactcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`diaspora-contact\` where \`uri-id\` = ${id}; select row_count();" || echo 0)
	while read -r tmp_counter tmp_picturecount tmp_postthreadcount tmp_postthreadusercount tmp_postusercount tmp_posttagcount tmp_postcontentcount tmp_postcount tmp_photocount tmp_contactcount tmp_apcontactcount tmp_diasporacontactcount; do
		if [[ "${tmp_counter}" -gt "${counter}" ]]; then
			counter=$((tmp_counter + 1))
		fi
		picturecount=$((picturecount + tmp_picturecount))
		postthreadcount=$((postthreadcount + tmp_postthreadcount))
		postthreadusercount=$((postthreadusercount + tmp_postthreadusercount))
		postusercount=$((postusercount + tmp_postusercount))
		posttagcount=$((posttagcount + tmp_posttagcount))
		postcontentcount=$((postcontentcount + tmp_postcontentcount))
		postcount=$((postcount + tmp_postcount))
		photocount=$((photocount + tmp_photocount))
		contactcount=$((contactcount + tmp_contactcount))
		apcontactcount=$((apcontactcount + tmp_apcontactcount))
		diasporacontactcount=$((diasporacontactcount + tmp_diasporacontactcount))
	done <"${tmpfile}"
	response_left=$(printf "%s %s %s %s@%s " "${counter}" "${id}" "${lastitem::-9}" "${nick}" "${baseurltrimmed}")
	response=$(printf "%spicture:%s " "${response}" "${picturecount}")
	response=$(printf "%spost-thread:%s " "${response}" "${postthreadcount}")
	response=$(printf "%spost-thread-user:%s " "${response}" "${postthreadusercount}")
	response=$(printf "%spost-user:%s " "${response}" "${postusercount}")
	response=$(printf "%spost-tag:%s " "${response}" "${posttagcount}")
	response=$(printf "%spost-content:%s " "${response}" "${postcontentcount}")
	response=$(printf "%spost:%s " "${response}" "${postcount}")
	response=$(printf "%sphoto:%s " "${response}" "${photocount}")
	response=$(printf "%scontact:%s " "${response}" "${contactcount}")
	response=$(printf "%sapcontact:%s " "${response}" "${apcontactcount}")
	response=$(printf "%sdiaspora-contact:%s " "${response}" "${diasporacontactcount}")
	echo "${counter}" "${picturecount}" "${postthreadcount} ${postthreadusercount} ${postusercount} ${posttagcount} ${postcontentcount} ${postcount} ${photocount} ${contactcount} ${apcontactcount} ${diasporacontactcount}" >"${tmpfile}"
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
}

#Check if our dependencies are installed
if [[ -n $(type curl) && -n "${dbengine}" && -n $(type "${dbengine}") && -n $(type date) ]]; then
	date
	touch "${tmpfile}"
	echo "0 0 0 0 0 0 0 0 0 0 0 0" >"${tmpfile}"
	if [[ "${intense_optimizations}" -gt 0 ]]; then
		"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` add index if not exists \`contact_baseurl\` (baseurl)"
	fi
	counter=0
	was_empty=0
	while [[ "${was_empty}" -eq 0 ]]; do
		current_counter=0
		while read -r id nick baseurl lastitem; do
			counter=$((counter + 1))
			current_counter=$((current_counter + 1))
			loop "${id}" "${nick}" "${baseurl}" "${lastitem}" "${counter}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
		done < <("${dbengine}" "${db}" -N -B -q -e \
			"select \`id\`, \`nick\`, \`baseurl\`, \`last-item\` from contact c where \
			c.\`id\` not in (select \`cid\` from \`user-contact\`) and \
			c.\`id\` not in (select \`uid\` from \`user\`) and \
			c.\`id\` not in ( select \`contact-id\` from \`group_member\`) and \
			c.\`contact-type\` != 4 and not pending and \`last-item\` < CURDATE() - INTERVAL ${period} limit 1000")
		wait
		if [[ "${current_counter}" -eq 0 ]]; then
			was_empty=1
		fi
	done
	printf "\n\r"
	if [[ "${intense_optimizations}" -gt 0 ]]; then
		"${dbengine}" "${db}" -N -B -q -e "alter table \`post-thread\` auto_increment = 1; \
			alter table \`post-thread-user\` auto_increment = 1; \
			alter table \`post-user\` auto_increment = 1; \
			alter table \`post-tag\` auto_increment = 1; \
			alter table \`post\` auto_increment = 1; \
			alter table \`photo\` auto_increment = 1; \
			alter table \`contact\` auto_increment = 1"
		"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` drop index \`contact_baseurl\`"
	fi
	rm -rf "${tmpfile}"
	date
fi
