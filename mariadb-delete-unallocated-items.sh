#!/bin/bash
dbengine="mariadb"
intense_optimizations=${1:-"0"}
delete_items=${2:-"0"}
db=${3:-"friendica"}
referenced_table_name=${4:-"item-uri"}
enable_maximum_item=${5:-"0"}
folder=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
file="${folder}/find-unallocated.txt"
rm "${file}" && touch "${file}"
limit=1000
count=0
sum=0
query_string_last_table=""
while read -r id; do
	max_count=$("${dbengine}" "${db}" -NBqe "SELECT DISTINCT TABLE_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_SCHEMA = \"${db}\" AND REFERENCED_TABLE_NAME = \"${referenced_table_name}\" AND REFERENCED_COLUMN_NAME = \"${id}\"" | wc -l)
	if [[ ${max_count} -gt 0 ]]; then
		query_string_count_prefix="SELECT COUNT(i.\`${id}\`) FROM \`${referenced_table_name}\` i"
		query_string_find_prefix="SELECT i.\`${id}\` FROM \`${referenced_table_name}\` i"
		query_string_pre_delete_prefix="CREATE TABLE IF NOT EXISTS \`tmp_${referenced_table_name}\` (SELECT \`${id}\` FROM \`${referenced_table_name}\` WHERE \`${id}\` IN ("
		query_string_content=""
		query_string_suffix=" WHERE "
		while read -r table column; do
			if [[ ${table} != "${query_string_last_table}" ]]; then
				count=$((count + 1))
				query_string_last_table="${table}"
				query_string_content="${query_string_content} LEFT JOIN \`${table}\` t${count} ON i.\`${id}\` = t${count}.\`${column}\`"
			else
				query_string_content="${query_string_content} AND i.\`${id}\` = t${count}.\`${column}\`"
			fi
			if [[ ${intense_optimizations} -eq 0 ]]; then
				echo "${id} ${table} ${column}" | tee -a "${file}"
				current=$("${dbengine}" "${db}" -NBqe "SELECT COUNT(x.\`${id}\`) FROM \`${referenced_table_name}\` x INNER JOIN \`${table}\` y ON x.\`${id}\` = y.\`${column}\`" | tee -a "${file}")
				echo "${current}"
				sum=$((sum + current))
			fi
			query_string_suffix="${query_string_suffix} \`t${count}\`.\`${column}\` IS NULL"
			if [[ ${count} -lt ${max_count} ]]; then
				query_string_suffix="${query_string_suffix} AND "
			fi
		done < <("${dbengine}" "${db}" -NBqe "SELECT DISTINCT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_SCHEMA = \"${db}\" AND REFERENCED_TABLE_NAME = \"${referenced_table_name}\" AND REFERENCED_COLUMN_NAME = \"${id}\"")
		query_string_count="${query_string_count_prefix} ${query_string_content} ${query_string_suffix}"
		query_string_find="${query_string_find_prefix} ${query_string_content} ${query_string_suffix}"
		query_string_pre_delete="${query_string_pre_delete_prefix} ${query_string_find_prefix} ${query_string_content} ${query_string_suffix}"
		if [[ ${intense_optimizations} -eq 0 ]]; then
			echo "Sum: ${sum}"
			echo "Total:" | tee -a "${file}"
			"${dbengine}" "${db}" -vvve "${query_string_count}"
		fi
		if [[ ${delete_items} -eq 1 ]]; then
			deletions=1
			total_deletions=0
			deleted_per_second=0
			sleep_time=1
			original_limit="${limit}"
			query_string_pre_delete_suffix=") ORDER BY \`${id}\` ASC);"
			if [[ ${enable_maximum_item} -gt 0 ]]; then
				maximum_item=$("${dbengine}" "${db}" -N -B -q -e 'SELECT `uri-id` FROM `post-thread-user-view` WHERE `uid` = 0 AND `received` < (CURDATE() - INTERVAL 1 DAY) ORDER BY `received` DESC LIMIT 1')
				query_string_pre_delete_suffix=") AND \`${id}\` < ${maximum_item}  ORDER BY \`${id}\` ASC);"
			else
				query_string_pre_delete_suffix=")  ORDER BY \`${id}\` ASC);"
			fi
			echo "${query_string_pre_delete} ${query_string_pre_delete_suffix}"
			"${dbengine}" "${db}" -NBqe "${query_string_pre_delete} ${query_string_pre_delete_suffix}"
			while [[ ${deletions} -gt 0 ]]; do
				starttime=$(date +'%s')
				query_string_delete="DELETE IGNORE FROM \`${referenced_table_name}\`, \`tmp_${referenced_table_name}\` USING \`${referenced_table_name}\` INNER JOIN \`tmp_${referenced_table_name}\` ON \`${referenced_table_name}\`.\`${id}\` = \`tmp_${referenced_table_name}\`.\`${id}\` WHERE \`${referenced_table_name}\`.\`${id}\` IN (SELECT \`${id}\` FROM \`tmp_${referenced_table_name}\`) LIMIT ${limit}; SELECT ROW_COUNT();"
				echo "${query_string_delete}"
				#Since we delete from both tables, we must calculate half the reported amount of items deleted to get the true account
				both_deletions=$("${dbengine}" "${db}" -NBqe "${query_string_delete}")
				if [[ -z ${both_deletions} ]]; then
					both_deletions=0
				fi
				deletions=$((both_deletions / 2))
				total_deletions=$((total_deletions + deletions))
				endtime=$(date +'%s')
				total_time=$((endtime - starttime))
				sleep_time=$((total_time / 2))
				if [[ ${total_time} -gt 0 ]]; then
					deleted_per_second_this_iteration=$((deletions / total_time))
				else
					deleted_per_second_this_iteration="${deletions}"
				fi
				if [[ ${deleted_per_second_this_iteration} -ge ${deleted_per_second} || ${limit} -le ${original_limit} ]]; then
					limit=$((limit * 2))
				else
					limit=$((limit / 2))
				fi
				deleted_per_second="${deleted_per_second_this_iteration}"
				echo "${total_deletions} item(s) deleted so far, ${deletions} deleted in ${total_time}s, ${deleted_per_second_this_iteration}i/s"
				if [[ ${intense_optimizations} -eq 0 ]]; then
					sleep "${sleep_time}"
				fi
			done
			"${dbengine}" "${db}" -NBqe "DROP TABLE IF EXISTS \`tmp_${referenced_table_name}\`;"
		fi
		findings_this_batch="${limit}"
		total_findings=0
		found_per_second=0
		original_limit="${limit}"
		sleep_time="${limit}"
		last_found_id=0
		echo "${query_string_find}"
		while [[ ${findings_this_batch} -gt 0 && ${findings_this_batch} -ge ${limit} ]]; do
			findings_this_batch=0
			starttime=$(date +'%s')
			query_string_find_suffix="AND i.\`${id}\` > \"${last_found_id}\" ORDER BY i.\`${id}\` ASC LIMIT ${limit}"
			while read -r i; do
				findings_this_batch=$((findings_this_batch + 1))
				(
					if [[ ${intense_optimizations} -eq 0 ]]; then
						"${dbengine}" "${db}" -NBqe "SELECT * FROM \`${referenced_table_name}\` WHERE \`${id}\` = \"${i}\"" | tee -a "${file}"
					else
						echo "${i}" | tee -a "${file}"
					fi
				) &
				if [[ ${i} -gt ${last_found_id} ]]; then
					last_found_id="${i}"
				fi
				(
					if [[ ${delete_items} -eq 1 ]]; then
						if [[ ${intense_optimizations} -eq 0 ]]; then
							echo "${i}"
						fi
						query_string_post_delete_prefix="DELETE IGNORE FROM \`${referenced_table_name}\` WHERE \`${id}\` = \"${i}\""
						query_string_post_delete_suffix=";"
						if [[ ${enable_maximum_item} -gt 0 ]]; then
							maximum_item=$("${dbengine}" "${db}" -N -B -q -e 'SELECT `uri-id` FROM `post-thread-user-view` WHERE `uid` = 0 AND `received` < (CURDATE() - INTERVAL 1 DAY) ORDER BY `received` DESC LIMIT 1')
							query_string_post_delete_suffix=" AND \`${id}\` < ${maximum_item};"
						else
							query_string_post_delete_suffix=";"
						fi
						"${dbengine}" "${db}" -NBqe "${query_string_post_delete_prefix}${query_string_post_delete_suffix}"
					fi
				) &
				while [[ $(jobs -r -p | wc -l) -le $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; do
					sleep 0.1s
				done
			done < <("${dbengine}" "${db}" -NBqe "${query_string_find} ${query_string_find_suffix}")
			wait
			total_findings=$((total_findings + findings_this_batch))
			endtime=$(date +'%s')
			total_time=$((endtime - starttime))
			sleep_time=$((total_time / 2))
			if [[ ${total_time} -gt 0 ]]; then
				found_per_second_this_iteration=$((findings_this_batch / total_time))
			else
				found_per_second_this_iteration="${findings_this_batch}"
			fi
			if [[ ${found_per_second_this_iteration} -ge ${found_per_second} || ${limit} -le ${original_limit} ]]; then
				limit=$((limit * 2))
			else
				limit=$((limit / 2))
			fi
			found_per_second="${found_per_second_this_iteration}"
			echo "${total_findings} item(s) found so far, ${findings_this_batch} found in ${total_time}s, ${found_per_second_this_iteration}i/s"
			if [[ ${intense_optimizations} -eq 0 ]]; then
				sleep "${sleep_time}"
			fi
		done
	fi
done < <("${dbengine}" "${db}" -NBqe "SELECT DISTINCT REFERENCED_COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_SCHEMA = \"${db}\" AND REFERENCED_TABLE_NAME = \"${referenced_table_name}\"")
"${dbengine}" "${db}" -vvve "SELECT COUNT(*) FROM \`${referenced_table_name}\`"
