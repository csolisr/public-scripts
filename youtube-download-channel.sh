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
#subfolder="${folder}/${channel}"
subfolder="${folder}/subscriptions"
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
cd "${subfolder}" || exit
if [[ ! -f "${archive}" ]]; then
	touch "${archive}"
fi
if [[ -f "${channel}.tar.zst" ]]; then
	if [[ "${channel}" = "subscriptions" ]]; then
		find . -iname "*.tar.zst" | while read -r c; do tar -xvp -I zstd -f "${c}"; done
	else
		tar -xvp -I zstd -f "${channel}.tar.zst"
	fi
fi
#If available, you can use the cookies from your browser directly:
#    --cookies-from-browser "firefox"
url="https://www.youtube.com/@${channel}"
if [[ "${channel}" = "subscriptions" ]]; then
	url="https://www.youtube.com/feed/subscriptions"
fi
if [[ -f "${cookies}" && "${channel}" = "subscriptions" ]]; then
	"${python}" "${ytdl}" "${url}" \
		--skip-download --download-archive "${archive}" \
		--dateafter "${breaktime}" \
		--extractor-args youtubetab:approximate_date \
		--break-on-reject --lazy-playlist --write-info-json \
		--sleep-requests "${sleeptime}"
else
	"${python}" "${ytdl}" "${url}" \
		--cookies "${cookies}" \
		--skip-download --download-archive "${archive}" \
		--dateafter "${breaktime}" \
		--extractor-args youtubetab:approximate_date \
		--break-on-reject --lazy-playlist --write-info-json \
		--sleep-requests "${sleeptime}"
fi
if [[ -f "${csv}" ]]; then
	rm -rf "${csv}"
fi
if [[ ! -f "${sortcsv}" ]]; then
	touch "${sortcsv}"
fi
db=$(date -d"${breaktime}" +"%s")
find . -type f -iname "*.info.json" -exec ls -t {} + | while read -r xp; do
	(
		x="${xp##./}"
		if [[ -f "${subfolder}/${x}" && "${channel}" != "subscriptions" && $(jq -rc ".uploader_id" "${subfolder}/${x}") != "@${channel}" ]]; then
			echo "Video ${x} not uploaded from ${channel}, removing..." && rm "${subfolder}/${x}" #&
		fi
		if [[ -f "${subfolder}/${x}" && "${breaktime}" =~ ^[0-9]+$ && "${db}" -ge "${df}" ]]; then
			echo "Video ${x} uploaded before ${breaktime}, removing..." && rm "${subfolder}/${x}" #&
		fi
		if [[ -f "${subfolder}/${x}" ]]; then
			df=$(jq -rc '.timestamp' "${subfolder}/${x}")
			touch "${subfolder}/${x}" -d "@${df}" #&
		fi
		if [[ -f "${subfolder}/${x}" ]]; then
			echo "youtube $(jq -cr '.id' "${subfolder}/${x}")" | tee -a "${archive}" &
			if [[ ${enablecsv} = "1" ]]; then
				jq -c '[.upload_date, .timestamp, .uploader , .title, .webpage_url]' "${subfolder}/${x}" | while read -r i; do
					echo "${i}" | sed -e "s/^\[//g" -e "s/\]$//g" -e "s/\\\\\"/＂/g" | tee -a "${csv}" #&
				done
			fi
			if [[ ${enablecsv} = "1" || ${enabledb} = "1" ]]; then
				jq -c '[.upload_date, .timestamp]' "${subfolder}/${x}" | while read -r i; do
					echo "${i},${x}" | sed -e "s/^\[//g" -e "s/\],/,/g" -e "s/\\\\\"/＂/g" | tee -a "${sortcsv}" #&
				done
			fi
		fi
	) &
	#if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 3 * 2)) ]]; then
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi

done
wait
if [[ ${enablecsv} = "1" || ${enabledb} = "1" ]]; then
	sort "${sortcsv}" | uniq >"/tmp/${channel}-sort-ordered.csv"
fi
if [[ ${enabledb} = "1" ]]; then
	if [[ -f "/tmp/${channel}.db" ]]; then
		rm "/tmp/${channel}.db"
	fi
	echo "{\"playlistName\":\"${channel}\",\"protected\":false,\"description\":\"Videos from ${channel} to watch later\",\"videos\":[" >"/tmp/${channel}.db"
fi
if [[ ${enablecsv} = "1" || ${enabledb} = "1" ]]; then
	while read -r line; do
		file=$(echo "${line}" | cut -d ',' -f3-)
		#if [[ "${breaktime}" =~ ^[0-9]+$ ]]; then
		#	uploaddate=$(echo "${line}" | cut -d ',' -f1 | sed -e "s/\"//g")
		#	if [[ "${uploaddate}" -lt "${breaktime}" ]]; then
		#		echo "Video ${file} uploaded on ${uploaddate}, removing..."
		#		rm "${file}"
		#	fi
		#fi
		if [[ ${enabledb} = "1" ]]; then
			if [[ -f "${file}" ]]; then
				jq -c "{\"videoId\": .id, \"title\": .title, \"author\": .uploader, \"authorId\": .channel_id, \"lengthSeconds\": .duration, \"published\": ( .timestamp * 1000 ), \"timeAdded\": $(date +%s)$(date +%N | cut -c-3), \"playlistItemId\": \"$(cat /proc/sys/kernel/random/uuid)\", \"type\": \"video\"}" "${subfolder}/${file}" | tee -a "/tmp/${channel}.db"
				echo "," >>"/tmp/${channel}.db"
			fi
		fi
	done <"/tmp/${channel}-sort-ordered.csv"
fi
if [[ ${enabledb} = "1" ]]; then
	echo "],\"_id\":\"${channel}$(date +%s)\",\"createdAt\":$(date +%s),\"lastUpdatedAt\":$(date +%s)}" >>"/tmp/${channel}.db"
	rm "${json}"
	grep -v -e ":[ ]*null" "/tmp/${channel}.db" | tr '\n' '\r' | sed -e "s/,\r[,\r]*/,\r/g" | sed -e "s/,\r\]/\]/g" -e "s/\[\r,/\[/g" | tr '\r' '\n' | jq -c . >"${json}" && rm "/tmp/${channel}.db"
fi
if [[ ${enablecsv} = "1" || ${enabledb} = "1" ]]; then
	rm "/tmp/${channel}-sort-ordered.csv" "${sortcsv}"
fi
if [[ ${enablecsv} = "1" ]]; then
	sort "${csv}" | uniq >"/tmp/${channel}-without-header.csv"
	echo '"Upload Date", "Timestamp", "Uploader", "Title", "Webpage URL"' >"/tmp/${channel}.csv"
	cat "/tmp/${channel}-without-header.csv" >>"/tmp/${channel}.csv"
	mv "/tmp/${channel}.csv" "${csv}"
	rm "/tmp/${channel}-without-header.csv"
fi
sort "${archive}" | uniq >"/tmp/${channel}.txt"
mv "/tmp/${channel}.txt" "${archive}"
tar -cvp -I zstd -f "${channel}.tar.zst" -- *.info.json && rm -- *.info.json
