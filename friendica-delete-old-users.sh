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
url=friendica.example.net
avatarfolder=/var/www/friendica/avatar
avatarfolderescaped=${avatarfolder////\\/}

loop() {
	baseurltrimmed=$(echo "${baseurl}" | sed -e "s/http[s]*:\/\///g")
	printf "%s - %s@%s " "${lineb}" "${nick}" "${baseurltrimmed}"
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
	postthreadcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread (select \`uri-id\` from \`post-thread\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete h.* from \`post-thread\` h inner join \`tmp_post_thread\` t where h.\`uri-id\` = t.\`uri-id\`; select row_count();")
	postthreadusercount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_thread_user (select \`uri-id\` from \`post-thread-user\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete r.* from \`post-thread-user\` r inner join \`tmp_post_thread_user\` t where r.\`uri-id\` = t.\`uri-id\`; select row_count();")
	postusercount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post_user (select \`id\` from \`post-user\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete u.* from \`post-user\` u inner join \`tmp_post_user\` t where u.\`id\` = t.\`id\`; select row_count();")
	posttagcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`post-tag\` where cid = ${lineb}; select row_count();")
	postcontentcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete p.* from \`post-content\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();")
	postcount=$("${dbengine}" "${db}" -N -B -q -e "create temporary table tmp_post (select \`uri-id\` from \`post\` where \`owner-id\` = ${lineb} or \`author-id\` = ${lineb} or \`causer-id\` = ${lineb}); delete p.* from \`post\` p inner join \`tmp_post\` t where p.\`uri-id\` = t.\`uri-id\`; select row_count();")
	photocount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`photo\` where \`contact-id\` = ${lineb}; select row_count();")
	contactcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`contact\` where \`id\` = ${lineb}; select row_count();")
	apcontactcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`apcontact\` where \`uri-id\` = ${lineb}; select row_count();")
	diasporacontactcount=$("${dbengine}" "${db}" -N -B -q -e "delete from \`diaspora-contact\` where \`uri-id\` = ${lineb}; select row_count();")
	printf "post-thread: %s " "${postthreadcount}"
	printf "post-thread-user: %s " "${postthreadusercount}"
	printf "post-user: %s " "${postusercount}"
	printf "post-tag: %s " "${posttagcount}"
	printf "post-content: %s " "${postcontentcount}"
	printf "post: %s " "${postcount}"
	printf "photo: %s " "${photocount}"
	printf "contact: %s " "${contactcount}"
	printf "apcontact: %s " "${apcontactcount}"
	printf "diaspora-contact: %s " "${diasporacontactcount}"
	printf "\r\n"
}

#Check if our dependencies are installed
if [[ -n $(type curl) && -n "${dbengine}" && -n $(type "${dbengine}") && -n $(type date) ]]; then
	date
	"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` add index if not exists \`contact_baseurl\` (baseurl)"
	"${dbengine}" "${db}" -N -B -q -e \
		"select \`id\`, \`nick\`, \`baseurl\` from contact c where \
		c.\`id\` not in (select \`cid\` from \`user-contact\`) and \
		c.\`id\` not in (select \`uid\` from \`user\`) and \
		c.\`id\` not in ( select \`contact-id\` from \`group_member\`) and \
		c.\`contact-type\` != 4 and not pending and \`last-discovery\` < CURDATE() - INTERVAL 1 YEAR and \`last-item\` < CURDATE() - INTERVAL 1 YEAR" |
		while read -r lineb nick baseurl; do
			loop "${lineb}" "${nick}" "${baseurl}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; then
				wait -n
			fi
		done
	wait
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-thread\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-thread-user\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-user\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post-tag\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`post\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`photo\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` auto_increment = 1"
	"${dbengine}" "${db}" -N -B -q -e "alter table \`contact\` drop index \`contact_baseurl\`"
	date
fi
