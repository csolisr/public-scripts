#!/bin/bash
interval=7
limit=1000
tmpfile=/tmp/fcb
dbengine=mariadb
db=friendica

touch "${tmpfile}"
echo "tmp_post_origin_deleted"
tmp_post_origin_deleted_q="${limit}"
tmp_post_origin_deleted_current_uri_id=0
until [[ "${tmp_post_origin_deleted_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_origin_deleted=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\`, \`uid\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \`deleted\` AND \`edited\` < (CURDATE() - INTERVAL ${interval} DAY) \
			AND ( \`uri-id\` > ${tmp_post_origin_deleted_current_uri_id} ) \
			ORDER BY \`uri-id\`, \`uid\` LIMIT ${limit}")
	tmp_post_origin_deleted_q=$(echo "${tmp_post_origin_deleted}" | grep -c '.')
	#echo "${tmp_post_origin_deleted_q}"
	if [[ "${tmp_post_origin_deleted_q}" -gt 0 ]]; then
		echo "${tmp_post_origin_deleted}" | while read -r uri_id uid; do
			if [[ -n "${uri_id}" && -n "${uid}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-origin\` WHERE \`parent-uri-id\` = ${uri_id} AND \`uid\` = ${uid}"
				#echo "${uri_id} ${uid}"
				echo "${uri_id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_post_origin_deleted_current_uri_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_origin_deleted_q} item(s) deleted until ${tmp_post_origin_deleted_current_uri_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_post_user_deleted"
tmp_post_user_deleted_q="${limit}"
tmp_post_user_deleted_current_uri_id=0
until [[ "${tmp_post_user_deleted_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_user_deleted=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \`deleted\` AND \`edited\` < (CURDATE() - INTERVAL ${interval} DAY) \
			AND \`uri-id\` > ${tmp_post_user_deleted_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	tmp_post_user_deleted_q=$(echo "${tmp_post_user_deleted}" | grep -c '.')
	#echo "${tmp_post_user_deleted_q}"
	if [[ "${tmp_post_user_deleted_q}" -gt 0 ]]; then
		echo "${tmp_post_user_deleted}" | while read -r uri_id; do
			if [[ -n "${uri_id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-user\` WHERE \`uri-id\` = ${uri_id}"
				#echo "${uri_id}"
				echo "${uri_id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_post_user_deleted_current_uri_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_user_deleted_q} item(s) deleted until ${tmp_post_user_deleted_current_uri_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_post_uri_id_not_in_post_user"
tmp_post_uri_id_not_in_post_user_q="${limit}"
tmp_post_uri_id_not_in_post_user_current_uri_id=0
until [[ "${tmp_post_uri_id_not_in_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_uri_id_not_in_post_user=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`) \
			AND \`uri-id\` > ${tmp_post_uri_id_not_in_post_user_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	tmp_post_uri_id_not_in_post_user_q=$(echo "${tmp_post_uri_id_not_in_post_user}" | grep -c '.')
	#echo "${tmp_post_uri_id_not_in_post_user_q}"
	if [[ "${tmp_post_uri_id_not_in_post_user_q}" -gt 0 ]]; then
		echo "${tmp_post_uri_id_not_in_post_user}" | while read -r uri_id; do
			if [[ -n "${uri_id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post\` WHERE \`uri-id\` = ${uri_id}"
				#echo "${uri_id}"
				echo "${uri_id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_post_uri_id_not_in_post_user_current_uri_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_uri_id_not_in_post_user_q} item(s) deleted until ${tmp_post_uri_id_not_in_post_user_current_uri_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_post_content_uri_id_not_in_post_user"
tmp_post_content_uri_id_not_in_post_user_q="${limit}"
tmp_post_content_uri_id_not_in_post_user_current_uri_id=0
until [[ "${tmp_post_content_uri_id_not_in_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_content_uri_id_not_in_post_user=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-content\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`) \
			AND \`uri-id\` > ${tmp_post_content_uri_id_not_in_post_user_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	tmp_post_content_uri_id_not_in_post_user_q=$(echo "${tmp_post_content_uri_id_not_in_post_user}" | grep -c '.')
	#echo "${tmp_post_content_uri_id_not_in_post_user_q}"
	if [[ "${tmp_post_content_uri_id_not_in_post_user_q}" -gt 0 ]]; then
		echo "${tmp_post_content_uri_id_not_in_post_user}" | while read -r uri_id; do
			if [[ -n "${uri_id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-content\` WHERE \`uri-id\` = ${uri_id}"
				#echo "${uri_id}"
				echo "${uri_id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_post_content_uri_id_not_in_post_user_current_uri_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_content_uri_id_not_in_post_user_q} item(s) deleted until ${tmp_post_content_uri_id_not_in_post_user_current_uri_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_post_thread_uri_id_not_in_post_user"
tmp_post_thread_uri_id_not_in_post_user_q="${limit}"
tmp_post_thread_uri_id_not_in_post_user_current_uri_id=0
until [[ "${tmp_post_thread_uri_id_not_in_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_thread_uri_id_not_in_post_user=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-thread\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`) \
			AND \`uri-id\` > ${tmp_post_thread_uri_id_not_in_post_user_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	tmp_post_thread_uri_id_not_in_post_user_q=$(echo "${tmp_post_thread_uri_id_not_in_post_user}" | grep -c '.')
	#echo "${tmp_post_thread_uri_id_not_in_post_user_q}"
	if [[ "${tmp_post_thread_uri_id_not_in_post_user_q}" -gt 0 ]]; then
		echo "${tmp_post_thread_uri_id_not_in_post_user}" | while read -r uri_id; do
			if [[ -n "${uri_id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-thread\` WHERE \`uri-id\` = ${uri_id}"
				#echo "${uri_id}"
				echo "${uri_id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_post_thread_uri_id_not_in_post_user_current_uri_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_thread_uri_id_not_in_post_user_q} item(s) deleted until ${tmp_post_thread_uri_id_not_in_post_user_current_uri_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_post_user_uri_id_not_in_post"
tmp_post_user_uri_id_not_in_post_q="${limit}"
tmp_post_user_uri_id_not_in_post_current_uri_id=0
until [[ "${tmp_post_user_uri_id_not_in_post_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_post_user_uri_id_not_in_post=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-user\` WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post\`) \
			AND \`uri-id\` > ${tmp_post_user_uri_id_not_in_post_current_uri_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	tmp_post_user_uri_id_not_in_post_q=$(echo "${tmp_post_user_uri_id_not_in_post}" | grep -c '.')
	#echo "${tmp_post_user_uri_id_not_in_post_q}"
	if [[ "${tmp_post_user_uri_id_not_in_post_q}" -gt 0 ]]; then
		echo "${tmp_post_user_uri_id_not_in_post}" | while read -r uri_id; do
			if [[ -n "${uri_id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-user\` WHERE \`uri-id\` = ${uri_id}"
				#echo "${uri_id}"
				echo "${uri_id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_post_user_uri_id_not_in_post_current_uri_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_user_uri_id_not_in_post_q} item(s) deleted until ${tmp_post_user_uri_id_not_in_post_current_uri_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_item_uri_not_in_valid_post_thread"
tmp_item_uri_not_in_valid_post_thread_q="${limit}"
tmp_item_uri_not_in_valid_post_thread_current_id=0
until [[ "${tmp_item_uri_not_in_valid_post_thread_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_item_uri_not_in_valid_post_thread=$("${dbengine}" "${db}" -N -B -q -e \
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
	tmp_item_uri_not_in_valid_post_thread_q=$(echo "${tmp_item_uri_not_in_valid_post_thread}" | grep -c '.')
	#echo "${tmp_item_uri_not_in_valid_post_thread_q}"
	if [[ "${tmp_item_uri_not_in_valid_post_thread_q}" -gt 0 ]]; then
		echo "${tmp_item_uri_not_in_valid_post_thread}" | while read -r id; do
			if [[ -n "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}"
				#echo "${id}"
				echo "${id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_item_uri_not_in_valid_post_thread_current_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_item_uri_not_in_valid_post_thread_q} item(s) deleted until ${tmp_item_uri_not_in_valid_post_thread_current_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_item_uri_not_in_valid_post_user"
tmp_item_uri_not_in_valid_post_user_q="${limit}"
tmp_item_uri_not_in_valid_post_user_current_id=0
until [[ "${tmp_item_uri_not_in_valid_post_user_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_item_uri_not_in_valid_post_user=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`uri-id\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \`uid\` = 0 \
		AND \`received\` < (CURDATE() - INTERVAL ${interval} DAY) AND NOT \`uri-id\` IN ( SELECT \`parent-uri-id\` FROM \`post-user\` AS \`i\` WHERE \`i\`.\`uid\` != 0 \
		AND \`i\`.\`parent-uri-id\` = \`post-user\`.\`uri-id\` ) AND NOT \`uri-id\` IN ( SELECT \`parent-uri-id\` FROM \`post-user\` AS \`i\` WHERE \`i\`.\`uid\` = 0 \
		AND \`i\`.\`parent-uri-id\` = \`post-user\`.\`uri-id\` AND \`i\`.\`received\` > (CURDATE() - INTERVAL ${interval} DAY) ) \
		AND \`uri-id\` > ${tmp_item_uri_not_in_valid_post_user_current_id} ORDER BY \`uri-id\` LIMIT ${limit}")
	tmp_item_uri_not_in_valid_post_user_q=$(echo "${tmp_item_uri_not_in_valid_post_user}" | grep -c '.')
	#echo "${tmp_item_uri_not_in_valid_post_user_q}"
	if [[ "${tmp_item_uri_not_in_valid_post_user_q}" -gt 0 ]]; then
		echo "${tmp_item_uri_not_in_valid_post_user}" | while read -r id; do
			if [[ -n "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}"
				#echo "${id}"
				echo "${id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_item_uri_not_in_valid_post_user_current_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_item_uri_not_in_valid_post_user_q} item(s) deleted until ${tmp_item_uri_not_in_valid_post_user_current_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_attach_not_in_post_media"
tmp_attach_not_in_post_media_q="${limit}"
tmp_attach_not_in_post_media_current_id=0
until [[ "${tmp_attach_not_in_post_media_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_attach_not_in_post_media=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`id\` FROM \`attach\` WHERE \`id\` NOT IN (SELECT \`attach-id\` FROM \`post-media\`) \
		AND \`id\` > ${tmp_attach_not_in_post_media_current_id} ORDER BY \`id\` LIMIT ${limit}")
	tmp_attach_not_in_post_media_q=$(echo "${tmp_attach_not_in_post_media}" | grep -c '.')
	#echo "${tmp_attach_not_in_post_media_q}"
	if [[ "${tmp_attach_not_in_post_media_q}" -gt 0 ]]; then
		echo "${tmp_attach_not_in_post_media}" | while read -r id; do
			if [[ -n "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`attach\` WHERE \`id\` = ${id}"
				#echo "${id}"
				echo "${id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_attach_not_in_post_media_current_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_attach_not_in_post_media_q} item(s) deleted until ${tmp_attach_not_in_post_media_current_id}"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_item_uri_not_valid"
tmp_item_uri_not_valid_q="${limit}"
tmp_item_uri_not_valid_current_id=0
tmp_item_uri_not_valid_last_id=$("${dbengine}" "${db}" -N -B -q -e \
	"SELECT \`uri-id\` FROM \`post\` WHERE \`received\` < CURDATE() - INTERVAL 1 DAY ORDER BY \`received\` DESC LIMIT 1")
until [[ "${tmp_item_uri_not_valid_q}" -lt "${limit}" ]]; do
	initial_i=$(date +%s)
	tmp_item_uri_not_valid=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT \`id\` FROM \`item-uri\` WHERE ( \`id\` < ${tmp_item_uri_not_valid_last_id} ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`post-user\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`parent-uri-id\` FROM \`post-user\` WHERE \`parent-uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`thr-parent-id\` FROM \`post-user\` WHERE \`thr-parent-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`external-id\` FROM \`post-user\` WHERE \`external-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`replies-id\` FROM \`post-user\` WHERE \`replies-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`context-id\` FROM \`post-thread\` WHERE \`context-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`conversation-id\` FROM \`post-thread\` WHERE \`conversation-id\`= \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`mail\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`event\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`user-contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`apcontact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`diaspora-contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`inbox-status\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`post-delivery\` WHERE \`uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`uri-id\` FROM \`post-delivery\` WHERE \`inbox-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`parent-uri-id\` FROM \`mail\` WHERE \`parent-uri-id\` = \`item-uri\`.\`id\` ) \
		AND NOT EXISTS ( SELECT \`thr-parent-id\` FROM \`mail\` WHERE \`thr-parent-id\` = \`item-uri\`.\`id\` ) \
		AND (\`id\` > ${tmp_item_uri_not_valid_current_id} ) ORDER BY \`id\` LIMIT ${limit}")
	tmp_item_uri_not_valid_q=$(echo "${tmp_item_uri_not_valid}" | grep -c '.')
	#echo "${tmp_item_uri_not_valid_q}"
	if [[ "${tmp_item_uri_not_valid_q}" -gt 0 ]]; then
		echo "${tmp_item_uri_not_valid}" | while read -r id; do
			if [[ -n "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}"
				echo "${id}" >"${tmpfile}"
			fi
		done
	fi
	if [[ -f "${tmpfile}" && -s "${tmpfile}" ]]; then
		tmp_item_uri_not_valid_current_id=$(cat "${tmpfile}")
	fi
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_item_uri_not_valid_q} item(s) deleted until ${tmp_item_uri_not_valid_current_id} in ${final_i}s"
done
rm "${tmpfile}" && touch "${tmpfile}"

echo "tmp_item_uri_duplicate"
tmp_item_uri_duplicate_q="${limit}"
until [[ "${tmp_item_uri_duplicate_q}" -lt "${limit}" ]]; do
	tmp_item_uri_duplicate=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT t1.\`id\` FROM \`item-uri\` t1 INNER JOIN \`item-uri\` t2 WHERE t1.\`id\` < t2.\`id\` AND t1.\`uri\` = t2.\`uri\` LIMIT ${limit}")
	tmp_item_uri_duplicate_q=$(echo "${tmp_item_uri_duplicate}" | grep -c '.')
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_item_uri_duplicate_q}"
	if [[ "${tmp_item_uri_duplicate_q}" -gt 0 ]]; then
		echo "${tmp_item_uri_duplicate}" | while read -r id; do
			if [[ -n "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`item-uri\` WHERE \`id\` = ${id}"
				echo "${id}"
			fi
		done
	fi
done

echo "tmp_post_media_duplicate"
tmp_post_media_duplicate_q="${limit}"
until [[ "${tmp_post_media_duplicate_q}" -lt "${limit}" ]]; do
	tmp_post_media_duplicate=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT u1.\`id\` FROM \`post-media\` u1 INNER JOIN \`post-media\` u2 WHERE u1.\`id\` < u2.\`id\` AND u1.\`uri-id\` = u2.\`uri-id\` AND u1.\`url\`= u2.\`url\` LIMIT ${limit}")
	tmp_post_media_duplicate_q=$(echo "${tmp_post_media_duplicate}" | grep -c '.')
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_media_duplicate_q}"
	if [[ "${tmp_post_media_duplicate_q}" -gt 0 ]]; then
		echo "${tmp_post_media_duplicate}" | while read -r id; do
			if [[ -n "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-media\` WHERE \`id\` = ${id}"
				echo "${id}"
			fi
		done
	fi
done

echo "tmp_post_user_duplicate"
tmp_post_user_duplicate_q="${limit}"
until [[ "${tmp_post_user_duplicate_q}" -lt "${limit}" ]]; do
	tmp_post_user_duplicate=$("${dbengine}" "${db}" -N -B -q -e \
		"SELECT v1.\`id\` FROM \`post-user\` v1 INNER JOIN \`post-media\` v2 WHERE v1.\`id\` = v2.\`id\` AND v1.\`uri-id\` = v2.\`uri-id\` LIMIT ${limit}")
	tmp_post_user_duplicate_q=$(echo "${tmp_post_user_duplicate}" | grep -c '.')
	final_i=$(($(date +%s) - initial_i))
	echo "${tmp_post_user_duplicate_q}"
	if [[ "${tmp_post_user_duplicate_q}" -gt 0 ]]; then
		echo "${tmp_post_user_duplicate}" | while read -r id; do
			if [[ -n "${id}" ]]; then
				"${dbengine}" "${db}" -N -B -q -e \
					"DELETE FROM \`post-user\` WHERE \`id\` = ${id}"
				echo "${id}"
			fi
		done
	fi
done
