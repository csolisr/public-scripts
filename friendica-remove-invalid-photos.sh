#!/bin/bash
#Set your parameters here
url=friendica.example.net
user=friendica
group=www-data
fileperm=660
db=friendica
folder=/var/www/friendica
nfile=/tmp/n.csv
nlock=/tmp/n.lock
if [[ -f ${nfile} ]]; then
	rm -rf "${nfile}" && touch "${nfile}"
else
	touch "${nfile}"
fi
if [[ -f ${nlock} ]]; then
	rm -rf "${nlock}"
fi
#Internal parameters:
#Amount of times the internal loop has run
batch=0
#Number of invalid avatars found.
n=0
#Number of entries processed this loop
nx=0
#Total number of entries processed
nt=0
#Last known ID to have been successfully processed
lastid=0
#Highest possible ID known
maxid=$(mariadb "${db}" -B -N -q -e "select max(\`id\`) from contact")
#Limit per batch
limit=$(((maxid / 1000) + 1))
#https:// = 8 characters | /avatar/ = 8 characters
#indexlength=$(("${#url}" + 16))
#mariadb "${db}" -e "alter table contact add index if not exists photo_index (photo(${indexlength}))"
#Add to the loop, reset values
#dbcount=$(mariadb "${db}" -B -N -q -e "select count(\`id\`) from contact where photo like 'https:\/\/${url}/avatar/%' and (id in (select cid from \`user-contact\`) or id in (select \`uid\` from \`user\`) or \`id\` in (select \`contact-id\` from \`group_member\`))")
dbcount=$(mariadb "${db}" -B -N -q -e "select count(\`id\`) from contact where photo like 'https:\/\/${url}/avatar/%'")

loop() {
	#Wait until lock no longer exists
	r=0
	while [[ "${r}" -eq 0 ]]; do
		#Read data from file, delete lock
		if [[ ! -f "${nlock}" ]]; then
			touch "${nlock}" && read -r lastid n nx nt <"${nfile}" && rm -rf "${nlock}" && r=1
		fi
	done
	nx=$(("${nx}" + 1))
	nt=$(("${nt}" + 1))
	#Continue only if lastid is lower than current id
	t_id=$(($(date +%s%N) / 1000000))
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
							(convert "${k_photo}" -resize 80x80 -depth 16 "${k_thumb}" && chmod "${fileperm}" "${k_thumb}" && chown "${user}:${group}" "${k_thumb}") &
							(convert "${k_photo}" -resize 48x48 -depth 16 "${k_micro}" && chmod "${fileperm}" "${k_micro}" && chown "${user}:${group}" "${k_micro}") &
							(convert "${k_photo}" -resize 300x300 -depth 16 "${k_photo}" && chmod "${fileperm}" "${k_photo}" && chown "${user}:${group}" "${k_photo}") &
							result_string=$(printf "%s (generated)" "${result_string}")
							error_found=1
						else
							#If the avatar is not valid, set it as blank in the database
							mariadb "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\"" &
							rm -rf "${k_photo}" "${k_thumb}" "${k_micro}" &
							result_string=$(printf "%s (blanked)" "${result_string}")
							error_found=1
						fi
					else
						result_string=$(printf "%s No remote" "${result_string}")
						#If no remote avatar is found, then we blank the photo/thumb/micro and let the avatar cache process fix them later
						mariadb "${db}" -N -B -q -e "update contact set photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\"" &
						result_string=$(printf "%s (blanked)" "${result_string}")
						error_found=1
					fi
				else
					t=$(($(date +%s%N) / 1000000))
					#If the images are all found in the filesystem, but fetching any of the images causes an error
					if [[ -s $(curl --fail-early \
						-s "${photo}" -X HEAD -I --http2-prior-knowledge -4 -N --next \
						-s "${thumb}" -X HEAD -I --http2-prior-knowledge -4 -N --next \
						-s "${micro}" -X HEAD -I --http2-prior-knowledge -4 -N |
						grep -q "content-type: image") ]]; then
						result_string=$(printf "%s F%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t)))
						result_string=$(printf "${result_string} Fetch error: %s" "${photo}")
						mariadb "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\"" &
						result_string=$(printf "%s (blanked)" "${result_string}")
						nl=1
						error_found=1
					else
						result_string=$(printf "%s F%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t)))
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
						(convert "${k_photo}" -resize 80x80 -depth 16 "${k_thumb}" && chmod "${fileperm}" "${k_thumb}" && chown "${user}:${group}" "${k_thumb}") &
						(convert "${k_photo}" -resize 48x48 -depth 16 "${k_micro}" && chmod "${fileperm}" "${k_micro}" && chown "${user}:${group}" "${k_micro}") &
						(convert "${k_photo}" -resize 300x300 -depth 16 "${k_photo}" && chmod "${fileperm}" "${k_photo}" && chown "${user}:${group}" "${k_photo}") &
						result_string=$(printf "%s (generated)" "${result_string}")
						error_found=1
					else
						#If the avatar is not valid, set it as blank in the database
						mariadb "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\"" &
						rm -rf "${k_photo}" "${k_thumb}" "{k_micro}" &
						result_string=$(printf "%s (blanked)" "${result_string}")
						error_found=1
					fi
				else
					result_string=$(printf "%s No remote" "${result_string}")
					#If no remote avatar is found, we would blank the photo/thumb/micro and let the avatar cache process fix them later, but it's empty already here
					error_found=1
				fi
			fi
			if [[ "${error_found}" -gt 0 ]]; then
				mariadb "${db}" -N -B -q -e "insert ignore into workerqueue (command, parameter, priority, created) \
						values (\"UpdateContact\", \"[${id}]\", 20, concat(curdate(), \" \", curtime()));" &
				result_string=$(printf "%s (added)" "${result_string}")
				nl=1
				n=$((n + 1))
			fi
			lastid="${id}"
		done < <(mariadb "${db}" -B -N -q -e "select \`avatar\`, \`photo\`, \`thumb\`, \`micro\` from \`contact\` where \`id\` = ${id}")
	fi
	w=0
	while [[ "${w}" -eq 0 ]]; do
		if [[ ! -f "${nlock}" ]]; then
			#Write data to file, delete lock
			#n is increased only if error_found = 1
			touch "${nlock}" && read -r lastid n nx nt <"${nfile}" && n=$((n + error_found)) && nx=$((nx + 1)) && nt=$((nt + 1)) && lastid="${id}" &&
				echo "${lastid} ${n} ${nx} ${nt}" >"${nfile}" && rm -rf "${nlock}" && w=1
		fi
	done
	result_string=$(printf "%s T%dms" "${result_string}" $(($(($(date +%s%N) / 1000000)) - t_id)))
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
	#Add a new line only when necessary
	if [[ "${nl}" -eq 1 ]]; then
		final_string=$(printf "%s\n\r\n" "${final_string}")
	fi
	printf "%s\r" "${final_string}"
}

#Go to the Friendica installation
cd "${folder}" || exit
until [[ $((nt + limit)) -gt "${dbcount}" ]]; do
	nx=0
	batch=$(("${batch}" + 1))
	result_string=""
	nl=0
	error_found=0
	echo "${lastid} ${n} ${nx} ${nt}" >"${nfile}"
	while read -r id; do
		loop "${batch}" "${result_string}" "${nl}" "${nx}" "${nt}" "${error_found}" &
		until [[ $(jobs -r -p | wc -l) -lt $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; do
			wait -n
		done
	done < <(mariadb "${db}" -B -N -q -e "select \`id\` from \`contact\` where \`id\` > ${lastid} and (\`photo\` like \"https:\/\/${url}/avatar/%\" or \`photo\` like \"\") order by id limit ${limit}")
	wait
done
rm -rf "${nfile}" "${nlock}"
#mariadb "${db}" -e "alter table contact drop index photo_index"
#printf "\nFixing folders and moving to avatar cache...\n"
