#!/bin/bash
db="friendica"
tmpfile="/tmp/sitesdown.txt"
idsdownfile="/tmp/idsdown.txt"
url=friendica.example.net
avatarfolder=/var/www/friendica/avatar
avatarfolderescaped=${avatarfolder////\\/}
loop_1() {
	sitereq=$(curl -s -L --head -m 30 --request GET "${a}")
	#Skip check if the message contains a reference to Cloudflare
	status=$(echo "${sitereq}" | grep -e "200" -e "cloudflare")
	if [[ -z ${status} ]]; then
		echo "${a}" >>"${tmpfile}"
		echo "Added ${a}"
	fi
}
loop_2() {
	echo "Finding users for ${b}"
	"${dbengine}" "${db}" -N -B -q -e "select \`id\`, \`nick\`, \`baseurl\` from contact c where c.\`id\` not in (select \`contact-id\` from group_member) and (c.baseurl = \"${b}\" or c.url = \"${b}\")" | sudo tee -a "${idsdownfile}" #&> /dev/null
}

loop_3() {
	baseurltrimmed=$(echo "${baseurl}" | sed -e "s/http[s]*:\/\///g")
	echo "Deleting user ${lineb} - ${nick}@${baseurltrimmed}"
	#Find the pictures in the avatar folders and delete them
	"${dbengine}" "${db}" -N -B -q -e "select \`photo\`, \`thumb\`, \`micro\` from \`contact\` where \`id\` = ${lineb}" | while read -r photo thumb micro; do
		#If stored in avatar folder
		if grep -v -q "${url}/avatar" <(echo "${photo}"); then
			#if [[ -z "${isavatar}" ]]
			phototrimmed=$(echo "${photo}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			echo "${phototrimmed}"
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
	if [[ ! -f "${tmpfile}" ]]; then
		echo "Listing sites"
		#sites=($("${dbengine}" "${db}" -N -B -q -e "select distinct baseurl from contact where baseurl != \"\"" | sort -n | uniq ))
		sites=()
		mapfile -t sites < <("${dbengine}" "${db}" -N -B -q -e "select distinct baseurl from contact where baseurl != \"\"" | sort -b -f -n | uniq -i)
		echo "Amount of unique sites: ${#sites[@]}"
		for a in "${sites[@]}"; do
			loop_1 "${a}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; then
				wait -n
			fi
		done
		wait
	fi
	sitesdown=()
	while read -r line; do
		sitesdown+=("${line}")
	done <"${tmpfile}"
	echo "Amount of sites down: ${#sitesdown[@]} / ${#sites[@]}"
	if [[ ! -f "${idsdownfile}" ]]; then
		for b in "${sitesdown[@]}"; do
			loop_2 "${b}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; then
				wait -n
			fi
		done
		wait
		#cat "$idsdownfile" | sort -n | uniq > "$idsdownfile"
	fi
	#idsdown=()
	#echo "$idsdownfile" | sort | uniq > "$idsdownfile"
	while read -r lineb nick baseurl; do
		#idsdown+=($lineb)
		#The community no longer exists, delete
		loop_3 "${lineb}" "${nick}" "${baseurl}" &
		if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; then
			wait -n
		fi
		wait
	done <"${idsdownfile}"
	rm "${tmpfile}" 2>/dev/null
	rm "${idsdownfile}" 2>/dev/null
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-thread\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-thread-user\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-user\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-tag\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`photo\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` auto_increment = 1"
	date
fi
