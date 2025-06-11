#!/bin/bash
#Parameters:
#1st parameter: Channel you want to turn into a playlist. Leave blank to save your subscriptions (cookie file required)
channel=${1:-"subscriptions"}
#2nd parameter: Time limit for the download. Leave blank to save all videos from the last month.
breaktime=${2:-"today-1month"}
#3rd parameter: Seconds between data requests. Decrease to make downloads faster, but your account may be temporarily blocked if you use a number too low.
sleeptime=${3:-"1.0"}
#4th parameter: Whether to enable exporting to FreeTube playlist database (1=on by default, 0=off)
enabledb=${4:-"1"}
#5th parameter: Whether to enable exporting to a CSV file (1=on by default, 0=off)
enablecsv=${5:-"1"}
#Internal variables:
#Via https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
folder=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
#Required to download your own subscriptions.
#Obtain this file through the procedure listed at
# https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp
#and place it next to your script.
cookies="${folder}/yt-cookies.txt"
subfolder="${folder}/subscriptions"
temporary="/tmp/subscriptions/${channel}"
archive="${subfolder}/${channel}.txt"
sortcsv="${subfolder}/${channel}-sort.csv"
csv="${subfolder}/${channel}.csv"
json="${subfolder}/${channel}.db"
python="python"
if [[ -f "/opt/venv/bin/python" ]]; then
	python="/opt/venv/bin/python"
fi
ytdl="/usr/bin/yt-dlp"
if [[ -f "/opt/venv/bin/yt-dlp" ]]; then
	ytdl="/opt/venv/bin/yt-dlp"
fi
if [[ ! -d "${subfolder}" ]]; then
	mkdir -v "${subfolder}"
fi
if [[ ! -d "/tmp/subscriptions" ]]; then
	mkdir -v "/tmp/subscriptions"
fi
if [[ ! -d "${temporary}" ]]; then
	mkdir -v "${temporary}"
fi
cd "${temporary}" || exit
if [[ ! -f "${archive}" ]]; then
	touch "${archive}"
fi
if [[ -f "${subfolder}/${channel}.tar.zst" ]]; then
	if [[ "${channel}" = "subscriptions" ]]; then
		find "${subfolder}" -iname "*.tar.zst" | while read -r c; do tar -xvp -I zstd -f "${c}"; done
	else
		tar -xvp -I zstd -f "${subfolder}/${channel}.tar.zst"
	fi
fi
url="https://www.youtube.com/@${channel}"
if [[ "${channel}" = "subscriptions" ]]; then
	url="https://www.youtube.com/feed/subscriptions"
fi
if [[ -f "${cookies}" && "${channel}" = "subscriptions" ]]; then
	#If available, you can use the cookies from your browser directly. Substitute
	#	--cookies "${cookies}"
	#for the below, substituting for your browser of choice:
	#	--cookies-from-browser "firefox"
	#In case this still fails, you can resort to a PO Token. Follow the instructions at
	# https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide
	#and add a new variable with the contents of the PO Token in the form
	#	potoken="INSERTYOURPOTOKENHERE"
	#then substitute the "--extractor-args" line below with
	#	--extractor-args "youtubetab:approximate_date,youtube:player-client=default,mweb;po_token=mweb.gvs+${potoken}" \
	#including the backslash so the multiline command keeps working.
	"${python}" "${ytdl}" "${url}" \
		--cookies "${cookies}" \
		--extractor-args "youtubetab:approximate_date" \
		--skip-download --download-archive "${archive}" \
		--dateafter "${breaktime}" \
		--break-on-reject --lazy-playlist --write-info-json \
		--sleep-requests "${sleeptime}"
else
	"${python}" "${ytdl}" "${url}" \
		--extractor-args "youtubetab:approximate_date" \
		--skip-download --download-archive "${archive}" \
		--dateafter "${breaktime}" \
		--break-on-reject --lazy-playlist --write-info-json \
		--sleep-requests "${sleeptime}"
fi
if [[ ${enablecsv} = 1 ]]; then
	if [[ -f "${csv}" ]]; then
		rm -rf "${csv}"
	fi
	touch "${csv}"
fi
if [[ ${enabledb} = 1 ]]; then
	if [[ -f "${sortcsv}" ]]; then
		rm -rf "${sortcsv}"
	fi
	touch "${sortcsv}"
fi
breaktime_timestamp=$(date -d"${breaktime}" +"%s")
count=0
total=$(find "${temporary}" -type f -iname "*.info.json" | wc -l)
find "${temporary}" -type f -iname "*.info.json" | while read -r x; do
	count=$((count + 1))
	(
		if [[ -f "${x}" && "${channel}" != "subscriptions" && $(jq -rc ".uploader_id" "${x}") != "@${channel}" ]]; then
			echo "Video ${x} not uploaded from ${channel}, removing..." && rm "${x}"
		fi
		if [[ -f "${x}" && "${breaktime}" =~ ^[0-9]+$ ]]; then
			file_timestamp=$(jq -rc '.timestamp' "${x}")
			if [[ "${breaktime_timestamp}" -ge "${file_timestamp}" ]]; then
				echo "Video ${x} uploaded before ${breaktime}, removing..." && rm "${x}"
			fi
		fi
		if [[ -f "${x}" ]]; then
			if [[ ${enablecsv} = "1" ]]; then
				jq -c '[.upload_date, .timestamp, .uploader , .title, .webpage_url]' "${x}" | while read -r i; do
					echo "${i}" | sed -e "s/^\[//g" -e "s/\]$//g" -e "s/\\\\\"/＂/g" >>"${csv}"
				done
			fi
			if [[ ${enabledb} = "1" ]]; then
				jq -c '[.upload_date, .timestamp]' "${x}" | while read -r i; do
					echo "${i},${x##*/}" | sed -e "s/^\[//g" -e "s/\],/,/g" -e "s/\\\\\"/＂/g" >>"${sortcsv}"
				done
			fi
			echo "${count}/${total} ${x}"
		fi
	) &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi

done
wait
sleep 1
if [[ ${enabledb} = "1" ]]; then
	sort "${sortcsv}" | uniq >"/tmp/${channel}-sort-ordered.csv"
	if [[ -f "/tmp/${channel}.db" ]]; then
		rm "/tmp/${channel}.db"
	fi
	echo "{\"playlistName\":\"${channel}\",\"protected\":false,\"description\":\"Videos from ${channel} to watch later\",\"videos\":[" >"/tmp/${channel}.db"
	count=0
	total=$(wc -l <"/tmp/${channel}-sort-ordered.csv")
	while read -r line; do
		count=$((count + 1))
		file=$(echo "${line}" | cut -d ',' -f3-)
		if [[ -f "${file}" ]]; then
			jq -c "{\"videoId\": .id, \"title\": .title, \"author\": .uploader, \"authorId\": .channel_id, \"lengthSeconds\": .duration, \"published\": ( .timestamp * 1000 ), \"timeAdded\": $(date +%s)$(date +%N | cut -c-3), \"playlistItemId\": \"$(cat /proc/sys/kernel/random/uuid)\", \"type\": \"video\"}" "${temporary}/${file}" >>"/tmp/${channel}.db"
			echo "," >>"/tmp/${channel}.db"
			echo "${count}/${total} ${file}"
		fi
	done <"/tmp/${channel}-sort-ordered.csv"
	echo "],\"_id\":\"${channel}$(date +%s)\",\"createdAt\":$(date +%s),\"lastUpdatedAt\":$(date +%s)}" >>"/tmp/${channel}.db"
	rm "${json}"
	grep -v -e ":[ ]*null" "/tmp/${channel}.db" | tr '\n' '\r' | sed -e "s/,\r[,\r]*/,\r/g" | sed -e "s/,\r\]/\]/g" -e "s/\[\r,/\[/g" | tr '\r' '\n' | jq -c . >"${json}" && rm "/tmp/${channel}.db"
	rm "/tmp/${channel}-sort-ordered.csv" "${sortcsv}"
fi
if [[ ${enablecsv} = "1" ]]; then
	sort "${csv}" | uniq >"/tmp/${channel}-without-header.csv"
	echo '"Upload Date", "Timestamp", "Uploader", "Title", "Webpage URL"' >"/tmp/${channel}.csv"
	cat "/tmp/${channel}-without-header.csv" >>"/tmp/${channel}.csv"
	mv "/tmp/${channel}.csv" "${csv}"
	rm "/tmp/${channel}-without-header.csv"
fi
cd "${temporary}" || exit
tar -cvp -I "zstd -T0" -f "${subfolder}/${channel}.tar.zst" -- *.info.json
find "${temporary}" -type f -iname "*.info.json" | while read -r x; do
	if [[ -f "${x}" ]]; then
		echo "youtube $(jq -cr '.id' "${x}")" >>"${archive}"
	fi
done
sort "${archive}" | uniq >"/tmp/${channel}.txt" && mv "/tmp/${channel}.txt" "${archive}"
rm -rf "${temporary}"
