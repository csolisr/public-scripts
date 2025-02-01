#!/bin/bash
db="friendica"
tmpfile="/tmp/sitesdown.txt"
idsdownfile="/tmp/idsdown.txt"
loop_1() {
	sitereq=$(curl -s -L --head -m 20 --request GET "${a}")
	status=$(echo "${sitereq}" | grep -e "200" -e "cloudflare")
	if [[ -z ${status} ]]
	then
		echo "${a}" >> "${tmpfile}"
		echo "Added ${a}"
	fi
}
loop_2() {
	echo "Finding users for ${b}"
	mariadb "${db}" -N -B -q -e "select \`id\`, \`name\` from contact c where c.\`id\` not in (select \`contact-id\` from group_member) and (c.baseurl = \"${b}\" or c.url = \"${b}\")" | sudo tee -a "${idsdownfile}" #&> /dev/null
}

loop_3() {
	echo "Deleting user ${lineb} - ${username}"
	mariadb "${db}" -N -B -q -e "delete from \`post-thread\` where \`author-id\` = ${lineb} or \`causer-id\` = ${lineb} or \`owner-id\` = ${lineb}"
	mariadb "${db}" -N -B -q -e "delete from \`post-thread-user\` where \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}  or \`owner-id\` = ${lineb}"
	mariadb "${db}" -N -B -q -e "delete from \`post-user\` where \`author-id\` = ${lineb}  or \`causer-id\` = ${lineb} or \`owner-id\` = ${lineb}"
	mariadb "${db}" -N -B -q -e "delete from \`post-tag\` where cid = ${lineb}"
	mariadb "${db}" -N -B -q -e "delete from \`post\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}"
	mariadb "${db}" -N -B -q -e "delete from \`photo\` where \`contact-id\` = ${lineb}"
	mariadb "${db}" -N -B -q -e "delete from \`contact\` where \`id\` = ${lineb}"
}

#Check if our dependencies are installed
if [[ -n $(type curl) && -n $(type mariadb) && -n $(type date) ]]
then
	date
	if [[ ! -f "${tmpfile}" ]]
	then
		echo "Listing sites"
		sites=($(mariadb "${db}" -N -B -q -e "select distinct baseurl from contact" | sort -n | uniq ))
		echo "Amount of unique sites: ${#sites[@]}"
		for a in "${sites[@]}"
		do
			loop_1 "${a}" &
			if [[ $(jobs -r -p | wc -l) -ge $(expr $(getconf _NPROCESSORS_ONLN)*2) ]]
			then
				wait -n
			fi
		done
		wait
	fi
	sitesdown=()
	while read -r line; do
		sitesdown+=(${line})
	done < "${tmpfile}"
	echo "Amount of sites down: ${#sitesdown[@]} / ${#sites[@]}"
	if [[ ! -f "${idsdownfile}" ]]
	then
		for b in "${sitesdown[@]}"
		do
			loop_2 "${b}" &
			if [[ $(jobs -r -p | wc -l) -ge $(expr $(getconf _NPROCESSORS_ONLN)/2) ]]
			then
				wait -n
			fi
		done
		wait
		#cat "$idsdownfile" | sort -n | uniq > "$idsdownfile"
	fi
	#idsdown=()
	#echo "$idsdownfile" | sort | uniq > "$idsdownfile"
	while read -r lineb username; do
		#idsdown+=($lineb)
		#The community no longer exists, delete
		loop_3 "${lineb}" &
		if [[ $(jobs -r -p | wc -l) -ge $(expr $(getconf _NPROCESSORS_ONLN)/2) ]]
		then
			wait -n
		fi
		wait
	done < "${idsdownfile}"
	rm "${tmpfile}" 2> /dev/null
	rm "${idsdownfile}" 2> /dev/null
	date
fi
