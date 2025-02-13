#!/bin/bash
#Set your parameters here
url=friendica.example.net
user=friendica
group=www-data
fileperm=660
dbengine=""
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
else
	exit
fi
db=friendica
folder=/var/www/friendica
timeout=60
#Command-line parameter number 1: whether to enable the more intensive optimizations (1=on). Defaults to 0=off.
intensive_optimizations=${1:-"0"}
if [[ "${intensive_optimizations}" != "0" && "${intensive_optimizations}" != "1" ]]; then
	intensive_optimizations=0
fi
#Command-line parameter number 2: multiplier for the amount of threads, 1 = as many as the device has cores. Defaults to 1.
thread_multiplier=${2:-"1"}
if [[ ! "${thread_multiplier}" =~ ^[0-9]+$ || $((10#${thread_multiplier})) -le 0 ]]; then
	thread_multiplier=1
fi
#Command-line parameter number 3: whether to display the amount of time taken for certain processes (1=on). Defaults to 0=off.
time_counter=${3:-"0"}
if [[ "${time_counter}" != "0" && "${time_counter}" != "1" ]]; then
	time_counter=0
fi
#Command-line parameter number 4: last known ID to have been successfully processed. Defaults to 0
lastid=${4:-"0"}
if [[ ! "${lastid}" =~ ^[0-9]+$ || $((10#${lastid})) -le 0 ]]; then
	lastid=0
fi
nfolder="/tmp/friendica-remove-invalid-photos"
nfile="${nfolder}/n$(date +%s).csv"
nlock="${nfolder}/n$(date +%s).lock"
if [[ ! -d "${nfolder}" ]]; then
	mkdir "${nfolder}"
fi
if [[ -f "${nfile}" ]]; then
	rm -rf "${nfile}" && touch "${nfile}"
else
	touch "${nfile}"
fi
if [[ -f "${nlock}" ]]; then
	rm -rf "${nlock}" && touch "${nlock}"
else
	touch "${nlock}"
fi
#Internal parameters:
#Number of invalid avatars found
n=0
#Total number of entries processed
nt=0
#Highest possible ID known
maxid=$("${dbengine}" "${db}" -B -N -q -e "select max(\`id\`) from contact")
#Limit per batch
#limit=$(((maxid / 1000) + 1))
limit="${maxid}"
dbcount=0
idcount=0
if [[ "${intensive_optimizations}" -gt 0 ]]; then
	#https:// = 8 characters | /avatar/ = 8 characters
	indexlength=$(("${#url}" + 16))
	"${dbengine}" "${db}" -e "alter table contact add index if not exists photo_index (photo(${indexlength}))"
	dbcount=$("${dbengine}" "${db}" -B -N -q -e "select count(\`id\`) from \`contact\` where \`id\` > ${lastid} and (\`photo\` like 'https:\/\/${url}/avatar/%' or (\`photo\` = '' and not \`avatar\` = '') or (\`avatar\` = '' and not \`photo\` = ''))")
else
	dbcount=$("${dbengine}" "${db}" -B -N -q -e "select count(\`id\`) from \`contact\` where \`id\` > ${lastid} and (\`photo\` like 'https:\/\/${url}/avatar/%' or (\`photo\` = '' and not \`avatar\` = '') or (\`avatar\` = '' and not \`photo\` = '')) and (\`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`) or \`id\` in (select \`contact-id\` from \`group_member\`))")
fi

loop() {
	if [[ "${time_counter}" -eq 1 ]]; then
		t_id=$(($(date +%s%N) / 1000000))
	fi
	result_string=""
	nl=0
	error_found=0
	#Lockfile-protected read
	r=0
	if [[ "${time_counter}" -eq 1 ]]; then
		t_r=$(($(date +%s%N) / 1000000))
	fi
	#Fallback in case the process dies
	(
		sleep "${timeout}"s
		if [[ "${r}" -eq 0 ]]; then
			rm -rf "${nlock}"
		fi
	) &
	while [[ "${r}" -eq 0 ]]; do
		if [[ ! -d "${nfolder}" ]]; then
			mkdir "${nfolder}"
		fi
		if [[ ! -f "${nlock}" ]]; then
			touch "${nlock}"
		fi
		if [[ -f "${nlock}" && $(cat "${nlock}" 2>/dev/null || echo 0) == "" ]]; then
			rm -rf "${nlock}" && touch "${nlock}" && echo "${id}" | tee "${nlock}" &>/dev/null
			if [[ -f "${nlock}" && $(grep -e "[0-9]" "${nlock}" 2>/dev/null || echo 0) == "${id}" ]]; then
				read -r n_tmp nt_tmp <"${nfile}" || break
				if [[ -n "${n_tmp}" && -n "${nt_tmp}" ]]; then
					n="${n_tmp}"
					nt="${nt_tmp}"
					if [[ -f "${nlock}" ]]; then
						rm -rf "${nlock}" && touch "${nlock}" && echo "" >"${nlock}"
					fi
					r=1
				fi
			elif [[ -f "${nlock}" ]]; then
				nlm=$(grep -e "[0-9]" "${nlock}" 2>/dev/null || echo 0)
				if [[ -n "${nlm}" ]]; then
					nlmt=$((10#${nlm}))
					if [[ "${nlmt}" -lt $((id + limit)) ]]; then
						rm -rf "${nlock}" && touch "${nlock}" && echo "" >"${nlock}"
					fi
				else
					rm -rf "${nlock}" && touch "${nlock}" && echo "" >"${nlock}"
				fi
			fi
		fi
	done
	if [[ "${time_counter}" -eq 1 ]]; then
		result_string=$(printf "%s R%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t_r)))
	fi
	if [[ -n "${id}" ]]; then
		while read -r avatar photo thumb micro; do
			if [[ -n "${photo}" && -n "${thumb}" && -n "${micro}" ]]; then
				#If there is a photo
				folderescaped=${folder////\\/}
				#Substitute the URL path with the folder path so we can search for it in the local file system
				#Photo is nominally 320px, actually 300px
				k_photo=$(sed -e "s/https:\/\/${url}/${folderescaped}/g" -e "s/\?ts=.*//g" <<<"${photo}")
				#Thumb is 80px
				k_thumb=$(sed -e "s/https:\/\/${url}/${folderescaped}/g" -e "s/\?ts=.*//g" <<<"${thumb}")
				#Micro is 48px
				k_micro=$(sed -e "s/https:\/\/${url}/${folderescaped}/g" -e "s/\?ts=.*//g" <<<"${micro}")
				#If any of the images is not found in the filesystem
				if [[ ! -e "${k_photo}" || ! -e "${k_thumb}" || ! -e "${k_micro}" ]]; then
					#If the avatar uses the standard fallback picture or is local, we cannot use it as a base
					#If we have a remote avatar as a fallback, download it
					if [[ -n "${avatar}" && $(grep -q -v -e "${url}" -e "images/person" <(echo "${avatar}")) -gt 0 ]]; then
						result_string=$(printf "%s Remote %s" "${result_string}" "${avatar}")
						nl=1
						sudo -u "${user}" curl "${avatar}" -s -o "${k_photo}"
						#If the file is a valid picture (not empty, not text)
						if file "${k_photo}" | grep -q -v -e "text" -e "empty" -e "symbolic link" -e "directory"; then
							#Also fetch for thumb/micro and resize
							#As the photo is the largest version we have, we will use it as the base, and leave it last to convert
							convert "${k_photo}" -resize 80x80 -depth 16 "${k_thumb}" && chmod "${fileperm}" "${k_thumb}" && chown "${user}:${group}" "${k_thumb}"
							convert "${k_photo}" -resize 48x48 -depth 16 "${k_micro}" && chmod "${fileperm}" "${k_micro}" && chown "${user}:${group}" "${k_micro}"
							convert "${k_photo}" -resize 300x300 -depth 16 "${k_photo}" && chmod "${fileperm}" "${k_photo}" && chown "${user}:${group}" "${k_photo}"
							result_string=$(printf "%s (generated)" "${result_string}")
							error_found=1
						else
							#If the avatar is not valid, set it as blank in the database
							"${dbengine}" "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
							rm -rf "${k_photo}" "${k_thumb}" "${k_micro}"
							result_string=$(printf "%s (blanked)" "${result_string}")
							error_found=1
						fi
					else
						result_string=$(printf "%s No remote" "${result_string}")
						#If no remote avatar is found, then we blank the photo/thumb/micro and let the avatar cache process fix them later
						"${dbengine}" "${db}" -N -B -q -e "update contact set photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
						result_string=$(printf "%s (blanked)" "${result_string}")
						error_found=1
					fi
				else
					if [[ "${time_counter}" -eq 1 ]]; then
						t=$(($(date +%s%N) / 1000000))
					fi
					#If the images are all found in the filesystem, but fetching any of the images causes an error
					if [[ -s $(curl --fail-early \
						-s "${photo}" -X HEAD -I --http2-prior-knowledge -4 -N --next \
						-s "${thumb}" -X HEAD -I --http2-prior-knowledge -4 -N --next \
						-s "${micro}" -X HEAD -I --http2-prior-knowledge -4 -N |
						grep -q "content-type: image") ]]; then
						if [[ "${time_counter}" -eq 1 ]]; then
							result_string=$(printf "%s F%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t)))
						fi
						result_string=$(printf "${result_string} Fetch error: %s" "${photo}")
						"${dbengine}" "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
						result_string=$(printf "%s (blanked)" "${result_string}")
						nl=1
						error_found=1
					else
						if [[ "${time_counter}" -eq 1 ]]; then
							result_string=$(printf "%s F%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t)))
						fi
						result_string=$(printf "%s (FOUND)" "${result_string}")
						error_found=0
					fi
				fi
			else
				#If there is no photo
				result_string=$(printf "%s No local" "${result_string}")
				#If the avatar uses the standard fallback picture or is local, we cannot use it as a base
				#If we have a remote avatar as a fallback, download it
				if [[ -n "${avatar}" && $(grep -q -v -e "${url}" -e "images/person" <(echo "${avatar}")) -gt 0 ]]; then
					result_string=$(printf "${result_string} Remote %s" "${avatar}")
					nl=1
					sudo -u "${user}" curl "${avatar}" -s -o "${k_photo}"
					#If the file is a valid picture (not empty, not text)
					if file "${k_photo}" | grep -q -v -e "text" -e "empty" -e "symbolic link" -e "directory"; then
						#Also fetch for thumb/micro and resize
						#As the photo is the largest version we have, we will use it as the base, and leave it last to convert
						convert "${k_photo}" -resize 80x80 -depth 16 "${k_thumb}" && chmod "${fileperm}" "${k_thumb}" && chown "${user}:${group}" "${k_thumb}"
						convert "${k_photo}" -resize 48x48 -depth 16 "${k_micro}" && chmod "${fileperm}" "${k_micro}" && chown "${user}:${group}" "${k_micro}"
						convert "${k_photo}" -resize 300x300 -depth 16 "${k_photo}" && chmod "${fileperm}" "${k_photo}" && chown "${user}:${group}" "${k_photo}"
						result_string=$(printf "%s (generated)" "${result_string}")
						error_found=1
					else
						#If the avatar is not valid, set it as blank in the database
						"${dbengine}" "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
						rm -rf "${k_photo}" "${k_thumb}" "{k_micro}"
						result_string=$(printf "%s (blanked)" "${result_string}")
						error_found=1
					fi
				else
					result_string=$(printf "%s No remote" "${result_string}")
					#If the avatar is not valid, set it as blank in the database
					"${dbengine}" "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
					result_string=$(printf "%s (blanked)" "${result_string}")
					#If no remote avatar is found, we would blank the photo/thumb/micro and let the avatar cache process fix them later, but it's empty already here
					error_found=1
				fi
			fi
			if [[ "${error_found}" -gt 0 ]]; then
				"${dbengine}" "${db}" -N -B -q -e "insert ignore into workerqueue (command, parameter, priority, created) \
						values (\"UpdateContact\", \"[${id}]\", 20, concat(curdate(), \" \", curtime()));"
				result_string=$(printf "%s (added)" "${result_string}")
				nl=1
			fi
			lastid="${id}"
		done < <("${dbengine}" "${db}" -B -N -q -e "select \`avatar\`, \`photo\`, \`thumb\`, \`micro\` from \`contact\` where \`id\` = ${id}")
	fi
	w=0
	if [[ "${time_counter}" -eq 1 ]]; then
		t_w=$(($(date +%s%N) / 1000000))
	fi
	while [[ "${w}" -eq 0 ]]; do
		if [[ ! -d "${nfolder}" ]]; then
			mkdir "${nfolder}"
		fi
		if [[ ! -f "${nlock}" ]]; then
			#n is increased only if error_found = 1
			touch "${nlock}"
		fi
		if [[ -f "${nlock}" && $(cat "${nlock}" 2>/dev/null || echo "") == "" ]]; then
			rm -rf "${nlock}" && touch "${nlock}" && echo "${id}" | tee "${nlock}" &>/dev/null
			if [[ -f "${nlock}" && $(grep -e "[0-9]" "${nlock}" 2>/dev/null || echo 0) == "${id}" ]]; then
				read -r n_tmp nt_tmp <"${nfile}" || break
				if [[ -n "${n_tmp}" && -n "${nt_tmp}" ]]; then
					if [[ $(grep -e "[0-9]" "${nlock}" 2>/dev/null || echo 0) == "${id}" ]]; then
						if [[ "${n_tmp}" -ge "${n}" ]]; then
							n=$((n_tmp + error_found))
						else
							n=$((n + error_found))
						fi
						if [[ "${nt_tmp}" -ge "${nt}" ]]; then
							nt=$((nt_tmp + 1))
						else
							nt=$((nt + 1))
						fi
						echo "${n} ${nt}" >"${nfile}"
						if [[ -f "${nlock}" ]]; then
							rm -rf "${nlock}" && touch "${nlock}" && echo "" >"${nlock}"
						fi
						w=1
					fi
				fi
			fi
		fi
	done
	if [[ "${time_counter}" -eq 1 ]]; then
		result_string=$(printf "%s W%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t_w)))
		result_string=$(printf "%s T%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t_id)))
	fi
	final_string=$(printf "E%8d F%8d/%8d T%8d/%8d %s" "${n}" "${nt}" "${dbcount}" "${lastid}" "${maxid}" "${result_string}")
	final_string_length="${#final_string}"
	#Previous line clearance
	#Measure length of string, blank only the excess
	blank_string=""
	blank_string_length=$((COLUMNS - final_string_length))
	for ((count = 0; count < "${blank_string_length}"; count++)); do
		blank_string=$(printf "%s " "${blank_string}")
	done
	final_string=$(printf "%s%s" "${final_string}" "${blank_string}")
	for ((count = 0; count < "${blank_string_length}"; count++)); do
		final_string=$(printf "%s\b" "${final_string}")
	done
	#Add a new line only when necessary
	if [[ "${nl}" -eq 1 ]]; then
		final_string=$(printf "%s\n\r\n" "${final_string}")
	fi
	printf "%s\r" "${final_string}"
}

#Go to the Friendica installation
cd "${folder}" || exit
echo "${n} ${nt}" >"${nfile}"
#until [[ "${idcount}" -ge "${dbcount}" || "${nt}" -gt "${dbcount}" || "${lastid}" -gt "${maxid}" ]]; do
c=""
if [[ "${intensive_optimizations}" -gt 0 ]]; then
	c=$("${dbengine}" "${db}" -B -N -q -e "select \`id\` from \`contact\` where \`id\` > ${lastid} and (\`photo\` like 'https:\/\/${url}/avatar/%' or (\`photo\` = '' and not \`avatar\` = '') or (\`avatar\` = '' and not \`photo\` = '')) order by id limit ${limit}")
else
	c=$("${dbengine}" "${db}" -B -N -q -e "select \`id\` from \`contact\` where \`id\` > ${lastid} and (\`photo\` like 'https:\/\/${url}/avatar/%' or (\`photo\` = '' and not \`avatar\` = '') or (\`avatar\` = '' and not \`photo\` = '')) and (id in (select cid from \`user-contact\`) or id in (select \`uid\` from \`user\`) or \`id\` in (select \`contact-id\` from \`group_member\`)) order by id limit ${limit}")
fi
while read -r id; do
	if [[ -n "${id}" && $((10#${id})) -ge "${lastid}" ]]; then
		lastid=$((10#${id}))
		id=$((10#${id}))
	fi
	if [[ -n "${lastid}" ]]; then
		idcount=$((idcount + 1))
		loop &
	fi
	until [[ $(jobs -r -p | wc -l) -lt $(($(getconf _NPROCESSORS_ONLN) * thread_multiplier)) ]]; do
		wait -n
	done
done < <(echo "${c}")
wait
#Read data before next iteration
rl=0
(
	sleep 60s
	if [[ "${rl}" -eq 0 ]]; then rm -rf "${nlock}"; fi
) &
while [[ "${rl}" -eq 0 ]]; do
	if [[ ! -f "${nlock}" ]]; then
		touch "${nlock}"
	fi
	if [[ -f "${nlock}" && $(cat "${nlock}" 2>/dev/null || echo "") == "" ]]; then
		rm -rf "${nlock}" && touch "${nlock}" && echo "${lastid}" | tee "${nlock}" &>/dev/null
		if [[ -f "${nlock}" && $(grep -e "[0-9]" "${nlock}" 2>/dev/null || echo 0) == "${lastid}" ]]; then
			read -r n_tmp_l nt_tmp_l <"${nfile}" || break
			if [[ -n "${n_tmp_l}" && -n "${nt_tmp_l}" ]]; then
				n="${n_tmp_l}"
				nt="${nt_tmp_l}"
				if [[ -f "${nlock}" ]]; then
					rm -rf "${nlock}" && touch "${nlock}" && echo "" >"${nlock}"
				fi
				rl=1
			fi
		elif [[ -f "${nlock}" ]]; then
			nlm=$(grep -e "[0-9]" "${nlock}" 2>/dev/null || echo 0)
			if [[ -n "${nlm}" ]]; then
				nlmt=$((10#${nlm}))
				if [[ "${nlmt}" -lt $((id + limit)) ]]; then
					rm -rf "${nlock}" && touch "${nlock}" && echo "" >"${nlock}"
				fi
			else
				rm -rf "${nlock}" && touch "${nlock}" && echo "" >"${nlock}"
			fi
		fi
	fi
done
#done
if [[ -f "${nfile}" ]]; then
	rm -rf "${nfile}"
fi
if [[ -f "${nlock}" ]]; then
	rm -rf "${nlock}"
fi
if [[ ! -d "${nfolder}" && $(find "${nfolder}" | wc -l) -eq 0 ]]; then
	rm -rf "${nfolder}"
fi
"${dbengine}" "${db}" -e "delete from workerqueue where \`id\` in (select distinct w2.\`id\` from workerqueue w1 inner join workerqueue w2 where w1.\`id\` > w2.\`id\` and w1.\`parameter\` = w2.\`parameter\` and w1.\`command\` = \"UpdateContact\" and w1.\`done\` = 0)"
if [[ "${intensive_optimizations}" -gt 0 ]]; then
	"${dbengine}" "${db}" -e "alter table contact drop index photo_index"
fi
