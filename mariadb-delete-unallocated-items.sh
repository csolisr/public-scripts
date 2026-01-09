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
while read -r id; do
	max_count=$("${dbengine}" "${db}" -NBqe "SELECT DISTINCT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_SCHEMA = \"${db}\" AND REFERENCED_TABLE_NAME = \"${referenced_table_name}\" AND REFERENCED_COLUMN_NAME = \"${id}\"" | wc -l)
	if [[ "${max_count}" -gt 0 ]]; then
		query_string_count_prefix="SELECT COUNT(i.\`${id}\`) FROM \`${referenced_table_name}\` i"
		query_string_find_prefix="SELECT i.\`${id}\` FROM \`${referenced_table_name}\` i"
		query_string_delete_prefix="DELETE IGNORE FROM \`${referenced_table_name}\` WHERE \`${id}\` IN ("
		query_string_content=""
		query_string_suffix=" WHERE "
		while read -r table column; do
			count=$((count + 1))
			if [[ "${intense_optimizations}" -eq 0 ]]; then
				echo "${id} ${table} ${column}" | tee -a "${file}"
				current=$("${dbengine}" "${db}" -NBqe "SELECT COUNT(x.\`${id}\`) FROM \`${referenced_table_name}\` x INNER JOIN \`${table}\` y ON x.\`${id}\` = y.\`${column}\`" | tee -a "${file}")
				echo "${current}"
				sum=$((sum + current))
			fi
			query_string_content="${query_string_content} LEFT JOIN \`${table}\` t${count} ON i.\`${id}\` = t${count}.\`${column}\`"
			query_string_suffix="${query_string_suffix} \`t${count}\`.\`${column}\` IS NULL"
			if [[ "${count}" -lt "${max_count}" ]]; then
				query_string_suffix="${query_string_suffix} AND "
			fi
		done < <("${dbengine}" "${db}" -NBqe "SELECT DISTINCT TABLE_NAME, COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_SCHEMA = \"${db}\" AND REFERENCED_TABLE_NAME = \"${referenced_table_name}\" AND REFERENCED_COLUMN_NAME = \"${id}\"")
		query_string_count="${query_string_count_prefix} ${query_string_content} ${query_string_suffix}"
		query_string_find="${query_string_find_prefix} ${query_string_content} ${query_string_suffix}"
		query_string_delete="${query_string_delete_prefix} ${query_string_find_prefix} ${query_string_content} ${query_string_suffix}"
		if [[ "${intense_optimizations}" -eq 0 ]]; then
			echo "Sum: ${sum}"
			echo "Total:" | tee -a "${file}"
			"${dbengine}" "${db}" -vvve "${query_string_count}"
		fi
		if [[ "${delete_items}" -eq 1 ]]; then
			echo "${query_string_delete}"
			deletions=1
			total_deletions=0
			deleted_per_second=0
			sleep_time=1
			original_limit="${limit}"
			while [[ "${deletions}" -gt 0 ]]; do
				starttime=$(date +'%s')
				query_string_delete_suffix=") ORDER BY \`${id}\` ASC LIMIT ${limit}; SELECT ROW_COUNT();"
				if [[ "${enable_maximum_item}" -gt 0 ]]; then
					maximum_item=$("${dbengine}" "${db}" -N -B -q -e "SELECT \`uri-id\` FROM \`post-thread-user-view\` WHERE \`uid\` = 0 AND \`received\` < (CURDATE() - INTERVAL 1 DAY) ORDER BY \`received\` DESC LIMIT 1")
					query_string_delete_suffix=") AND \`${id}\` < ${maximum_item} ORDER BY \`${id}\` ASC LIMIT ${limit}; SELECT ROW_COUNT();"
				else
					query_string_delete_suffix=") ORDER BY \`${id}\` ASC LIMIT ${limit}; SELECT ROW_COUNT();"
				fi
				deletions=$("${dbengine}" "${db}" -NBqe "${query_string_delete} ${query_string_delete_suffix}")
				total_deletions=$((total_deletions + deletions))
				endtime=$(date +'%s')
				total_time=$((endtime - starttime))
				sleep_time=$((total_time / 2))
				if [[ "${total_time}" -gt 0 ]]; then
					deleted_per_second_this_iteration=$((deletions / total_time))
				else
					deleted_per_second_this_iteration="${deletions}"
				fi
				if [[ "${deleted_per_second_this_iteration}" -ge "${deleted_per_second}" || "${limit}" -le "${original_limit}" ]]; then
					limit=$((limit * 2))
				else
					limit=$((limit / 2))
				fi
				deleted_per_second="${deleted_per_second_this_iteration}"
				echo "${total_deletions} item(s) deleted so far, ${deletions} deleted in ${total_time}s, ${deleted_per_second_this_iteration}i/s"
				if [[ "${intense_optimizations}" -eq 0 ]]; then
					sleep "${sleep_time}"
				fi
			done
		fi
		findings_this_batch="${limit}"
		total_findings=0
		found_per_second=0
		original_limit="${limit}"
		sleep_time="${limit}"
		last_found_id=0
		echo "${query_string_find}"
		while [[ "${findings_this_batch}" -gt 0 && "${findings_this_batch}" -ge "${limit}" ]]; do
			findings_this_batch=0
			starttime=$(date +'%s')
			query_string_find_suffix="AND i.\`${id}\` > \"${last_found_id}\" ORDER BY i.\`${id}\` ASC LIMIT ${limit}"
			while read -r i; do
				findings_this_batch=$((findings_this_batch + 1))
				(
					if [[ "${intense_optimizations}" -eq 0 ]]; then
						"${dbengine}" "${db}" -NBqe "SELECT * FROM \`${referenced_table_name}\` WHERE \`${id}\` = \"${i}\"" | tee -a "${file}"
					else
						echo "${i}" | tee -a "${file}"
					fi
				) &
				if [[ "${i}" -gt "${last_found_id}" ]]; then
					last_found_id="${i}"
				fi
				(
					if [[ "${delete_items}" -eq 1 ]]; then
						if [[ "${intense_optimizations}" -eq 0 ]]; then
							echo "${i}"
						fi
						"${dbengine}" "${db}" -NBqe "DELETE IGNORE FROM \`${referenced_table_name}\` WHERE \`${id}\` = \"${i}\""
					fi
				) &
				if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; then
					wait -n
				fi
			done < <("${dbengine}" "${db}" -NBqe "${query_string_find} ${query_string_find_suffix}")
			wait
			total_findings=$((total_findings + findings_this_batch))
			endtime=$(date +'%s')
			total_time=$((endtime - starttime))
			sleep_time=$((total_time / 2))
			if [[ "${total_time}" -gt 0 ]]; then
				found_per_second_this_iteration=$((findings_this_batch / total_time))
			else
				found_per_second_this_iteration="${findings_this_batch}"
			fi
			if [[ "${found_per_second_this_iteration}" -ge "${found_per_second}" || "${limit}" -le "${original_limit}" ]]; then
				limit=$((limit * 2))
			else
				limit=$((limit / 2))
			fi
			found_per_second="${found_per_second_this_iteration}"
			echo "${total_findings} item(s) found so far, ${findings_this_batch} found in ${total_time}s, ${found_per_second_this_iteration}i/s"
			if [[ "${intense_optimizations}" -eq 0 ]]; then
				sleep "${sleep_time}"
			fi
		done
	fi
done < <("${dbengine}" "${db}" -NBqe "SELECT DISTINCT REFERENCED_COLUMN_NAME FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE WHERE REFERENCED_TABLE_SCHEMA = \"${db}\" AND REFERENCED_TABLE_NAME = \"${referenced_table_name}\"")
"${dbengine}" "${db}" -vvve "SELECT COUNT(*) FROM \`${referenced_table_name}\`"
