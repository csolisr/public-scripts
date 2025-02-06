#!/bin/bash
#Set your parameters here
url=friendica.example.net
user=friendica
group=www-data
fileperm=640
folderperm=750
db=friendica
folder=/var/www/friendica
#Internal parameters:
#Amount of times the internal loop has run
batch=0
#Number of invalid avatars found. Set to 1 initially so we can run the loop at least once
n=1
#Number of entries processed this loop
nx=0
#Total number of entries processed
nt=0
#Last known ID to have been successfully processed
lastid=0
#Highest possible ID known
maxid=$(mariadb "${db}" -B -N -q -e "select max(\`id\`) from contact")
#Limit per batch
limit=$(( ( maxid / 1000 ) + 1 ))
if [[ -f /tmp/lastid ]]; then
	rm /tmp/lastid && touch /tmp/lastid
else
	touch /tmp/lastid
fi
#Go to the Friendica installation
cd "${folder}" || exit
#Add to the loop, reset values
n=0
nt=0
maxid=$(mariadb "${db}" -B -N -q -e "select max(\`id\`) from contact")
#dbcount=$(mariadb "${db}" -B -N -q -e "select count(\`id\`) from contact where photo like 'https:\/\/${url}/avatar/%' and (id in (select cid from \`user-contact\`) or id in (select \`uid\` from \`user\`) or \`id\` in (select \`contact-id\` from \`group_member\`))")
dbcount=$(mariadb "${db}" -B -N -q -e "select count(\`id\`) from contact where photo like 'https:\/\/${url}/avatar/%'")
echo "${dbcount}"
until [[ $((nt + limit)) -gt ${dbcount} ]]; do
	nx=0
	maxid=$(mariadb "${db}" -B -N -q -e "select max(\`id\`) from contact")
	batch=$(("${batch}" + 1))
	#Read lastid outside of the loop with a temporary file
	if [[ -f /tmp/lastid && -s /tmp/lastid ]]; then
		count=0
		while read -r n_i nt_i lastid_i; do
			if [[ -s "${n_i}" ]]; then
				n="${n_i}"
			fi
			if [[ -s "${nt_i}" ]]; then
				nt="${nt_i}"
			fi
			if [[ -s "${lastid_i}" ]]; then
				lastid="${lastid_i}"
			fi
		done < /tmp/lastid
	fi
	#dboutput=$(mariadb "${db}" -B -N -q -e "select \`id\`, \`photo\`, \`thumb\`, \`micro\` from \`contact\` where \`id\` > ${lastid} and \`photo\` like \"https:\/\/${url}/avatar/%\" and (\`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`) or \`id\` in (select \`contact-id\` from \`group_member\`)) order by id limit ${limit}")
	dboutput=$(mariadb "${db}" -B -N -q -e "select \`id\`, \`photo\`, \`thumb\`, \`micro\` from \`contact\` where \`id\` > ${lastid} and \`photo\` like \"https:\/\/${url}/avatar/%\" order by id limit ${limit}")
	while read -r id photo thumb micro; do
		if [[ -n "${id}" && -n "${photo}" && -n "${thumb}" && -n "${micro}" ]]; then
			nx=$(("${nx}" + 1))
			nt=$(("${nt}" + 1))
			error_found=0
			folderescaped=${folder////\\/}
			#Substitute the URL path with the folder path so we can search for it in the local file system
			#Photo is nominally 320px, actually 300px
			k_photo=$(echo "${photo}" | sed -e "s/https:\/\/${url}/${folderescaped}/g" -e "s/\?ts=.*//g")
			#Thumb is 80px
			k_thumb=$(echo "${thumb}" | sed -e "s/https:\/\/${url}/${folderescaped}/g" -e "s/\?ts=.*//g")
			#Micro is 48px
			k_micro=$(echo "${micro}" | sed -e "s/https:\/\/${url}/${folderescaped}/g" -e "s/\?ts=.*//g")
			#If fetching any of the images causes an error
			if curl -s "${photo}" | file - | grep -q -e "text" -e "empty" -e "symbolic link" -e "directory" ||
				curl -s "${thumb}" | file - | grep -q -e "text" -e "empty" -e "symbolic link" -e "directory" ||
				curl -s "${micro}" | file - | grep -q -e "text" -e "empty" -e "symbolic link" -e "directory"; then
				#Request the user data to be regenerated in the system through the database
				mariadb "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
				if [[ $(mariadb "${db}" -N -B -q -e "select count(*) from workerqueue where command = \"UpdateContact\" and parameter = \"[${id}]\"" -gt 0) ]]; then
					mariadb "${db}" -N -B -q -e "insert ignore into workerqueue (command, parameter, priority, created) values (\"UpdateContact\", \"[${id}]\", 20, CURTIME());"
				fi
				echo "${id} ${photo}"
				error_found=1
			fi
			#If any of the images is not found in the filesystem
			if [[ ! -e "${k_photo}" || ! -e "${k_thumb}" || ! -e "${k_micro}" ]]; then
				#If the avatar uses the standard fallback picture or is local, we cannot use it as a base
				avatar=$(mariadb "${db}" -B -N -q -e "select avatar from contact where id = \"${id}\" and not avatar like \"%${url}\" and not avatar like \"%images/person%\"")
				#If we have a remote avatar as a fallback, download it
				if [[ $! -eq 0 && -n ${avatar} ]]; then
					echo "${id} ${avatar}"
					sudo -u "${user}" curl "${avatar}" -s -o "${k_photo}"
					#If the file is a valid picture (not empty, not text)
					if file "${k_photo}" | grep -q -v -e "text" -e "empty" -e "symbolic link" -e "directory"; then
						#Also fetch for thumb/micro and resize
						#As the photo is the largest version we have, we will use it as the base, and leave it last to convert
						convert "${k_photo}" -resize 80x80 -depth 16 "${k_thumb}" && chmod "${fileperm}" "${k_thumb}" && chown "${user}:${group}" "${k_thumb}"
						convert "${k_photo}" -resize 48x48 -depth 16 "${k_micro}" && chmod "${fileperm}" "${k_micro}" && chown "${user}:${group}" "${k_micro}"
						convert "${k_photo}" -resize 300x300 -depth 16 "${k_photo}" && chmod "${fileperm}" "${k_photo}" && chown "${user}:${group}" "${k_photo}"
					else
						#If the avatar is not valid, set it as blank in the database
						mariadb "${db}" -N -B -q -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
						rm -rf "${k_photo}"
					fi
					#Request the user data to be regenerated in the system through the database
					if [[ $(mariadb "${db}" -N -B -q -e "select count(*) from workerqueue where command = \"UpdateContact\" and parameter = \"[${id}]\"" -gt 0) ]]; then
						mariadb "${db}" -N -B -q -e "insert ignore into workerqueue (command, parameter, priority, created) values (\"UpdateContact\", \"[${id}]\", 20, CURTIME());"
					fi
				else
					echo "${id}"
					#If no remote avatar is found, then we blank the photo/thumb/micro and let the avatar cache process fix them later
					mariadb "${db}" -e "update contact set photo = \"\", thumb = \"\", micro = \"\" where id = \"${id}\""
					#Request the user data to be regenerated in the system through the database
					if [[ $(mariadb "${db}" -N -B -q -e "select count(*) from workerqueue where command = \"UpdateContact\" and parameter = \"[${id}]\"" -gt 0) ]]; then
						mariadb "${db}" -N -B -q -e "insert ignore into workerqueue (command, parameter, priority, created) values (\"UpdateContact\", \"[${id}]\", 20, CURTIME());"
					fi
				fi
				error_found=1
				k_photo_delta=$(echo "${photo}" | sed -e "s/.*?ts=//g")
			else
				k_photo_original_time=$(echo "${photo}" | sed -e "s/.*?ts=//g")
				k_photo_found_time=$(stat -c%W "${k_photo}")
				k_photo_delta=$((k_photo_found_time - k_photo_original_time))
			fi
			if [[ "${error_found}" -gt 0 ]]; then
				n=$((n + 1))
			fi
			lastid="${id}"
			touch /tmp/lastid
			echo "${n} ${nt} ${lastid}" > /tmp/lastid
		fi
		printf "\rB. %5d Fd. %8d E. %8d Ct. %4d/%4d To. %8d/%8d Dt. %6d " "${batch}" "${n}" "${nt}" "${nx}" "${limit}" "${lastid}" "${maxid}" "${k_photo_delta}"
	done < <(echo "${dboutput}")
done
printf "\nFixing folders and moving to avatar cache...\n"
#sudo -u "${user}" bin/console movetoavatarcache #&> /dev/null
"${folder}"/bin/console movetoavatarcache #&> /dev/null
find ./avatar -depth -not -user "${user}" -or -not -group "${group}" -exec chown -v "${user}:${group}" {} \;
find ./avatar -depth -type f -and -not -type d -and -not -perm "${fileperm}" -exec chmod -v "${fileperm}" {} \;
find ./avatar -depth -type d -and -not -perm "${folderperm}" -exec chmod -v "${folderperm}" {} \;
chown -R "${user}:${group}" ./avatar
rm /tmp/lastid
