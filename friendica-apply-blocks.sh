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
#Via https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
folder=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
#Amount of threads that will be used for multiprocessing.
threads=$(($(getconf _NPROCESSORS_ONLN) * 2))
#File that will hold the blocked domains found.
block_file="/tmp/blocked_urls.txt"
#Manual overrides for some external services, such as bridges, generally blocked by some servers.
overrides=(_OVERRIDES_)
#Local mode - determines whether to print output or not. Can pass as the first parameter.
if [[ $(uname -n) == "azkware" ]]; then
	localmode=${1:-"0"}
else
	localmode=${1:-"1"}
fi
#Limit of servers to fetch. Can pass as the second parameter.
limit=${2:-"20"}
#Name of the database. Can pass as the third parameter.
db=${3:-"friendica"}
#User of the instance. Can pass as the fourth parameter.
user=${4:-"friendica"}
#Location of the folder where the site resides. Can pass as the fifth parameter.
site_folder=${4:-"/var/www/friendica"}
#URL of your instance. Can pass as the sixth parameter.
mysite=${6:-"friendica.example.net"}
#URL of the service that contains the list of servers to fetch. Can pass as the seventh parameter.
serverslist=${7:-"https://api.fedidb.org/v1/servers?limit=${limit}"}
#User agent (to be used to identify the process)
useragent="Trending Hashtags Fetcher (https://${mysite})"

print_count() {
	if [[ ${localmode} != "0" ]]; then
		if [[ -f ${count_file} ]]; then
			count_amount=$(wc -l "${count_file}" | cut -d ' ' -f1)
			echo "Found ${count_amount} ${count_parameter}(s)" #&> /dev/null
		fi
	fi
}

process_blocks() {
	if [[ -n ${i} ]]; then
		if [[ -z ${i_reason} ]]; then
			i_reason="Shared banlist"
		fi
		i_reason=$(echo "${i_reason}" | sed -e 's/"/”/g')
		if ! (echo "${current_server_blocks}" | grep -q -e "${i}"); then
			bash -c "sudo -u ${user} php ${site_folder}/bin/console.php serverblock add ${i} \"${i_reason}\""
		fi
		if (echo "${current_server_blocks}" | grep -e "| ${i} +|" | grep -q -e "Shared banlist") && [[ ${i_reason} != "Shared banlist" ]]; then
			bash -c "sudo -u ${user} php ${site_folder}/bin/console.php serverblock remove ${i}"
			bash -c "sudo -u ${user} php ${site_folder}/bin/console.php serverblock add ${i} \"${i_reason}\""
		fi
		if [[ -z $(echo "${current_server_blocks}" | grep -e "${i}" | sed -e "s/${i}//g" -e "s/|//g" -e "s/\s//g") ]]; then
			bash -c "sudo -u ${user} php ${site_folder}/bin/console.php serverblock remove ${i}"
			bash -c "sudo -u ${user} php ${site_folder}/bin/console.php serverblock add ${i} \"${i_reason}\""
		fi
	fi
	"${dbengine}" "${db}" -NBqe "select \`id\` from \`contact\` where \`baseurl\` = \"https://${i}\"" | while read -r j; do
		bash friendica-delete-specific-contact.sh "${j}" &
		until [[ $(jobs -r -p | wc -l) -le ${threads} ]]; do
			sleep 0.1
		done
	done
}

fetch_blocks() {
	while read -r searchsite; do
		fetch_block "${searchsite}" &
		until [[ $(jobs -r -p | wc -l) -le ${threads} ]]; do
			sleep 0.1
		done
	done < <(echo "${serversresponse}" | jq -r '.data[].domain' 2>/dev/null)
	wait
	#Deduplicate
	if [[ -f ${block_file} ]]; then
		if [[ ${localmode} != "0" ]]; then
			echo "Deduplicating blocks..." #&> /dev/null
		fi
		sort "${block_file}" | uniq -i >"${block_file}.tmp" && mv "${block_file}.tmp" "${block_file}"
	fi
	#Override URLs from the block list, since some smaller instances block bridging services, corporate servers, or even larger instances solely due to their size.
	if [[ -f ${block_file} ]]; then
		if [[ ${localmode} != "0" ]]; then
			echo "Reinstating domains..." #&> /dev/null
		fi
		for override in "${overrides[@]}"; do
			grep -v -F -e "${override}" -- "${block_file}" >"${block_file}.tmp" && mv "${block_file}.tmp" "${block_file}"
		done
	fi
	#Print amount of blocked URLs
	count_file="${block_file}"
	count_parameter="blocked URL"
	print_count "${block_file}" "${count_parameter}"

	current_server_blocks=$(bash -c "sudo -u ${user} php ${site_folder}/bin/console.php serverblock")
	while read -r i i_reason; do
		process_blocks "${i}" "${i_reason}" "${current_server_blocks}" &
		until [[ $(jobs -r -p | wc -l) -le ${threads} ]]; do
			sleep 0.1
		done
	done <"${block_file}"
	wait
}

fetch_block() {
	while read -r block_to_add block_reason; do
		if [[ ${block_to_add} != "null" && -f ${block_file} && -z $(echo "${block_to_add}" | awk "/\*/") ]]; then
			if [[ ${localmode} != "0" ]]; then
				echo "Blocked URL:" "${block_to_add}" "${block_reason}" #&> /dev/null
			fi
			echo "${block_to_add} ${block_reason}" >>"${block_file}"
		fi
		#done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" "https://${searchsite}/api/v1/instance/domain_blocks" 2>/dev/null | jq -r '.[] | select(.severity = "suspend") | [.domain, .comment] | @tsv' 2>/dev/null)
	done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" "https://${searchsite}/api/v1/instance/domain_blocks" 2>/dev/null | jq -r '.[] | [.domain, .comment] | @tsv' 2>/dev/null)

	until [[ $(jobs -r -p | wc -l) -le ${threads} ]]; do
		sleep 0.1
	done
}
clear_files() {
	if [[ -f ${block_file} ]]; then
		rm -rf "${block_file}" #&> /dev/null
	fi
}

initialize_files() {
	touch "${block_file}" #&> /dev/null
}

#Main process
main() {
	cd "${folder}" || exit
	if [[ ${localmode} != "0" ]]; then
		starttime=$(date +'%s')
	fi
	clear_files
	initialize_files
	serversresponse=$(curl -s -S --no-progress-meter -L "${serverslist}")
	fetch_blocks "${serversresponse}"
	clear_files
	if [[ ${localmode} != "0" ]]; then
		endtime=$(date +'%s')
		elapsedtime=$((endtime - starttime))
		elapsedtimehuman=$(date -d@"${elapsedtime}" -u +%Hh\ %Mm\ %Ss)
		echo "Time elapsed = ${elapsedtimehuman}" #&> /dev/null
	fi
}
main
