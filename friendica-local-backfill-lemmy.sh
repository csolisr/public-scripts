#!/bin/bash
#Amount of days to fetch. Can pass as the first parameter.
amountofdays=${1:-"1"}
#URL of your instance. Can pass as the second parameter.
mysite=${2:-"friendica.example.net"}
#Token from your website. Can pass as the third parameter. Needs to be generated using something like GetAuth and the "read" permission ( https://getauth.thms.uk/?scopes=read )
token=${3:-"12345678"}
#MariaDB database.
db="friendica"
#User agent
useragent="Friendica Local Backfill (https://${mysite})"
#URL array of the Lemmy sites you want to backfill.
sites=()
while read -r line; do
	sites+=("${line}")
done < <(mariadb "${db}" -N -B -q -e "select c.url from \`contact\` c join \`user-contact\` u where c.url like \"https:\/\/%\/c\/%\" and c.id = u.cid and (u.rel = 2 or u.rel=3)" | sort -u | sed -e "s/\/c\/.*//g" -e "s/https:\/\///g" -e "s/\/.*//g" | uniq -i)
#Tweak this if your instance uses a non-standard API.
searchurl="https://${mysite}/api/v2/search?resolve=true&limit=1&type=statuses&q="
echo "${searchurl}" #&> /dev/null
#Define the amount of time we will go back at maximum
lastepoch=$(date -d "${amountofdays} days ago" '+%s')
#Parallel part of the function
loop() {
	#If the item is not empty
	if [[ -n ${item} && ! ${item} =~ " " ]]; then
		#Manually backfill the address to our backend
		#curl -s --no-progress-meter -H "User-Agent: ${useragent}" -H "Authorization: Bearer ${token}" "${searchurl}${item}" -O /dev/null
		item_result=$(curl -s --no-progress-meter -H "User-Agent: ${useragent}" -H "Authorization: Bearer ${token}" "${searchurl}${item}")
		itemid=$(echo "${item_result}" | jq -r '.statuses[0].id')
		#Download the HTML of the page, clean it with XMLStarlet
		jpdl=$(curl -s --no-progress-meter -H "User-Agent: ${useragent}" "${item}" 2>/dev/null)
		if [[ -n ${jpdl} ]]; then
			jp=$(echo "${jpdl}" | xmlstarlet fo -H -R 2>/dev/null)
			#Select the canonical address of the page
			j=$(echo "${jp}" | xmlstarlet sel -t -v '/html/head/link[@rel="canonical"]/@href' 2>/dev/null)
			#If neither is empty, and if the canonical address is in another server, backfill that as well
			if [[ -n ${jp} && -n ${j} && ${j} != "${item}" ]]; then
				#curl -s --no-progress-meter -H "Authorization: Bearer ${token}" "${searchurl}${j}" -O /dev/null
				j_result=$(curl -s --no-progress-meter -H "Authorization: Bearer ${token}" "${searchurl}${j}")
				jid=$(echo "${j_result}" | jq -r '.statuses[0].id')
				if [[ ${jid} != "null" ]]; then
					if [[ ${itemid} != null ]]; then
						echo "${commnumber}/${commtotal} Community = ${comm} Position = ${position}/${ai}; Post = ${item} (internal), ${j} (external) - ${itemid} = ${jid}" #&> /dev/null
					else
						echo "${commnumber}/${commtotal} Community = ${comm} Position = ${position}/${ai}; Post = ${j} (external) - ${jid}" #&> /dev/null
					fi
				else
					echo "${commnumber}/${commtotal} Community = ${comm} Position = ${position}/${ai}; Post = ${item} (internal) - Waiting for itemid" #&> /dev/null
				fi
			#If there is no external canonical address to backfill, but there is an internal one:
			else
				#If our backend has returned an item ID:
				if [[ -n ${itemid} && ${itemid} != "null" ]]; then
					echo "${commnumber}/${commtotal} Community = ${comm} Position = ${position}/${ai}; Post = ${item} (internal) - ${itemid}" #&> /dev/null
				else
					echo "${commnumber}/${commtotal} Community = ${comm} Position = ${position}/${ai}; Post = ${item} (internal) - Waiting for itemid" #&> /dev/null
				fi
			fi
		fi
	fi
}
comm_loop() {
	#If any community is found
	if [[ -n ${comm} ]]; then
		#Iterate per page until we have no new items
		keep_looping=1
		m_page="1"
		while [[ ${keep_looping} -eq 1 ]]; do
			#Lemmy backend
			s="https://${a}/feeds/${comm}.xml"
			echo "${commnumber}/${commtotal} Feed: ${s}" #&> /dev/null
			#Find all GUIDs in the RSS feed of the community
			m=()
			while IFS="" read -r m_line; do
				m+=("${m_line}")
			done < <(curl -s -L -m 10 -H "User-Agent: ${useragent}" "${s}"?sort=New\&limit=50\&page="${m_page}" | xmlstarlet sel -t -m "//item" -v "concat(guid,'|',pubDate,'#')" -n 2>/dev/null | tr ' ' '_')
			if [[ ${#m[@]} -eq 0 ]]; then
				#If no items are found, fall back to Piefed backend.
				#Warning: this RSS feed does not seem to have a limit of items, so we will just assume no looping is allowed
				comm_trimmed=$(echo "${comm}" | sed -e "s/c\///g")
				s="https://${a}/community/${comm_trimmed}/feed"
				echo "${commnumber}/${commtotal} Feed (PieFed backend): ${s}" #&> /dev/null
				while IFS="" read -r m_line; do
					m+=("${m_line}")
				done < <(curl -s -L -m 10 -H "User-Agent: ${useragent}" "${s}" | xmlstarlet sel -t -m "//item" -v "concat(guid,'|',pubDate,'#')" -n 2>/dev/null | tr ' ' '_')
				keep_looping=0
			fi
			#We use our own separators for guid and pubDate, in the format "guid|pubDate# "
			dropped=0
			#Deduplicate GUIDs
			m_dedup=()
			while IFS="" read -r m_dedup_line; do
				m_dedup+=("${m_dedup_line}")
			done < <(echo "${m[@]}" | tr '# ' '\n' | sort -u | uniq -i)
			mb=()
			#Remove items older than the stated period
			for mx in "${m_dedup[@]}"; do
				#Split the item by its separator, |
				itemurl="${mx%%|*}"
				itemdate="${mx#*|}"
				#Parse date from the second item of the separator
				epoch=$(date -d "$(echo "${itemdate}" | tr '_' ' ')" '+%s')
				#If the items are valid (not empty):
				if [[ -n ${itemurl} && -n ${itemdate} ]]; then
					#If the date is older than the specified time, ignore
					if [[ ${epoch} -gt ${lastepoch} ]]; then
						mb+=("${itemurl}")
					else
						dropped=$((dropped + 1))
					fi
				fi
			done
			ai="${#mb[@]}"
			echo "${sites_count}/${sites_total} Site: ${a}, ${commnumber}/${commtotal} Community = ${comm}; Amount of items = ${ai}, Dropped = ${dropped}" #&> /dev/null
			#Start loop
			while read -r item position; do
				#Parallelize to our loop function
				loop "${item}" "${position}" "${ai}" "${comm}" "${commnumber}" "${commtotal}" &
				#Wait until we have enough cores free to continue
				if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN))) ]]; then
					wait -n
				fi
				#TODO: Find a better way to parse the array into "read"
			done < <(
				position=0
				for mi in "${mb[@]}"; do
					position=$((position + 1))
					echo "${mi} ${position}"
				done
			)
			wait
			#End loop
			if [[ ${dropped} -gt 0 || ${ai} -eq 0 ]]; then
				keep_looping=0
			else
				m_page=$((m_page + 1))
			fi
		done
	fi
}
outer_loop() {
	sitereq=$(curl -s -L --head -m 5 -H "User-Agent: ${useragent}" --request GET "${a}")
	status=$(echo "${sitereq}" | grep "200")
	if [[ -n ${status} ]]; then
		#Only process communities from the sites we want to backfill, ignore the rest
		comms=()
		#Parse all the landing page feeds for several categories
		lemmyfeed="https://${a}/feeds/local.xml"
		for i in \
			"${lemmyfeed}?sort=Active&limit=50" \
			"${lemmyfeed}?sort=Hot&limit=50" \
			"${lemmyfeed}?sort=Scaled&limit=50" \
			"${lemmyfeed}?sort=TopDay&limit=50" \
			"${lemmyfeed}?sort=TopHour&limit=50" \
			"${lemmyfeed}?sort=TopSixHour&limit=50" \
			"${lemmyfeed}?sort=TopTwelveHour&limit=50"; do

			#TODO: fetch the community URLs straight from our backend, if possible.
			for n in "${sites[@]}"; do
				#Only process communities from the sites we want to backfill, ignore the rest
				if [[ ${i} =~ ${n} ]]; then
					#Parse the RSS feed, find each community ("https://example.com/c/community")
					#TODO: find if there's a better way to parse this through XMLStarlet alone
					for sp in $(curl -L -m 10 -s -H "User-Agent: ${useragent}" "${i}" 2>/dev/null | xmlstarlet sel -T -t -c "//item/description" 2>/dev/null |
						grep -o -e "<a href=\"https://${n}/c/.*\">.*<\/a>" |
						sed -e "s/</\n/g" -e "s/>/\n/g" | grep -o -e "https://${n}/c/.*" |
						sed -e "s/https:\/\/${n}\///g" -e 's/"//g' -e "s/ /\r\n/g" | uniq -i); do
						#If any community is found, add it to our list
						if [[ -n ${sp} ]]; then
							comms+=("${sp}")
						fi
					done
					#TODO: Use the list of users to populate as well
					#for sq in $(curl -L -m 10 -s -H "User-Agent: ${useragent}" "${i}" 2>/dev/null | xmlstarlet sel -T -t -c "//item/description" 2>/dev/null |
					#grep -o -e "<a href=\"https://${n}/u/.*\">.*<\/a>" |
					#sed -e "s/</\n/g" -e "s/>/\n/g" | grep -o -e "https://${n}/u/.*" |
					#sed -e "s/https:\/\/${n}\///g" -e "s/\"//g" -e "s/ /\r\n/g" | uniq -i); do
					##If any user is found, add it to our list
					#if [[ -n ${sq} ]]; then
					#users+=("${sq}")
					#fi
					#done
				fi
			done
		done
		#Fetch an array of all communities known on our database
		i=()
		while IFS="" read -r line; do
			i+=("${line}")
		done < <(mariadb "${db}" -N -B -q -e "select c.url from \`contact\` c join \`user-contact\` u where c.url like \"https:\/\/${a}%\/c\/%\" and c.id = u.cid and (u.rel = 2 or u.rel=3)")
		for n in "${i[@]}"; do
			if [[ ${n} =~ ${a} ]]; then
				#If any community is found, add it to our list
				sp=$(echo "${n}" | sed -e "s/https:\/\/${a}\///g")
				if [[ -n ${sp} ]]; then
					comms+=("${sp}")
				fi
			fi
		done
		#Deduplicate communities
		comms_dedup=()
		while IFS="" read -r line; do
			comms_dedup+=("${line}")
		done < <(echo "${comms[@]}" | tr ' ' '\n' | sort -u | uniq -i)
		for comm in "${comms_dedup[@]}"; do
			echo "https://${a}/${comm}" #&> /dev/null
		done
		commtotal="${#comms_dedup[@]}"
		echo "${sites_count}/${sites_total} Amount of unique communities for ${a}: ${commtotal}" #&> /dev/null
		commnumber=0
		for comm in "${comms_dedup[@]}"; do
			commnumber=$((commnumber + 1))
			comm_loop "${comm}" "${commnumber}" "${commtotal}" "${a}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; then
				wait -n
			fi
		done
		wait
		echo "Finished with site ${a}" #&> /dev/null
	else
		echo "${a} status: $(echo "${sitereq}" | grep -e HTTP)" #&> /dev/null
	fi
}
#Check if our dependencies are installed (XMLStarlet, curl, mariadb)
if [[ -n $(type xmlstarlet) && -n $(type curl) && -n $(type mariadb) && -n $(type date) ]]; then
	sites_count=0
	sites_total="${#sites[@]}"
	echo "Amount of unique sites: ${#sites[@]}" #&> /dev/null
	#Iterate through all the sites we want to backfill
	for a in "${sites[@]}"; do
		sites_count=$((sites_count + 1))
		outer_loop "${a}" "${sites_count}" "${sites_total}" &
		if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN))) ]]; then
			wait -n
		fi
	done
	wait
fi
