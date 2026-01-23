#!/bin/bash
#Local mode - determines whether to print output or not. Can pass as the first parameter.
if [[ $(uname -n) == "azkware" ]]; then
	localmode=${1:-"0"}
else
	localmode=${1:-"1"}
fi
#Limit of servers to fetch. Can pass as the second parameter.
limit=${2:-"20"}
#URL of your instance. Can pass as the third parameter.
mysite=${3:-"friendica.example.net"}
#Token from your website. Can pass as the fourth parameter. Needs to be generated using something like GetAuth and the "read" permission ( https://getauth.thms.uk/?scopes=read )
token=${4:-"12345678"}
#URL of the service that contains the list of servers to fetch. Can pass as the fifth parameter.
serverslist=${5:-"https://api.fedidb.org/v1/servers?limit=${limit}"}
#Tweak this if your instance uses a non-standard API.
searchurl="https://${mysite}/api/v2/search?resolve=true&limit=1&type=statuses&q="
#File that will hold the URLs found.
url_file="/tmp/trending_urls.txt"
#File that will hold the blocked domains found.
block_file="/tmp/blocked_urls.txt"
#File that will hold the domains explored.
found_file="/tmp/found_urls.txt"
#File that will hold the trending hashtags found.
tags_file="/tmp/trending_hashtags.txt"
#Amount of threads that will be used for multiprocessing.
threads=$(($(getconf _NPROCESSORS_ONLN) * 2))
#User agent (to be used to identify the process)
useragent="Trending Hashtags Fetcher (https://${mysite})"
#Languages for the trending topics, in ISO format.
languages=("en-US" "es-ES" "ja-JP" "de-DE" "fr-FR")
#Manual overrides for some external services, such as bridges, generally blocked by some servers.
overrides=("threads.net" "threads.com" "threads.instagram.com" "bsky.brid.gy" "bird.makeup" "mostr.pub" "newsmast.org" "newsmast.social" "mastodon.social" "misskey.io" "misskey.gg" "mstdn.jp" "mastodon.cloud" "mastodon.world" "fosstodon.org" "mas.to" "mastodon.art" "troet.cafe" "mastodon.online")

fetch_sites() {
	while read -r searchsite; do
		if [[ ${localmode} != "0" ]]; then
			echo "Site: ${searchsite}" #&> /dev/null
		fi
		echo "${searchsite}" >>"${found_file}"
	done < <(echo "${serversresponse}" | jq -r '.data[].domain' 2>/dev/null)
}

fetch_blocks() {
	while read -r searchsite; do
		fetch_block "${searchsite}" &
		if [[ $(jobs -r -p | wc -l) -ge ${threads} ]]; then
			wait -n
		fi
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
	if [[ -f ${block_file} && -f ${found_file} ]]; then
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
	print_count "${url_file}" "${count_parameter}"
}

fetch_block() {
	while read -r block_to_add; do
		if [[ ${block_to_add} != "null" && -f ${block_file} && -z $(echo "${block_to_add}" | awk "/\*/") ]]; then
			if [[ ${localmode} != "0" ]]; then
				echo "Blocked URL:" "${block_to_add}" #&> /dev/null
			fi
			echo "${block_to_add}" >>"${block_file}"
		fi
	done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" "https://${searchsite}/api/v1/instance/domain_blocks" 2>/dev/null | jq -r '.[] | select(.severity = "suspend") | .domain' 2>/dev/null)
}

fetch_hashtags() {
	while read -r searchsite; do
		did_add_hashtag=0
		while read -r hashtag_to_add; do
			if [[ -n ${hashtag_to_add} && ${hashtag_to_add} != "null" ]]; then
				already_printed=0
				if [[ -f ${tags_file} ]]; then
					if [[ ${already_printed} -eq 0 ]]; then
						if [[ ${localmode} != "0" ]]; then
							echo "Site: ${searchsite} Hashtag: #${hashtag_to_add}" #&> /dev/null
						fi
						already_printed=1
					fi
					echo "${hashtag_to_add}" >>"${tags_file}"
					if [[ -n ${hashtag_to_add} ]]; then
						did_add_hashtag=1
					fi
				fi
			fi
		done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" "https://${searchsite}/api/v1/trends/tags" 2>/dev/null | jq -r '.[].name' 2>/dev/null)
		#If this returns nothing, fall back to the Misskey API
		if [[ ${did_add_hashtag} -eq 0 ]]; then
			while read -r hashtag_to_add; do
				if [[ -n ${hashtag_to_add} && ${hashtag_to_add} != "null" ]]; then
					already_printed=0
					if [[ -f ${tags_file} ]]; then
						if [[ ${already_printed} -eq 0 ]]; then
							if [[ ${localmode} != "0" ]]; then
								echo "Site: ${searchsite} (Misskey API) Hashtag: #${hashtag_to_add}" #&> /dev/null
							fi
							already_printed=1
						fi
						echo "${hashtag_to_add}" >>"${tags_file}"
					fi
				fi
			done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" "https://${searchsite}/api/hashtags/trend" 2>/dev/null | jq -r '.[].tag' 2>/dev/null)
		fi
		#Other APIs I should check:
		#For Misskey:
		#	There doesn't seem to be a specific blocked domains API, besides of the Mastodon compatibility layer.
		#For Pixelfed:
		#	There are backends for everything, but they seem to require an account on each server for authentication.
		#	For trending hashtags:
		#		"https://${searchsite}/api/v1.1/discover/posts/hashtags"
		#	For trending posts:
		#		"https://${searchsite}/api/v1.1/discover/posts/trending"
		#	For blocked domains:
		#		"https://${searchsite}/api/v1/domain_blocks"
		#For Lemmy:
		#	There is an API to post block instances as admin, but not to read them.
		#	Also, there are no hashtags, but there are trending posts that can be accessed via RSS.
		#For PeerTube:
		#	For blocked domains:
		#		"https://${searchsite}/api/v1/server/blocklist/servers"
		#	There are no hashtags, but there are trending posts.
		#	The search API requires some text to search for, however, so this might not work to fetch trending videos per se.
		#		"https://${searchsite}/api/v1/search/videos?sort=-trending&count=100&isLocal=false&search=*"
		#			From here you will need to fetch pairs of '.data[].uuid' and '.data[].channel.host' to get the actual URL, in the form of
		#			"https://${host}/videos/watch/${uuid}"
	done < <(echo "${serversresponse}" | jq -r '.data[].domain' 2>/dev/null)
	wait
	#Deduplicate
	if [[ -f ${tags_file} ]]; then
		if [[ ${localmode} != "0" ]]; then
			echo "Deduplicating hashtags..." #&> /dev/null
		fi
		sort "${tags_file}" | uniq -i >"${tags_file}.tmp" && mv "${tags_file}.tmp" "${tags_file}"
	fi
	#Print amount of hashtags
	count_file="${tags_file}"
	count_parameter="hashtag"
	print_count "${count_file}" "${count_parameter}"
	#Populate
	if [[ -f ${tags_file} ]]; then
		while read -r searchsite; do
			while read -r hashtag_to_add; do
				fetch_hashtag "${hashtag_to_add}" "${searchsite}" &
				if [[ $(jobs -r -p | wc -l) -ge ${threads} ]]; then
					wait -n
				fi
			done <"${tags_file}"
		done < <(echo "${serversresponse}" | jq -r '.data[].domain' 2>/dev/null)
	fi
}

fetch_hashtag() {
	if [[ ${hashtag_to_add} != "null" ]]; then
		did_add_url=0
		already_printed=0
		#Fetch the URLs that contain the hashtag, and populate your website with them
		while read -r url_to_fetch; do
			if [[ -n ${url_to_fetch} && ${url_to_fetch} != "null" ]]; then
				if [[ ${already_printed} -eq 0 ]]; then
					if [[ ${localmode} != "0" ]]; then
						echo "Site: ${searchsite} Hashtag: #${hashtag_to_add}" #&> /dev/null
					fi
					already_printed=1
				fi
				fetch_url "${url_to_fetch}" "${searchsite}"
				if [[ -n ${url_to_fetch} ]]; then
					did_add_url=1
				fi
			fi
		done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" "https://${searchsite}/api/v1/timelines/tag/${hashtag_to_add}?local=false" 2>/dev/null | jq -r '.[].uri' 2>/dev/null)
		#If no URLs are found, fall back to the Misskey API
		if [[ ${did_add_url} -eq 0 ]]; then
			while read -r url_to_fetch; do
				if [[ -n ${url_to_fetch} && ${url_to_fetch} != "null" ]]; then
					if [[ ${already_printed} -eq 0 ]]; then
						if [[ ${localmode} != "0" ]]; then
							echo "Site: ${searchsite} (Misskey API) Hashtag: #${hashtag_to_add}" #&> /dev/null
						fi
						already_printed=1
					fi
					fetch_url "${url_to_fetch}" "${searchsite}"
				fi
			done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" -H 'Content-Type: application/json' -d "{\"query\": \"#${hashtag_to_add}\"}" "https://${searchsite}/api/notes/search" 2>/dev/null | jq -r '.[].uri' 2>/dev/null)
		fi
	fi
}

fetch_trending_posts() {
	while read -r searchsite; do
		for language in "${languages[@]}"; do
			already_printed=0
			while read -r url_to_fetch; do
				if [[ ${url_to_fetch} != "null" ]]; then
					if [[ ${already_printed} -eq 0 ]]; then
						if [[ ${localmode} != "0" ]]; then
							echo "Site: ${searchsite} Trending posts (${language})" #&> /dev/null
						fi
						already_printed=1
					fi
					fetch_url "${url_to_fetch}" &
					if [[ $(jobs -r -p | wc -l) -ge ${threads} ]]; then
						wait -n
					fi

				fi
			done < <(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" -H "Accept-Language: ${language}" "https://${searchsite}/api/v1/trends/statuses" 2>/dev/null | jq -r '.[].uri' 2>/dev/null)
		done
	done < <(echo "${serversresponse}" | jq -r '.data[].domain' 2>/dev/null)
	wait
}

fetch_url() {
	if [[ ${url_to_fetch} != "null" ]]; then
		if [[ ${localmode} != "0" ]]; then
			echo "Site: ${searchsite} URL: ${url_to_fetch}" #&> /dev/null
		fi
		echo "${url_to_fetch}" >>"${url_file}"
	fi
}

search_urls() {
	#Deduplicate
	if [[ -f ${url_file} ]]; then
		if [[ ${localmode} != "0" ]]; then
			echo "Deduplicating URLs..." #&> /dev/null
		fi
		sort "${url_file}" | uniq -i >"${url_file}.tmp" && mv "${url_file}.tmp" "${url_file}"
	fi
	#Remove blocked domains from the results
	if [[ -f ${block_file} && -f ${url_file} ]]; then
		while read -r url_to_remove; do
			grep -v -F -e "${url_to_remove}" -- "${url_file}" >"${url_file}.tmp" && mv "${url_file}.tmp" "${url_file}"
		done <"${block_file}"
	fi
	#Print amount of URLs
	count_file="${url_file}"
	count_parameter="URL"
	print_count "${url_file}" "${count_parameter}"
	current_url=0
	total_url=0
	if [[ ${localmode} != 0 ]]; then
		if [[ -f ${url_file} ]]; then
			total_url=$(wc -l "${url_file}" | cut -d ' ' -f1)
		fi
	fi
	while read -r url_to_fetch; do
		current_url=$((current_url + 1))
		search_url "${url_to_fetch}" "${current_url}" "${total_url}" &
		if [[ $(jobs -r -p | wc -l) -ge ${threads} ]]; then
			wait -n
		fi
	done <"${url_file}"
	wait
	#Print amount of URLs
	count_file="${url_file}"
	count_parameter="URL"
	print_count "${url_file}" "${count_parameter}"
}

search_url() {
	if [[ ${url_to_fetch} != "null" ]]; then
		curl_response_raw=$(curl -s -S --no-progress-meter -L -H "User-Agent: ${useragent}" -H "Authorization: Bearer ${token}" "${searchurl}${url_to_fetch}" 2>/dev/null)
		if [[ ${localmode} != "0" ]]; then
			curl_response=$(echo "${curl_response_raw}" | jq -r '.statuses[0].content' 2>/dev/null | sed -e 's/<[^>]*>/ /g' -e 's/  */ /g' -e 's/# /#/g' -e 's/^ //g')
			if [[ -n ${curl_response} && ${curl_response} != "null" ]]; then
				echo "${current_url}/${total_url} URL: ${url_to_fetch} ${curl_response}" #&> /dev/null
			else
				echo "${current_url}/${total_url} Waiting for URL:" "${url_to_fetch}" #&> /dev/null
			fi
		fi
	fi
}

print_count() {
	if [[ ${localmode} != "0" ]]; then
		if [[ -f ${count_file} ]]; then
			count_amount=$(wc -l "${count_file}" | cut -d ' ' -f1)
			echo "Found ${count_amount} ${count_parameter}(s)" #&> /dev/null
		fi
	fi
}

clear_files() {
	if [[ -f ${url_file} ]]; then
		rm -rf "${url_file}" #&> /dev/null
	fi
	if [[ -f ${block_file} ]]; then
		rm -rf "${block_file}" #&> /dev/null
	fi
	if [[ -f ${found_file} ]]; then
		rm -rf "${found_file}" #&> /dev/null
	fi
	if [[ -f ${tags_file} ]]; then
		rm -rf "${tags_file}" #&> /dev/null
	fi
}

initialize_files() {
	touch "${url_file}"   #&> /dev/null
	touch "${block_file}" #&> /dev/null
	touch "${found_file}" #&> /dev/null
	touch "${tags_file}"  #&> /dev/null
}

#Main process
main() {
	if [[ ${localmode} != "0" ]]; then
		starttime=$(date +'%s')
	fi
	clear_files
	initialize_files
	serversresponse=$(curl -s -S --no-progress-meter -L "${serverslist}")
	fetch_sites "${serversresponse}"
	fetch_blocks "${serversresponse}"
	fetch_hashtags "${serversresponse}"
	fetch_trending_posts "${serversresponse}"
	search_urls
	clear_files
	if [[ ${localmode} != "0" ]]; then
		endtime=$(date +'%s')
		elapsedtime=$((endtime - starttime))
		elapsedtimehuman=$(date -d@"${elapsedtime}" -u +%Hh\ %Mm\ %Ss)
		echo "Time elapsed = ${elapsedtimehuman}" #&> /dev/null
	fi
}
main
