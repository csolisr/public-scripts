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
db="friendica"
tmpfile="/tmp/sitesdown.txt"
idsdownfile="/tmp/idsdown.txt"
url=friendica.example.net
avatarfolder=/var/www/friendica/avatar
avatarfolderescaped=${avatarfolder////\\/}
loop_1() {
	site=$(echo "${sites}" | sed -e "s/http[s]*:\/\///g")
	if [[ "${protocol}" == "apub" ]]; then
		#For ActivityPub sites, we test the well-known Webfinger
		#We also need a valid (known) user for the Webfinger test
		user=$("${dbengine}" "${db}" -N -B -q -e "select \`addr\` from contact where baseurl = \"http://${site}\" or url = \"http://${site}\" or baseurl = \"https://${site}\" or url = \"https://${site}\" limit 1")
		site_test="https://${site}/.well-known/webfinger?resource=acct:${user}"
		#If the return message is in "application/jrd+json" format, the site is still up
		#If the message contains a reference to Cloudflare, we don't add it to the list either, just in case
		if ! grep -q -e "application/jrd+json" -e "HTTP.*200" -e "cloudflare" <(curl -s -L -I -m 30 -X HEAD "${site_test}"); then
			echo "${site}" >>"${tmpfile}"
			echo "Added ${site}"
		fi
	fi
	#This is mostly for RSS feeds, we only check whether the site itself is up
	#Skip check if the message contains a reference to Cloudflare
	if [[ "${protocol}" != "bsky" ]]; then
		if ! grep -q -e "HTTP.*200" -e "cloudflare" <(curl -s -L -I -m 30 -X HEAD "https://${site}"); then
			echo "${site}" >>"${tmpfile}"
			echo "Added ${site}"
		fi
	fi
}
loop_2() {
	echo "Finding users for ${b}"
	"${dbengine}" "${db}" -N -B -q -e "select \`id\`, \`nick\`, \`baseurl\` from contact c where c.\`id\` not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`) or \`id\` in (select \`cid\` from \`user-contact\`) or \`id\` in (select \`uid\` from \`user\`)) and (c.baseurl = \"http://${b}\" or c.baseurl = \"https://${b}\")" | sudo tee -a "${idsdownfile}" #&> /dev/null
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
			rm -rfv "${phototrimmed}"
			thumbtrimmed=$(echo "${thumb}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${thumbtrimmed}"
			microtrimmed=$(echo "${micro}" | sed -e "s/https:\/\/${url}\/avatar/${avatarfolderescaped}/g" -e "s/\?ts.*//g")
			rm -rfv "${microtrimmed}"
		fi
	done
	printf "post-thread:"
	"${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread (select \`uri-id\` from \`post-thread\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete h.* from \`post-thread\` h inner join \`tmp_post_thread\` t where h.\`uri-id\` = t.\`uri-id\`; select row_count();"
	printf "post-thread-user:"
	"${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread_user (select \`uri-id\` from \`post-thread-user\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete r.* from \`post-thread-user\` r inner join \`tmp_post_thread_user\` t where r.\`uri-id\` = t.\`uri-id\`; select row_count();"
	printf "post-user":
	"${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_user (select \`id\` from \`post-user\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete u.* from \`post-user\` u inner join \`tmp_post_user\` t where u.\`id\` = t.\`id\`; select row_count();"
	printf "post-tag:"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`post-tag\` where cid = ${lineb}; select row_count();"
	printf "post-content:"
	"${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete p.* from \`post-content\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();"
	printf "post:"
	"${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete p.* from \`post\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();"
	printf "photo:"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`photo\` where \`contact-id\` = ${lineb}; select row_count();"
	printf "contact:"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`contact\` where \`id\` = ${lineb}; select row_count();"
	printf "apcontact:"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`apcontact\` where \`uri-id\` = ${lineb}; select row_count();"
	printf "diaspora-contact:"
	"${dbengine}" "${db}" -N -B -q -e "delete from \`diaspora-contact\` where \`uri-id\` = ${lineb}; select row_count();"
}

#Check if our dependencies are installed
if [[ -n $(type curl) && -n "${dbengine}" && -n $(type "${dbengine}") && -n $(type date) ]]; then
	date
	"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` add index if not exists \`contact_baseurl\` (\`baseurl\`)"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-user\` add index if not exists \`post_user_id\` (\`author-id\`, \`causer-id\`, \`owner-id\`)"
	if [[ ! -f "${tmpfile}" ]]; then
		echo "Listing sites"
		siteslist=$("${dbengine}" "${db}" -N -B -q -e "select distinct baseurl, protocol from contact where baseurl != ''" | sort -b -f -n | sed -e "s/http:/https:/g" | uniq -i)
		siteslistamount=$(echo "${siteslist}" | wc -l)
		echo "Amount of unique sites: ${siteslistamount}"
		while read -r sites protocol; do
			loop_1 "${sites}" "${protocol}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; then
				wait -n
			fi
		done < <(echo "${siteslist}")
		wait
	fi
	sitesdown=()
	while read -r line; do
		sitesdown+=("${line}")
	done <"${tmpfile}"
	t=$(sort -n "${tmpfile}" | uniq)
	echo "${t}" >"${tmpfile}"
	echo "Amount of sites down: ${#sitesdown[@]} / ${siteslistamount}"
	if [[ ! -f "${idsdownfile}" ]]; then
		for b in "${sitesdown[@]}"; do
			loop_2 "${b}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; then
				wait -n
			fi
		done
		wait
		u=$(sort -n "${idsdownfile}" | uniq)
		echo "${u}" >"${idsdownfile}"
	fi
	while read -r lineb nick baseurl; do
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
	"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` drop index \`contact_baseurl\`"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-user\` drop index \`post_user_id\`"
	date
fi
