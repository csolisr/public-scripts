#!/bin/bash
#Parameters:
#1st parameter: Channel you want to turn into a playlist. Leave blank to save your subscriptions (cookie file required)
channel=${1:-"subscriptions"}
#2nd parameter: Time limit for the download. Leave blank to save all videos from the last month.
breaktime=${2:-"today-1month"}
#3rd parameter: Seconds between data requests. Decrease to make downloads faster, but your account may be temporarily blocked if you use a number too low.
sleeptime=${3:-"0.1"}
#4th parameter: Whether to enable exporting to FreeTube playlist database (1=on by default, 0=off)
enabledb=${4:-"1"}
#5th parameter: Whether to enable exporting to a CSV file (1=on by default, 0=off)
enablecsv=${5:-"1"}
#6th parameter: Personal folder where yt_dlp is hosted - specifically for Windows over Cygwin/WSL. Substitute this as required.
personal_folder=${6:-"/cygdrive/d/Nextcloud/Multimedia/Document/Playnite"}
#7th parameter: Whether to override reading the loop file. Required if running individual channel fetches.
override_loop=${7:-"0"}
#Internal variables:
#Via https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
folder=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
#Required to download your own subscriptions.
#Obtain this file through the procedure listed at
# https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp
#and place it next to your script.
cookies="${folder}/yt-cookies.txt"
subfolder="${folder}/subscriptions"
subscriptions_old="${subfolder}/subscriptions-old.csv"
subscriptions_new="${subfolder}/subscriptions-new.csv"
diff_file="/tmp/subscriptions-diff.csv"
loop_file="${subfolder}/loop-file.csv"
final="${folder}/../FreeTube/playlists.db"

core_loop() {
	if [[ -f ${subscriptions_old} && -f ${subscriptions_new} ]]; then
		diff <(sort "${subscriptions_old}" | cut -d ',' -f2) <(sort "${subscriptions_new}" | cut -d ',' -f2) | grep "< " | sed -e "s/< //g" -e "s/http:\/\/www.youtube.com\/channel\///g" | sort | uniq >"${diff_file}"
	fi
	temporary="/tmp/subscriptions-${channel}"
	if [[ ! -w "/tmp" ]]; then
		temporary="${subfolder}/subscriptions-${channel}"
	fi
	archive="${subfolder}/${channel}.txt"
	sortcsv="${temporary}/${channel}-sort.csv"
	csv="${subfolder}/${channel}.csv"
	tmpcsv="${temporary}/${channel}.csv"
	json="${subfolder}/${channel}.db"
	ytdl="yt-dlp"
	deno="deno"
	if [[ -f "/usr/bin/yt-dlp" ]]; then
		ytdl="/usr/bin/yt-dlp"
	fi
	if [[ -f "/opt/venv/bin/yt-dlp" ]]; then
		ytdl="/opt/venv/bin/yt-dlp"
	fi
	if [[ -f "/data/data/com.termux/files/usr/bin/yt-dlp" ]]; then
		ytdl="/data/data/com.termux/files/usr/bin/yt-dlp"
	fi
	if [[ -f "${personal_folder}/yt-dlp.exe" ]]; then
		ytdl="${personal_folder}/yt-dlp.exe"
	fi
	if [[ -f "/root/.deno/bin/deno" ]]; then
		deno="/root/.deno/bin/deno"
	fi
	folder_user=$(stat -c "%U" "${folder}")
	folder_group=$(stat -c "%G" "${folder}")
	if [[ ! -d ${subfolder} ]]; then
		mkdir -v "${subfolder}" && chmod 775 "${subfolder}" && chown "${folder_user}:${folder_group}" "${subfolder}"
	fi
	if [[ ! -d ${temporary} ]]; then
		mkdir -v "${temporary}" && chmod 775 "${temporary}" && chown "${folder_user}:${folder_group}" "${temporary}"
	fi
	cd "${temporary}" || exit
	if [[ ! -f ${archive} ]]; then
		touch "${archive}" && chmod 664 "${archive}" && chown "${folder_user}:${folder_group}" "${archive}"
	fi
	if [[ -f "${subfolder}/${channel}.tar.zst" ]]; then
		if [[ ${channel} == "subscriptions" ]]; then
			find "${subfolder}" -iname "*.tar.zst" | while read -r c; do tar -xvp -I zstd -f "${c}"; done
		else
			tar -xvp -I zstd -f "${subfolder}/${channel}.tar.zst"
		fi
	fi
	#	if [[ -f "${subfolder}/${channel}.tar.zst" ]]; then
	#		tar -xvp -I zstd -f "${subfolder}/${channel}.tar.zst"
	#		if [[ ${channel} == "subscriptions" ]]; then
	#			tar -xvp -I zstd -f "${subfolder}/WL.tar.zst"
	#		fi
	#	fi
	#Fix permissions after extraction, in case the script was run as root
	find "${temporary}" -type f -exec chmod 664 {} \;
	find "${temporary}" -type f -exec chown "${folder_user}:${folder_group}" {} \;
	url="https://www.youtube.com/@${channel}"
	#Via https://github.com/yt-dlp/yt-dlp/issues/13573#issuecomment-3020152141
	full_url=$("${ytdl}" -I0 --print "playlist:https://www.youtube.com/playlist?list=UU%(channel_id.2:)s" "${url}")
	if [[ ${channel} == "subscriptions" ]]; then
		url="https://www.youtube.com/feed/subscriptions"
		full_url="${url}"
	elif [[ ${channel} == "WL" ]]; then
		url="https://www.youtube.com/playlist?list=WL"
		full_url="${url}"
	fi
	if [[ ${channel} != "WL" ]]; then
		#Channels need to manually check for each of videos, shorts, and streams. This does not apply for the Watch Later list.
		for section_url in "${url}/videos" "${url}/shorts" "${url}/streams"; do
			if [[ ${section_url} == "${url}/videos" ]]; then
				full_url=$(curl -s "${url}" | tr -d "\n\r" 2>/dev/null | xmlstarlet fo -R -n -H 2>/dev/null | xmlstarlet sel -t -v "/html" -n 2>/dev/null | grep "/channel/UC" | sed -e "s/var .* = //g" -e "s/\};/\}/g" -e "s/channel\/UC/playlist\?list=UU/g" | jq -r ".metadata .channelMetadataRenderer .channelUrl" 2>/dev/null)
				if [[ -z ${full_url} ]]; then
					full_url="${url}"
				fi
			else
				full_url="${section_url}"
			fi
			echo "${section_url} = ${full_url}"
			#TODO: test if section exists
			#test=$(curl -s -L -I -m 30 -X HEAD "${full_url}"
			if [[ ${channel} == "subscriptions" || -f ${cookies} ]]; then
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
				"${ytdl}" "${full_url}" \
					--cookies "${cookies}" \
					--js-runtimes deno:"${deno}" \
					--remote-components ejs:npm \
					--skip-download --download-archive "${archive}" \
					--dateafter "${breaktime}" \
					--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
					--max-downloads 10000 \
					--break-on-reject --lazy-playlist --write-info-json \
					--sleep-requests "${sleeptime}" \
					--parse-metadata "video::(?P<formats>)" \
					--parse-metadata "video::(?P<thumbnails>)" \
					--parse-metadata "video::(?P<subtitles>)" \
					--parse-metadata "video::(?P<automatic_captions>)" \
					--parse-metadata "video::(?P<chapters>)" \
					--parse-metadata "video::(?P<heatmap>)" \
					--parse-metadata "video::(?P<tags>)" \
					--parse-metadata "video::(?P<categories>)"
			else
				"${ytdl}" "${full_url}" \
					--js-runtimes deno:"${deno}" \
					--remote-components ejs:npm \
					--skip-download --download-archive "${archive}" \
					--dateafter "${breaktime}" \
					--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
					--max-downloads 10000 \
					--break-on-reject --lazy-playlist --write-info-json \
					--sleep-requests "${sleeptime}" \
					--parse-metadata "video::(?P<formats>)" \
					--parse-metadata "video::(?P<thumbnails>)" \
					--parse-metadata "video::(?P<subtitles>)" \
					--parse-metadata "video::(?P<automatic_captions>)" \
					--parse-metadata "video::(?P<chapters>)" \
					--parse-metadata "video::(?P<heatmap>)" \
					--parse-metadata "video::(?P<tags>)" \
					--parse-metadata "video::(?P<categories>)"
			fi
		done
	else
		if [[ -f ${cookies} && ${channel} == "WL" ]]; then
			"${ytdl}" "${full_url}" \
				--js-runtimes deno:"${deno}" \
				--remote-components ejs:npm \
				--cookies "${cookies}" \
				--skip-download --download-archive "${archive}" \
				--dateafter "${breaktime}" \
				--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
				--break-on-reject --lazy-playlist --write-info-json \
				--sleep-requests "${sleeptime}" \
				--parse-metadata "video::(?P<formats>)" \
				--parse-metadata "video::(?P<thumbnails>)" \
				--parse-metadata "video::(?P<subtitles>)" \
				--parse-metadata "video::(?P<automatic_captions>)" \
				--parse-metadata "video::(?P<chapters>)" \
				--parse-metadata "video::(?P<heatmap>)" \
				--parse-metadata "video::(?P<tags>)" \
				--parse-metadata "video::(?P<categories>)"
		fi
	fi
	if [[ ${enablecsv} == 1 ]]; then
		if [[ -f ${tmpcsv} ]]; then
			rm -rf "${tmpcsv}"
		fi
		touch "${tmpcsv}"
	fi
	if [[ ${enabledb} == 1 ]]; then
		if [[ -f ${sortcsv} ]]; then
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
			if [[ ${channel} != "subscriptions" && ${channel} != "WL" && -f ${x} && $(jq -rc ".uploader_id" "${x}") != "@${channel}" ]]; then
				echo "${count}/${total} ${x} not uploaded from ${channel}, removing..." && rm "${x}"
			fi
			if [[ ${breaktime} =~ ^[0-9]+$ && -f ${x} ]]; then
				file_timestamp=$(jq -rc '.timestamp' "${x}")
				if [[ ${breaktime_timestamp} -ge ${file_timestamp} ]]; then
					echo "${count}/${total} ${x} uploaded before ${breaktime}, removing..." && rm "${x}"
				fi
			fi
			#if [[ -f ${x} && -f ${diff_file} && (${channel} == "subscriptions" || ${channel} == "WL") ]]; then
			if [[ ${channel} == "subscriptions" && -f ${x} && -f ${diff_file} ]]; then
				channel_id=$(jq -rc ".channel_id" "${x}")
				if [[ -f ${subscriptions_old} ]]; then
					while read -r line; do
						#if [[ ${line} == "${channel_id}" && -f ${x} ]]; then
						if [[ ${line} == "${channel_id}" ]]; then
							unsubscribed_channel=$(grep "${line}" "${subscriptions_old}" | cut -d ',' -f3-)
							echo "${count}/${total} ${x} is from unsubscribed channel ${unsubscribed_channel}, removing..."
							touch "${subfolder}/${channel}-remove.csv"
							jq -c '[.upload_date, .timestamp, .duration, .uploader , .title, .webpage_url, .was_live]' "${x}" | while read -r i; do
								#echo "${i}" | sed -e "s/^\[//g" -e "s/\]$//g" -e 's/\\"/＂/g' >>"${temporary}/${channel}-remove.csv"
								echo "${i}" | sed -e "s/^\[//g" -e "s/\]$//g" -e 's/\\"/＂/g' | tee -a "${temporary}/${channel}-remove.csv"
							done
							sort "${temporary}/${channel}-remove.txt" | uniq >"${subfolder}/${channel}-remove.csv"
							rm "${temporary}/${channel}-remove.txt"
							rm "${x}"
						fi
					done <"${diff_file}"
				fi
			fi
			if [[ -f ${x} ]]; then
				jq '.formats="" | .automatic_captions="" | .subtitles="" | .thumbnails="" | .tags="" | .chapters="" | .heatmap="" | .categories=""' "${x}" >"${x}.tmp" && mv "${x}.tmp" "${x}"
				echo "youtube $(jq -cr '.id' "${x}")" >>"${temporary}/${channel}.txt"
				if [[ ${enablecsv} == "1" ]]; then
					jq -c '[.upload_date, .timestamp, .duration, .uploader , .title, .webpage_url, .was_live]' "${x}" | while read -r i; do
						echo "${i}" | sed -e "s/^\[//g" -e "s/\]$//g" -e 's/\\"/＂/g' >>"${tmpcsv}"
					done
				fi
				if [[ ${enabledb} == "1" ]]; then
					jq -c '[.upload_date, .timestamp]' "${x}" | while read -r i; do
						echo "${i},${x##*/}" | sed -e "s/^\[//g" -e "s/\],/,/g" -e 's/\\"/＂/g' >>"${sortcsv}"
					done
				fi
				echo "${count}/${total} ${x}"
			fi
		) &
		if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; then
			wait -n
		fi

	done
	wait
	sleep 1
	if [[ ${enabledb} == "1" ]]; then
		sort "${sortcsv}" | uniq >"${temporary}/${channel}-sort-ordered.csv"
		if [[ -f "${temporary}/${channel}.db" ]]; then
			rm "${temporary}/${channel}.db"
		fi
		if [[ ${channel} == "subscriptions" ]]; then
			echo '{"playlistName":"1. Subscriptions","protected":false,"description":"Videos from subscriptions","videos":[' >"${temporary}/${channel}.db"
		elif [[ ${channel} == "WL" ]]; then
			echo '{"playlistName":"Watch Later","protected":false,"description":"Videos to watch later","videos":[' >"${temporary}/${channel}.db"
		else
			echo "{\"playlistName\":\"${channel}\",\"protected\":false,\"description\":\"Videos from ${channel} to watch later\",\"videos\":[" >"${temporary}/${channel}.db"
		fi
		count=0
		total=$(wc -l <"${temporary}/${channel}-sort-ordered.csv")
		while read -r line; do
			count=$((count + 1))
			file=$(echo "${line}" | cut -d ',' -f3-)
			if [[ -f ${file} ]]; then
				if [[ $(jq -r ".timestamp" "${temporary}/${file}") != "null" ]]; then
					jq -c "{\"videoId\": .id, \"title\": .title, \"author\": .uploader, \"authorId\": .channel_id, \"lengthSeconds\": .duration, \"published\": ( .timestamp * 1000 ), \"timeAdded\": $(date +%s)$(date +%N | cut -c-3), \"playlistItemId\": \"$(uuidgen)\", \"type\": .media_type}" "${temporary}/${file}" >>"${temporary}/${channel}.db"
					echo "," >>"${temporary}/${channel}.db"
					echo "${count}/${total} ${file}"
				else
					#TODO: Process the playlist files
					rm "${temporary}/${file}"
				fi
			fi
		done <"${temporary}/${channel}-sort-ordered.csv"
		echo "],\"_id\":\"${channel}$(date +%s)\",\"createdAt\":$(date +%s),\"lastUpdatedAt\":$(date +%s)}" >>"${temporary}/${channel}.db"
		rm "${json}"
		grep -v -e ":[ ]*null" "${temporary}/${channel}.db" | tr '\n' '\r' | sed -e "s/,\r[,\r]*/,\r/g" | sed -e "s/,\r\]/\]/g" -e "s/\[\r,/\[/g" | tr '\r' '\n' | jq -c . >"${json}" && rm "${temporary}/${channel}.db"
		rm "${temporary}/${channel}-sort-ordered.csv" "${sortcsv}"
	fi
	if [[ ${enablecsv} == "1" ]]; then
		sort "${tmpcsv}" | uniq >"${temporary}/${channel}-without-header.csv"
		echo '"Upload Date", "Timestamp", "Duration", "Uploader", "Title", "Webpage URL", "Livestream"' >"${temporary}/${channel}-tmp.csv"
		cat "${temporary}/${channel}-without-header.csv" >>"${temporary}/${channel}-tmp.csv"
		mv "${temporary}/${channel}-tmp.csv" "${csv}"
		rm "${temporary}/${channel}-without-header.csv"
		rm "${tmpcsv}"
		rm "${diff_file}"
	fi
	cd "${temporary}" || exit
	#Fix permissions before compression, in case the script was run as root
	find "${temporary}" -type f -exec chmod 664 {} \;
	find "${temporary}" -type f -exec chown "${folder_user}:${folder_group}" {} \;
	tar -cvp -I "zstd -T0 --fast" -f "${subfolder}/${channel}.tar.zst" -- *.info.json
	total=$(find "${temporary}" -type f -iname "*.info.json" | wc -l)
	sort "${temporary}/${channel}.txt" | uniq >"${archive}"
	rm -rf "${temporary}"
}

#Start of the script proper
starttime=$(date +'%s')
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd
if [[ -f ${loop_file} && ${override_loop} == "0" ]]; then
	while read -r channel_entry cutdate; do
		channel="${channel_entry}"
		breaktime="${cutdate}"
		#Allow for commented-out channels
		if [[ -n ${channel} && -n ${cutdate} && ${channel:0:1} != "#" ]]; then
			core_loop "${channel}" "${breaktime}" "${sleeptime}" "${enabledb}" "${enablecsv}"
		fi
	done <"${loop_file}"
else
	core_loop "${channel}" "${breaktime}" "${sleeptime}" "${enabledb}" "${enablecsv}"
fi

if [[ -f ${loop_file} && ${override_loop} == "0" ]]; then
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd
	if [[ ${enabledb} -eq "1" ]]; then
		cd ./subscriptions || exit
		if [[ -f ${final} ]]; then
			rm -rf "${final}"
		fi
		if [[ ! -f ${final} ]]; then
			touch "${final}"
		fi
		#Concatenate all playlists
		#TODO: properly add "Favorites" list
		find . -iname "*.db" | while read -r i; do
			cat "${i}" >>"${final}"
			#They are not separated by a comma, curiously enough
		done
	fi
fi

#Scripts used specifically for my web server
if [[ $(uname -n) == "azkware" ]]; then
	#Used to scan my files in my Nextcloud folder
	../nextcloud-files-scan.sh "Document/Scripts"
	#Deduplicate files on my Nextcloud versions
	clearfolder="/home/yunohost.app/nextcloud/data/csolisr/files_versions/Multimedia/Document/Scripts"
	mapfile -t list < <(sudo find "${clearfolder}" -iname "*.v*" | sed -e "s/.*\///g" -e "s/\.v.*//g" | sort | uniq)
	for i in "${list[@]}"; do
		newest_name=""
		newest_date=0
		while read -r j; do
			current_date=$(sudo stat -c%Y "${j}")
			if [[ ${current_date} -gt ${newest_date} ]]; then
				newest_name="${j}"
				newest_date="${current_date}"
			fi
		done < <(sudo find "${clearfolder}" -iname "${i}*")
		echo "Newest:"
		sudo find "${clearfolder}" -ipath "${newest_name}"
		echo "Others:"
		sudo find "${clearfolder}" -not -ipath "${newest_name}" -and -iname "${i}*" -delete -print
		echo "---"
	done
fi

endtime=$(date +'%s')
elapsedtime=$((endtime - starttime))
elapsedtimehuman=$(date -d@"${elapsedtime}" -u +%Hh\ %Mm\ %Ss)
echo "Time elapsed = ${elapsedtimehuman}"
