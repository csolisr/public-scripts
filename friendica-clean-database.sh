#!/bin/bash
interval=7
limit=1000
folder=/var/www/friendica
user=friendica
phpversion=php8.2
dbengine=""
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
else
	exit
fi
db=friendica
dboptimizer=""
if [[ -n $(type mariadb-optimize) ]]; then
	dboptimizer="mariadb-optimize"
elif [[ -n $(type mysqloptimize) ]]; then
	dbengine="mysqloptimize"
fi
intense_optimizations=${1:-"0"}

if [[ "${intense_optimizations}" -gt 0 ]]; then
	bash -c "cd ${folder} && sudo -u ${user} ${phpversion} bin/console.php maintenance 1 \"Database maintenance\"" #&> /dev/null
fi

echo "tmp_post_origin_deleted" #&> /dev/null
tmp_post_origin_deleted_q="${limit}"
tmp_post_origin_deleted_current_uri_id=0
until [[ "${tmp_post_origin_deleted_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_origin_deleted_q=0
	while read -r uri_id uid; do
		if [[ -s "${uri_id}" && -s "${uid}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`post-origin\` WHERE \`parent-uri-id\` = ${uri_id} AND \`uid\` = ${uid}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_post_origin_deleted_q=$((tmp_post_origin_deleted_q + 1))
			tmp_post_origin_deleted_current_uri_id="${uri_id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\`, \`uid\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \`deleted\` AND \`edited\` < (CURDATE() - INTERVAL ${interval} DAY) \
		AND ( \`uri-id\` > ${tmp_post_origin_deleted_current_uri_id} ) \
		ORDER BY \`uri-id\`, \`uid\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_origin_deleted_q} item(s) deleted until ${tmp_post_origin_deleted_current_uri_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_post_user_deleted" #&> /dev/null
tmp_post_user_deleted_q="${limit}"
tmp_post_user_deleted_current_uri_id=0
until [[ "${tmp_post_user_deleted_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_user_deleted_q=0
	while read -r uri_id; do
		if [[ -s "${uri_id}" ]]; then
			tmp_post_user_deleted_q=$((tmp_post_user_deleted_q + 1))
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`post-user\` WHERE \`uri-id\` = ${uri_id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_post_user_deleted_q=$((tmp_post_user_deleted_q + 1))
			tmp_post_user_deleted_current_uri_id="${uri_id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \`deleted\` AND \`edited\` < (CURDATE() - INTERVAL ${interval} DAY) \
			AND \`uri-id\` > ${tmp_post_user_deleted_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_user_deleted_q} item(s) deleted until ${tmp_post_user_deleted_current_uri_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_post_uri_id_not_in_post_user" #&> /dev/null
tmp_post_uri_id_not_in_post_user_q="${limit}"
tmp_post_uri_id_not_in_post_user_current_uri_id=0
until [[ "${tmp_post_uri_id_not_in_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_uri_id_not_in_post_user_q=0
	while read -r uri_id; do
		if [[ -s "${uri_id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`post\` WHERE \`uri-id\` = ${uri_id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_post_uri_id_not_in_post_user_q=$((tmp_post_uri_id_not_in_post_user_q + 1))
			tmp_post_uri_id_not_in_post_user_current_uri_id="${uri_id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT p.\`uri-id\` FROM \`post\` p LEFT JOIN \`post-user\` u ON p.\`uri-id\` = u.\`uri-id\` \
		  WHERE u.\`uri-id\` IS NULL AND \
		  p.\`uri-id\` > ${tmp_post_uri_id_not_in_post_user_current_uri_id} \
		ORDER BY p.\`uri-id\` LIMIT ${limit}")
#		"SELECT \`uri-id\` FROM \`post\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`) \
#			AND \`uri-id\` > ${tmp_post_uri_id_not_in_post_user_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_uri_id_not_in_post_user_q} item(s) deleted until ${tmp_post_uri_id_not_in_post_user_current_uri_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_post_content_uri_id_not_in_post_user" #&> /dev/null
tmp_post_content_uri_id_not_in_post_user_q="${limit}"
tmp_post_content_uri_id_not_in_post_user_current_uri_id=0
until [[ "${tmp_post_content_uri_id_not_in_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_content_uri_id_not_in_post_user_q=0
	while read -r uri_id; do
		if [[ -s "${uri_id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`post-content\` WHERE \`uri-id\` = ${uri_id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_post_content_uri_id_not_in_post_user_q=$((tmp_post_content_uri_id_not_in_post_user_q + 1))
			tmp_post_content_uri_id_not_in_post_user_current_uri_id="${uri_id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT c.\`uri-id\` FROM \`post-content\` c LEFT JOIN \`post-user\` u ON c.\`uri-id\` = u.\`uri-id\` \
		  WHERE u.\`uri-id\` IS NULL AND \
		  c.\`uri-id\` > ${tmp_post_content_uri_id_not_in_post_user_current_uri_id} \
		ORDER BY c.\`uri-id\` LIMIT ${limit}")
#		"SELECT \`uri-id\` FROM \`post-content\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`) \
#			AND \`uri-id\` > ${tmp_post_content_uri_id_not_in_post_user_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_content_uri_id_not_in_post_user_q} item(s) deleted until ${tmp_post_content_uri_id_not_in_post_user_current_uri_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_post_thread_uri_id_not_in_post_user" #&> /dev/null
tmp_post_thread_uri_id_not_in_post_user_q="${limit}"
tmp_post_thread_uri_id_not_in_post_user_current_uri_id=0
until [[ "${tmp_post_thread_uri_id_not_in_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_thread_uri_id_not_in_post_user_q=0
	while read -r uri_id; do
		if [[ -s "${uri_id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`post-thread\` WHERE \`uri-id\` = ${uri_id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_post_thread_uri_id_not_in_post_user_q=$((tmp_post_thread_uri_id_not_in_post_user_q + 1))
			tmp_post_thread_uri_id_not_in_post_user_current_uri_id="${uri_id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT t.\`uri-id\` FROM \`post-thread\` t LEFT JOIN \`post-user\` u ON t.\`uri-id\` = u.\`uri-id\` \
		  WHERE u.\`uri-id\` IS NULL AND \
		  t.\`uri-id\` > ${tmp_post_thread_uri_id_not_in_post_user_current_uri_id} \
		ORDER BY t.\`uri-id\` LIMIT ${limit}")
#		"SELECT \`uri-id\` FROM \`post-thread\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`) \
#			AND \`uri-id\` > ${tmp_post_thread_uri_id_not_in_post_user_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_thread_uri_id_not_in_post_user_q} item(s) deleted until ${tmp_post_thread_uri_id_not_in_post_user_current_uri_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_post_user_uri_id_not_in_post" #&> /dev/null
tmp_post_user_uri_id_not_in_post_q="${limit}"
tmp_post_user_uri_id_not_in_post_current_uri_id=0
until [[ "${tmp_post_user_uri_id_not_in_post_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_user_uri_id_not_in_post_q=0
	while read -r uri_id; do
		if [[ -s "${uri_id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`post-user\` WHERE \`uri-id\` = ${uri_id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_post_user_uri_id_not_in_post_q=$((tmp_post_user_uri_id_not_in_post_q + 1))
			tmp_post_user_uri_id_not_in_post_current_uri_id="${uri_id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT u.\`uri-id\` FROM \`post-user\` u LEFT JOIN \`post\` p ON p.\`uri-id\` = u.\`uri-id\` \
		  WHERE p.\`uri-id\` IS NULL AND \
		  u.\`uri-id\` > ${tmp_post_user_uri_id_not_in_post_current_uri_id} \
		ORDER BY u.\`uri-id\` LIMIT ${limit}")
#		"SELECT \`uri-id\` FROM \`post-user\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post\`) \
#			AND \`uri-id\` > ${tmp_post_user_uri_id_not_in_post_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_user_uri_id_not_in_post_q} item(s) deleted until ${tmp_post_user_uri_id_not_in_post_current_uri_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_item_uri_not_in_valid_post_thread" #&> /dev/null
tmp_item_uri_not_in_valid_post_thread_q="${limit}"
tmp_item_uri_not_in_valid_post_thread_current_id=0
until [[ "${tmp_item_uri_not_in_valid_post_thread_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_item_uri_not_in_valid_post_thread_q=0
	while read -r id; do
		if [[ -s "${id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_item_uri_not_in_valid_post_thread_q=$((tmp_item_uri_not_in_valid_post_thread_q + 1))
			tmp_item_uri_not_in_valid_post_thread_current_id="${id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-thread\` WHERE \`received\` < (CURDATE() - INTERVAL ${interval} DAY) \
			AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-thread-user\` WHERE (\`mention\` OR \`starred\` OR \`wall\`) \
			AND \`uri-id\` = \`post-thread\`.\`uri-id\`) \
			AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-category\` WHERE \`uri-id\` = \`post-thread\`.\`uri-id\`) \
			AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-collection\` WHERE \`uri-id\` = \`post-thread\`.\`uri-id\`) \
			AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-media\` WHERE \`uri-id\` = \`post-thread\`.\`uri-id\`) \
			AND NOT \`uri-id\` IN (SELECT \`parent-uri-id\` FROM \`post-user\` INNER JOIN \`contact\` ON \`contact\`.\`id\` = \`contact-id\` \
				AND \`notify_new_posts\` WHERE \`parent-uri-id\` = \`post-thread\`.\`uri-id\`) \
			AND NOT \`uri-id\` IN (SELECT \`parent-uri-id\` FROM \`post-user\` WHERE (\`origin\` OR \`event-id\` != 0 OR \`post-type\` = 128) \
				AND \`parent-uri-id\` = \`post-thread\`.\`uri-id\`) \
			AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-content\` WHERE \`resource-id\` != 0 AND \`uri-id\` = \`post-thread\`.\`uri-id\`) \
			AND \`uri-id\` > ${tmp_item_uri_not_in_valid_post_thread_current_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_item_uri_not_in_valid_post_thread_q} item(s) deleted until ${tmp_item_uri_not_in_valid_post_thread_current_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_item_uri_not_in_valid_post_user" #&> /dev/null
tmp_item_uri_not_in_valid_post_user_q="${limit}"
tmp_item_uri_not_in_valid_post_user_current_id=0
until [[ "${tmp_item_uri_not_in_valid_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_item_uri_not_in_valid_post_user_q=0
	while read -r id; do
		if [[ -s "${id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_item_uri_not_in_valid_post_user_q=$((tmp_item_uri_not_in_valid_post_user_q + 1))
			tmp_item_uri_not_in_valid_post_user_current_id="${id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \`uid\` = 0 \
		AND \`received\` < (CURDATE() - INTERVAL ${interval} DAY) AND NOT \`uri-id\` IN ( SELECT \`parent-uri-id\` FROM \`post-user\` AS \`i\` WHERE \`i\`.\`uid\` != 0 \
		AND \`i\`.\`parent-uri-id\` = \`post-user\`.\`uri-id\` ) AND NOT \`uri-id\` IN ( SELECT \`parent-uri-id\` FROM \`post-user\` AS \`i\` WHERE \`i\`.\`uid\` = 0 \
		AND \`i\`.\`parent-uri-id\` = \`post-user\`.\`uri-id\` AND \`i\`.\`received\` > (CURDATE() - INTERVAL ${interval} DAY) ) \
		AND \`uri-id\` > ${tmp_item_uri_not_in_valid_post_user_current_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_item_uri_not_in_valid_post_user_q} item(s) deleted until ${tmp_item_uri_not_in_valid_post_user_current_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_attach_not_in_post_media" #&> /dev/null
tmp_attach_not_in_post_media_q="${limit}"
tmp_attach_not_in_post_media_current_id=0
until [[ "${tmp_attach_not_in_post_media_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_attach_not_in_post_media_q=0
	while read -r id; do
		if [[ -s "${id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`attach\` WHERE \`id\` = ${id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_attach_not_in_post_media_q=$((tmp_attach_not_in_post_media_q + 1))
			tmp_attach_not_in_post_media_current_id="${id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT a.\`id\` FROM \`attach\` a LEFT JOIN \`post-media\` m ON a.\`id\` = m.\`attach-id\` \
		  WHERE m.\`attach-id\` IS NULL AND \
		  a.\`id\` > ${tmp_attach_not_in_post_media_current_id} \
		ORDER BY a.\`id\` LIMIT ${limit}")
#		"SELECT \`id\` FROM \`attach\` WHERE \`id\` NOT IN (SELECT \`attach-id\` FROM \`post-media\`) \
#		AND \`id\` > ${tmp_attach_not_in_post_media_current_id} ORDER BY \`id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_attach_not_in_post_media_q} item(s) deleted until ${tmp_attach_not_in_post_media_current_id} in ${final_i}s" #&> /dev/null
done
wait

echo "tmp_item_uri_not_valid" #&> /dev/null
tmp_item_uri_not_valid_q="${limit}"
tmp_item_uri_not_valid_current_id=0
tmp_item_uri_not_valid_last_id=$("${dbengine}" "${db}" -N -B -q -e \
	"SELECT \`uri-id\` FROM \`post\` WHERE \`received\` < CURDATE() - INTERVAL 1 DAY ORDER BY \`received\` DESC LIMIT 1")
until [[ "${tmp_item_uri_not_valid_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_item_uri_not_valid_q=0
	while read -r id; do
		if [[ -s "${id}" ]]; then
			"${dbengine}" "${db}" -N -B -q -e \
				"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
				wait -n
			fi
			tmp_item_uri_not_valid_q=$((tmp_item_uri_not_valid_q + 1))
			tmp_item_uri_not_valid_current_id="${id}"
		fi
	done < <("${dbengine}" "${db}" -N -B -q -e \
		"SELECT i.id FROM \`item-uri\` i \
			LEFT JOIN \`post-user\` pu1 ON i.id = pu1.\`uri-id\` \
			LEFT JOIN \`post-user\` pu2 ON i.id = pu2.\`parent-uri-id\` \
			LEFT JOIN \`post-user\` pu3 ON i.id = pu3.\`thr-parent-id\` \
			LEFT JOIN \`post-user\` pu4 ON i.id = pu4.\`external-id\` \
			LEFT JOIN \`post-user\` pu5 ON i.id = pu5.\`replies-id\` \
			LEFT JOIN \`post-thread\` pt1 ON i.id = pt1.\`context-id\` \
			LEFT JOIN \`post-thread\` pt2 ON i.id = pt2.\`conversation-id\` \
			LEFT JOIN \`mail\` m1 ON i.id = m1.\`uri-id\` \
			LEFT JOIN \`event\` e ON i.id = e.\`uri-id\` \
			LEFT JOIN \`user-contact\` uc ON i.id = uc.\`uri-id\` \
			LEFT JOIN \`contact\` c ON i.id = c.\`uri-id\` \
			LEFT JOIN \`apcontact\` ac ON i.id = ac.\`uri-id\` \
			LEFT JOIN \`diaspora-contact\` dc ON i.id = dc.\`uri-id\` \
			LEFT JOIN \`inbox-status\` ins ON i.id = ins.\`uri-id\` \
			LEFT JOIN \`post-delivery\` pd1 ON i.id = pd1.\`uri-id\` \
			LEFT JOIN \`post-delivery\` pd2 ON i.id = pd2.\`inbox-id\` \
			LEFT JOIN \`mail\` m2 ON i.id = m2.\`parent-uri-id\` \
			LEFT JOIN \`mail\` m3 ON i.id = m3.\`thr-parent-id\` \
			WHERE \
			  i.id < ${tmp_item_uri_not_valid_last_id} AND \
			  i.id > ${tmp_item_uri_not_valid_current_id} AND \
			  pu1.\`uri-id\` IS NULL AND \
			  pu2.\`parent-uri-id\` IS NULL AND \
			  pu3.\`thr-parent-id\` IS NULL AND \
			  pu4.\`external-id\` IS NULL AND \
			  pu5.\`replies-id\` IS NULL AND \
			  pt1.\`context-id\` IS NULL AND \
			  pt2.\`conversation-id\` IS NULL AND \
			  m1.\`uri-id\` IS NULL AND \
			  e.\`uri-id\` IS NULL AND \
			  uc.\`uri-id\` IS NULL AND \
			  c.\`uri-id\` IS NULL AND \
			  ac.\`uri-id\` IS NULL AND \
			  dc.\`uri-id\` IS NULL AND \
			  ins.\`uri-id\` IS NULL AND \
			  pd1.\`uri-id\` IS NULL AND \
			  pd2.\`inbox-id\` IS NULL AND \
			  m2.\`parent-uri-id\` IS NULL AND \
			  m3.\`thr-parent-id\` IS NULL \
			ORDER BY \`id\` LIMIT ${limit}")
	#		"SELECT \`id\` FROM \`item-uri\` WHERE ( \`id\` < ${tmp_item_uri_not_valid_last_id} ) \
	#		AND (\`id\` > ${tmp_item_uri_not_valid_current_id} ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`post-user\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`parent-uri-id\` FROM \`post-user\` WHERE \`parent-uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`thr-parent-id\` FROM \`post-user\` WHERE \`thr-parent-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`external-id\` FROM \`post-user\` WHERE \`external-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`replies-id\` FROM \`post-user\` WHERE \`replies-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`context-id\` FROM \`post-thread\` WHERE \`context-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`conversation-id\` FROM \`post-thread\` WHERE \`conversation-id\`= \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`mail\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`event\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`user-contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`apcontact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`diaspora-contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`inbox-status\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`post-delivery\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`post-delivery\` WHERE \`inbox-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`parent-uri-id\` FROM \`mail\` WHERE \`parent-uri-id\` = \`item-uri\`.\`id\` ) \
	#		AND NOT EXISTS ( SELECT \`thr-parent-id\` FROM \`mail\` WHERE \`thr-parent-id\` = \`item-uri\`.\`id\` ) \
	#		ORDER BY \`id\` LIMIT ${limit}")
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_item_uri_not_valid_q} item(s) deleted until ${tmp_item_uri_not_valid_current_id} in ${final_i}s" #&> /dev/null
done
wait

if [[ "${intense_optimizations}" -gt 0 ]]; then
	echo "tmp_item_uri_duplicate" #&> /dev/null
	tmp_item_uri_duplicate_q="${limit}"
	tmp_item_uri_duplicate_current_id=0
	until [[ "${tmp_item_uri_duplicate_q}" -lt "${limit}" ]]; do
		initial_i=$(date +%s)
		tmp_item_uri_duplicate_q=0
		while read -r id; do
			if [[ -s "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}" &
				if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
					wait -n
				fi
				tmp_item_uri_duplicate_q=$((tmp_item_uri_duplicate_q + 1))
				tmp_item_uri_duplicate_current_id="${id}"
			fi
		done < <("${dbengine}" "${db}" -N -B -q -e \
			"SELECT t1.\`id\` FROM \`item-uri\` t1 INNER JOIN \`item-uri\` t2 WHERE t1.\`id\` > ${tmp_item_uri_duplicate_current_id} \
			AND t1.\`id\` < t2.\`id\` AND t1.\`uri\` = t2.\`uri\` LIMIT ${limit}")
		final_i=$(($(date +%s) - initial_i))
		echo "${tmp_item_uri_duplicate_q} item(s) deleted until ${tmp_item_uri_duplicate_current_id} in ${final_i}s" #&> /dev/null
	done
	wait

	echo "tmp_post_media_duplicate"
	tmp_post_media_duplicate_q="${limit}"
	tmp_post_media_duplicate_current_id=0
	until [[ "${tmp_post_media_duplicate_q}" -lt "${limit}" ]]; do
		initial_i=$(date +%s)
		tmp_post_media_duplicate_q=0
		while read -r id; do
			if [[ -s "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-media\` WHERE \`id\` = ${id}" &
				if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
					wait -n
				fi
				tmp_post_media_duplicate_q=$((tmp_post_media_duplicate_q + 1))
				tmp_post_media_duplicate_current_id="${id}"
			fi
		done < <("${dbengine}" "${db}" -N -B -q -e \
			"SELECT u1.\`id\` FROM \`post-media\` u1 INNER JOIN \`post-media\` u2 WHERE u1.\`id\` > ${tmp_post_media_duplicate_current_id} \
			AND u1.\`id\` < u2.\`id\` AND u1.\`uri-id\` = u2.\`uri-id\` AND u1.\`url\`= u2.\`url\` LIMIT ${limit}")
		final_i=$(($(date +%s) - initial_i))
		echo "${tmp_post_media_duplicate_q} item(s) deleted until ${tmp_post_media_duplicate_current_id} in ${final_i}s"
	done
	wait

	echo "tmp_post_user_duplicate"
	tmp_post_user_duplicate_q="${limit}"
	tmp_post_user_duplicate_current_id=0
	until [[ "${tmp_post_user_duplicate_q}" -lt "${limit}" ]]; do
		initial_i=$(date +%s)
		tmp_post_user_duplicate_q=0
		while read -r id; do
			if [[ -s "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-user\` WHERE \`id\` = ${id}" &
				if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 1)) ]]; then
					wait -n
				fi
				tmp_post_user_duplicate_q=$((tmp_post_user_duplicate_q + 1))
				tmp_post_user_duplicate_current_id="${id}"
			fi
		done < <("${dbengine}" "${db}" -N -B -q -e \
			"SELECT v1.\`id\` FROM \`post-user\` v1 INNER JOIN \`post-media\` v2 WHERE v1.\`id\` > ${tmp_post_user_duplicate_current_id} \
				AND v1.\`id\` < v2.\`id\` AND v1.\`uri-id\` = v2.\`uri-id\` LIMIT ${limit}")
		final_i=$(($(date +%s) - initial_i))
		echo "${tmp_post_user_duplicate_q} item(s) deleted until ${tmp_post_user_duplicate_current_id} in ${final_i}s"
	done
	wait

	"${dbengine}" "${db}" -N -B -q -e "ALTER TABLE \`post-user\` AUTO_INCREMENT = 1; ALTER TABLE \`post\` AUTO_INCREMENT = 1; ALTER TABLE \`post-content\` AUTO_INCREMENT = 1; \
		ALTER TABLE \`post-thread\` AUTO_INCREMENT = 1; ALTER TABLE \`item-uri\` AUTO_INCREMENT = 1; ALTER TABLE \`post-media\` AUTO_INCREMENT = 1; ALTER TABLE \`attach\` AUTO_INCREMENT = 1"

	"${dboptimizer}" "${db}" #&> /dev/null
	bash -c "cd ${folder} && sudo -u ${user} ${phpversion} bin/console.php maintenance 0" #&> /dev/null
fi
