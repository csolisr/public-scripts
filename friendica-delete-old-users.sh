#!/bin/bash
db="friendica"
idsdownfile="/tmp/idsdown.txt"
url=friendica.example.net
avatarfolder=/var/www/friendica/avatar
avatarfolderescaped=${avatarfolder////\\/}

loop() {
	baseurltrimmed=$(echo "${baseurl}" | sed -e "s/http[s]*:\/\///g")
	echo "Deleting user ${lineb} - ${nick}@${baseurltrimmed}"
	#Find the pictures in the avatar folders and delete them
	"${dbengine}" "${db}" -N -B -q -e "select \`photo\`, \`thumb\`, \`micro\` from \`contact\` where \`id\` = ${lineb}" | while read -r photo thumb micro; do
		#If stored in avatar folder
		if [[ -z $(echo "${photo}" | grep "${url}/avatar") ]]; then
			phototrimmed=$(echo "${photo}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${phototrimmed}"
			thumbtrimmed=$(echo "${thumb}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${thumbtrimmed}"
			microtrimmed=$(echo "${micro}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${microtrimmed}"
		fi
	done
	"${dbengine}" "${db}" -N -B -q -e "delete from \`post-thread\` where \`author-id\` = ${lineb} or \`causer-id\` = ${lineb} or \`owner-id\` = ${lineb}"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`post-thread-user\` where \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}  or \`owner-id\` = ${lineb}"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`post-user\` where \`author-id\` = ${lineb}  or \`causer-id\` = ${lineb} or \`owner-id\` = ${lineb}"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`post-tag\` where cid = ${lineb}"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`post\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`photo\` where \`contact-id\` = ${lineb}"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`contact\` where \`id\` = ${lineb}"
}

#Check for mariadb vs. mysql
dbengine=""
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
fi
#Check if our dependencies are installed
if [[ -n $(type curl) && -n "${dbengine}" && -n $(type "${dbengine}") && -n $(type date) ]]; then
	date
	"${dbengine}" "${db}" -N -B -q -e \
		"select \`id\`, \`nick\`, \`baseurl\` from contact c where \
		c.\`id\` not in (select \`cid\` from \`user-contact\`) and \
		c.\`id\` not in (select \`uid\` from \`user\`) and \
		c.\`id\` not in ( select \`contact-id\` from \`group_member\`) and \
		not pending and \`last-item\` < CURDATE() - INTERVAL 1 YEAR" |
		while read -r lineb nick baseurl; do
			loop "${lineb}" "${nick}" "${baseurl}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; then
				wait -n
			fi
		done
	date
fi
