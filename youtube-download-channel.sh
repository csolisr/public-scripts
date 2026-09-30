#!/bin/bash
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
final="${folder}/../FreeTube/playlists.db"
max_jobs=$(($(getconf _NPROCESSORS_ONLN) * 2))
#Default values:
override_loop="0"
loop_file="${subfolder}/loop-file.csv"
enabledb="1"
enablecsv="1"
enable_shorts="1"
enable_livestreams="1"
extract_all="0"
channel="subscriptions"
breaktime="today-1month"
sleeptime="0.1"
personal_folder="/cygdrive/d/Nextcloud/Multimedia/Document/Playnite"
track="1"
#Cf. https://stackoverflow.com/a/14203146
#Space to temporarily save the leftover positional arguments
pos_args=()
#Begin parsing items in the parameters stack
while [[ $# -gt 0 ]]; do
	case $1 in
	-h | --help)
		echo "-f [value] | --file [value]: Path to a file with the list of channels to download."
		echo "                             Use the format 'channelname 20260101', where the latter is the deadline for downloads."
		echo "                             Use 'WL' for the Watch Later list and 'subscriptions' for your subscriptions."
		echo "--cookies [value]: Path to a file with your YouTube cookies as extracted with 'yt-dlp --cookies-from-browser'."
		echo "--database [value]: Path to a file where you will save your final FreeTube playlist database."
		echo "--disable_db: Whether to disable exporting to FreeTube playlist database."
		echo "--disable_csv: Whether to disable exporting to a CSV file."
		echo "--disable_shorts: Whether to disable fetching shorts."
		echo "--disable_livestreams: Whether to disable fetching livestreams."
		echo "--extract_all: Whether to extract all other channels when downloading subscriptions."
		echo "-c [value] | --channel [value]: Channel you want to turn into a playlist. Leave blank to save your subscriptions (cookie file required)."
		echo "-b [value] | --breaktime [value]: Time limit for the download. Leave blank to save all videos from the last month."
		echo "-s [value] | --sleeptime [value]: Seconds between data requests. Decrease to make downloads faster, but your account may be temporarily blocked if you use a number too low."
		echo "--personal_folder [value]: Personal folder where yt_dlp is hosted - specifically for Windows over Cygwin/WSL. Substitute this as required."
		echo "--no_track: Whether to count the time used by the application's loops for statistical purposes."
		exit 0
		;;
	#Whether to override reading the loop file. Required if running individual channel fetches.
	-f | --file)
		override_loop="0"
		loop_file="$2"
		shift #for items with a value: first past the key (argument),
		shift #then past the value
		;;
	#Path to a file with your YouTube cookies, as extracted with `yt-dlp --cookies-from-browser`."
	--cookies)
		cookies="$2"
		shift
		shift
		;;
	#Path to a file where you will save your final FreeTube playlist database.
	--database)
		final="$2"
		shift
		shift
		;;
	#Whether to enable exporting to FreeTube playlist database (1=on by default, 0=off)
	--disable_db | --disable-db)
		enabledb="0"
		shift #for items without a value: only past the key (argument)
		;;
	#Whether to enable exporting to a CSV file (1=on by default, 0=off)
	--disable_csv | --disable-csv)
		enablecsv="0"
		shift
		;;
	#Whether to enable fetching shorts (1=on by default, 0=off)
	--disable_shorts | --disable-shorts)
		enable_shorts="0"
		shift
		;;
	#Whether to enable fetching livestreams (1=on by default, 0=off)
	--disable_livestreams | --disable-livestreams)
		enable_livestreams="0"
		shift
		;;
	#Whether to extract all other channels when downloading subscriptions (0=off by default, 1=on)
	--extract_all | --extract-all)
		extract_all="1"
		shift
		;;
	#Channel you want to turn into a playlist. Leave blank to save your subscriptions (cookie file required)
	-c | --channel)
		override_loop="1"
		channel="$2"
		shift
		shift
		;;
	#Time limit for the download. Leave blank to save all videos from the last month.
	-b | --breaktime)
		breaktime="$2"
		shift
		shift
		;;
	#Seconds between data requests. Decrease to make downloads faster, but your account may be temporarily blocked if you use a number too low.
	-s | --sleeptime)
		sleeptime="$2"
		shift
		shift
		;;
	#Personal folder where yt_dlp is hosted - specifically for Windows over Cygwin/WSL. Substitute this as required.
	--personal_folder | --personal-folder)
		personal_folder="$2"
		shift
		shift
		;;
	#Whether to count the time used by the application's loops for statistical purposes. (1=on by default, 0=off)
	--no_track | --no-track)
		track="0"
		shift
		;;
	#Any key-formatted arguments not understood cause an error
	--* | -*)
		echo "Unknown option: $1"
		exit 1
		;;
	#Any other positional arguments are stuffed here
	*)
		pos_args+=("$1")
		shift
		;;
	esac
done
#Restore the positional arguments
set -- "${pos_args[@]}"

inner_loop() {
	#TODO: Process playlist files here
	if [[ ${track} -eq 1 ]]; then
		mostinnerstarttime=$(date -u +%s%3N)
	fi
	if [[ ${enable_livestreams} -eq 0 ]]; then
		if [[ $(jq -rc '.is_live' "${x}") == "true" || $(jq -rc '.was_live' "${x}") == "true" || $(jq -rc '.media_type' "${x}") == "livestream" ]]; then
			echo "${count}/${total} ${x} was a livestream, removing..." && rm "${x}"
		fi
	fi
	if [[ ${enable_shorts} -eq 0 ]]; then
		if [[ $(jq -rc '.height' "${x}") -gt $(jq -rc '.height' "${x}") || $(jq -rc '.media_type' "${x}") == "short" ]]; then
			echo "${count}/${total} ${x} was a short, removing..." && rm "${x}"
		fi
	fi
	if [[ -f ${x} && ${breaktime} =~ ^[0-9]+$ ]]; then
		file_timestamp=$(jq -rc '.timestamp' "${x}")
		if [[ ${breaktime_timestamp} -ge ${file_timestamp} ]]; then
			echo "${count}/${total} ${x} uploaded before ${breaktime}, removing..." && rm "${x}"
		fi
	fi
	if [[ -f ${x} && ${channel} != "subscriptions" && ${channel} != "WL" && $(jq -rc ".uploader_id" "${x}") != "@${channel}" ]]; then
		echo "${count}/${total} ${x} not uploaded from ${channel}, removing..." && rm "${x}"
	fi
	if [[ -f ${x} && (${channel} == "subscriptions" || ${channel} == "WL") && -f ${diff_file} && -f ${subscriptions_old} ]]; then
		#TODO: Temporarily delete everything from non-subscribed channels (maybe with a parameter?)
		channel_id=$(jq -rc ".channel_id" "${x}")
		while read -r line; do
			if [[ ${line} == "${channel_id}" ]]; then
				unsubscribed_channel=$(tr -d '\r' <"${subscriptions_old}" | grep "${line}" | cut -d ',' -f3-)
				echo "${count}/${total} ${x} is from unsubscribed channel ${unsubscribed_channel}, removing..."
				touch "${subfolder}/${channel}-remove.csv"
				touch "${temporary}/${channel}-remove.csv"
				jq -c '[.upload_date, .timestamp, .duration, .uploader , .title, .webpage_url, .was_live]' "${x}" | while read -r i; do
					echo "${i}" | sed -e "s/^\[//g" -e "s/\]$//g" -e 's/\\"/＂/g' >>"${temporary}/${channel}-remove.csv"
				done
				rm "${x}"
			fi
		done <"${diff_file}"
	fi
	if [[ -f ${x} ]]; then
		if [[ $(stat -c%s "${x}") -gt 3000 ]]; then
			jq '.formats=""|.automatic_captions=""|.subtitles=""|.thumbnails=""|.tags=""|.chapters=""|.heatmap=""|.categories=""|.description=""|._format_sort_fields=""|.http_headers=""|.url=""|.manifest_url=""|._version=""' "${x}" >"${x}.tmp" && mv "${x}.tmp" "${x}"
		fi
		echo "youtube $(jq -cr '.id' "${x}")" >>"${temporary}/${channel}.txt"
		if [[ ${enablecsv} -eq 1 ]]; then
			jq -c '[.upload_date, .timestamp, .duration, .uploader , .title, .webpage_url, .was_live]' "${x}" | while read -r i; do
				echo "${i}" | sed -e "s/^\[//g" -e "s/\]$//g" -e 's/\\"/＂/g' >>"${tmpcsv}"
			done
		fi
		if [[ ${enabledb} -eq 1 ]]; then
			jq -c '[.upload_date, .timestamp]' "${x}" | while read -r i; do
				echo "${i},${x##*/}" | sed -e "s/^\[//g" -e "s/\],/,/g" -e 's/\\"/＂/g' >>"${sortcsv}"
			done
		fi
		echo "${count}/${total} ${x}"
	fi
	if [[ ${track} -eq 1 ]]; then
		mostinnerendtime=$(date -u +%s%3N)
		mostinnerelapsedtime=$((mostinnerendtime - mostinnerstarttime))
		echo "${count}/${total} Processing time: ${mostinnerelapsedtime}ms"
	fi
}

core_loop() {
	if [[ -f ${subscriptions_old} && -f ${subscriptions_new} ]]; then
		diff <(tr -d '\r' <"${subscriptions_old}" | sort | cut -d ',' -f2) <(tr -d '\r' <"${subscriptions_new}" | sort | cut -d ',' -f2) | grep "< " | sed -e "s/< //g" -e "s/http:\/\/www.youtube.com\/channel\///g" | sort | uniq >"${diff_file}"
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
	if [[ ${extract_all} -eq 0 ]]; then
		if [[ -f "${subfolder}/${channel}.tar.zst" ]]; then
			tar -xvp -I zstd -f "${subfolder}/${channel}.tar.zst"
			if [[ ${channel} == "subscriptions" ]]; then
				tar -xvp -I zstd -f "${subfolder}/WL.tar.zst"
			fi
		fi
	else
		if [[ -f "${subfolder}/${channel}.tar.zst" ]]; then
			if [[ ${channel} == "subscriptions" ]]; then
				find "${subfolder}" -iname "*.tar.zst" | while read -r c; do tar -xvp -I zstd -f "${c}"; done
			else
				tar -xvp -I zstd -f "${subfolder}/${channel}.tar.zst"
			fi
		fi
	fi
	#Fix permissions after extraction, in case the script was run as root
	find "${temporary}" -type f -and -not -perm 664 -exec chmod 664 {} \;
	find "${temporary}" -type f -and \( -not -user "${folder_user}" -or -not -group "${folder_group}" \) -exec chown "${folder_user}:${folder_group}" {} \;
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
		section_urls=()
		match_filters=""
		if [[ ${channel} != "subscriptions" ]]; then
			section_urls+=("${url}/videos")
		else
			section_urls+=("${url}")
		fi
		if [[ ${enable_shorts} -eq 1 ]]; then
			section_urls+=("${url}/shorts")
		else
			match_filters="height>width"
		fi
		if [[ ${enable_livestreams} -eq 1 ]]; then
			section_urls+=("${url}/livestreams")
		else
			if [[ ${enable_shorts} -eq 1 ]]; then
				match_filters="!is_live & !was_live"
			else
				match_filters="height>width & !is_live & !was_live"
			fi
		fi
		for section_url in "${section_urls[@]}"; do
			if [[ ${section_url} == "${url}/videos" ]]; then
				full_url=$(curl -s "${url}" | tr -d "\n\r" 2>/dev/null | xmlstarlet fo -R -n -H 2>/dev/null | xmlstarlet sel -t -v "/html" -n 2>/dev/null | grep "/channel/UC" | sed -e "s/var .* = //g" -e "s/\};/\}/g" -e "s/channel\/UC/playlist\?list=UU/g" | jq -r ".metadata .channelMetadataRenderer .channelUrl" 2>/dev/null | grep -ve '^null$' | tail -n 1)
				if [[ -z ${full_url} ]]; then
					full_url="${url}"
				fi
			else
				full_url="${section_url}"
			fi
			maxdownloads=10000
			if [[ ${section_url} == "${url}/shorts" ]]; then
				maxdownloads=200
			fi
			echo "${section_url} = ${full_url}"
			#Test if section exists
			test_raw=$(curl -s -L -I -m 30 -X HEAD "${full_url}")
			test=$(echo "${test_raw}" | grep -e "HTTP.* 200")
			if [[ -n ${test} ]]; then
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
					if [[ -n ${match_filters} ]]; then
						"${ytdl}" "${full_url}" \
							--cookies "${cookies}" \
							--js-runtimes deno:"${deno}" \
							--remote-components ejs:npm \
							--skip-download --download-archive "${archive}" \
							--no-write-playlist-metafiles \
							--dateafter "${breaktime}" \
							--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
							--max-downloads "${maxdownloads}" \
							--lazy-playlist --write-info-json \
							--sleep-requests "${sleeptime}" \
							--match-filters "${match_filters}" \
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
							--cookies "${cookies}" \
							--js-runtimes deno:"${deno}" \
							--remote-components ejs:npm \
							--skip-download --download-archive "${archive}" \
							--no-write-playlist-metafiles \
							--dateafter "${breaktime}" \
							--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
							--max-downloads "${maxdownloads}" \
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
				else
					if [[ -n ${match_filters} ]]; then
						"${ytdl}" "${full_url}" \
							--js-runtimes deno:"${deno}" \
							--remote-components ejs:npm \
							--skip-download --download-archive "${archive}" \
							--no-write-playlist-metafiles \
							--dateafter "${breaktime}" \
							--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
							--max-downloads "${maxdownloads}" \
							--lazy-playlist --write-info-json \
							--sleep-requests "${sleeptime}" \
							--match-filters "${match_filters}" \
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
							--no-write-playlist-metafiles \
							--dateafter "${breaktime}" \
							--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
							--max-downloads "${maxdownloads}" \
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
			else
				error_code=$(echo "${test_raw}" | grep -e "HTTP")
				echo "Error: ${error_code}"
			fi
		done
	else
		match_filters=""
		if [[ ${enable_shorts} -eq 0 ]]; then
			match_filters="height>width"
		fi
		if [[ ${enable_livestreams} -eq 0 ]]; then
			if [[ ${enable_shorts} -eq 0 ]]; then
				match_filters="height>width & !is_live & !was_live"
			else
				match_filters="!is_live & !was_live"
			fi
		fi
		maxdownloads=10000
		if [[ -f ${cookies} && ${channel} == "WL" ]]; then
			if [[ -n ${match_filters} ]]; then
				"${ytdl}" "${full_url}" \
					--cookies "${cookies}" \
					--js-runtimes deno:"${deno}" \
					--remote-components ejs:npm \
					--skip-download --download-archive "${archive}" \
					--no-write-playlist-metafiles \
					--dateafter "${breaktime}" \
					--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
					--max-downloads "${maxdownloads}" \
					--lazy-playlist --write-info-json \
					--sleep-requests "${sleeptime}" \
					--match-filters "${match_filters}" \
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
					--cookies "${cookies}" \
					--js-runtimes deno:"${deno}" \
					--remote-components ejs:npm \
					--skip-download --download-archive "${archive}" \
					--no-write-playlist-metafiles \
					--dateafter "${breaktime}" \
					--extractor-args "youtubetab:approximate_date" "youtubetab:skip=webpage" "youtube:player_skip=webpage,configs,js" "youtube:max_comments=0" \
					--max-downloads "${maxdownloads}" \
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
		if [[ ${track} -eq 1 ]]; then
			innerstarttime=$(date -u +%s%3N)
		fi
		count=$((count + 1))
		inner_loop &
		#Commented - this might place items in the wrong order due to parallelism.
		#if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		#wait -n
		#fi
		if [[ ${track} -eq 1 ]]; then
			job_start=$(jobs -r -p | wc -l)
			innersleeptime=$(date -u +%s%3N)
			total_sleeps=0
		fi
		while [[ $(jobs -r -p | wc -l) -ge ${max_jobs} ]]; do
			if [[ ${track} -eq 1 ]]; then
				total_sleeps=$((total_sleeps + 1))
			fi
			sleep "${sleeptime}"
		done
		if [[ ${track} -eq 1 ]]; then
			innerendtime=$(date -u +%s%3N)
			innerelapsedtime=$((innerendtime - innerstarttime))
			innersleepelapsedtime=$((innerendtime - innersleeptime))
			job_end=$(jobs -r -p | wc -l)
			echo "${count}/${total} wait for job ${job_start}>${job_end}/${max_jobs} : ${innerelapsedtime}ms / ${innersleepelapsedtime}ms (${total_sleeps})"
		fi
	done
	wait
	if [[ -f "${temporary}/${channel}-remove.csv" ]]; then
		sort "${temporary}/${channel}-remove.csv" | uniq >"${subfolder}/${channel}-remove.csv" && rm "${temporary}/${channel}-remove.csv"
	fi
	sleep 1
	if [[ ${enabledb} -eq 1 ]]; then
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
			if [[ ${track} -eq 1 ]]; then
				innerstarttime=$(date -u +%s%3N)
			fi
			count=$((count + 1))
			file=$(echo "${line}" | cut -d ',' -f3-)
			if [[ -f ${file} ]]; then
				if [[ $(jq -r ".timestamp" "${temporary}/${file}") != "null" ]]; then
					jq -c "{\"videoId\": .id, \"title\": .title, \"author\": .uploader, \"authorId\": .channel_id, \"lengthSeconds\": .duration, \"published\": ( .timestamp * 1000 ), \"timeAdded\": $(date +%s)$(date +%N | cut -c-3), \"playlistItemId\": \"$(cat /proc/sys/kernel/random/uuid || uuidgen)\", \"type\": .media_type}" "${temporary}/${file}" >>"${temporary}/${channel}.db"
					echo "," >>"${temporary}/${channel}.db"
					echo "${count}/${total} ${file}"
				else
					#TODO: Process the playlist files
					rm "${temporary}/${file}"
				fi
			fi
			if [[ ${track} -eq 1 ]]; then
				innerendtime=$(date -u +%s%3N)
				innerelapsedtime=$((innerendtime - innerstarttime))
				echo "${count}/${total} Processing time: ${innerelapsedtime}ms"
			fi
		done <"${temporary}/${channel}-sort-ordered.csv"
		echo "],\"_id\":\"${channel}$(date +%s)\",\"createdAt\":$(date +%s),\"lastUpdatedAt\":$(date +%s)}" >>"${temporary}/${channel}.db"
		rm "${json}"
		grep -v -e ":[ ]*null" "${temporary}/${channel}.db" | tr '\n' '\r' | sed -e "s/,\r[,\r]*/,\r/g" | sed -e "s/,\r\]/\]/g" -e "s/\[\r,/\[/g" | tr '\r' '\n' | jq -c . >"${json}" && rm "${temporary}/${channel}.db"
		rm "${temporary}/${channel}-sort-ordered.csv" "${sortcsv}"
	fi
	if [[ ${enablecsv} -eq 1 ]]; then
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
	find "${temporary}" -type f -and -not -perm 664 -exec chmod 664 {} \;
	find "${temporary}" -type f -and \( -not -user "${folder_user}" -or -not -group "${folder_group}" \) -exec chown "${folder_user}:${folder_group}" {} \;
	tar -cvp -I "zstd -T0 --fast" -f "${subfolder}/${channel}.tar.zst" -- *.info.json
	total=$(find "${temporary}" -type f -iname "*.info.json" | wc -l)
	sort "${temporary}/${channel}.txt" | uniq >"${archive}"
	rm -rf "${temporary}"
}

#Start of the script proper
if [[ ${track} -eq 1 ]]; then
	starttime=$(date +'%s')
fi
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd
echo "loop_file: ${loop_file}"
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
if [[ -f ${loop_file} && ${enabledb} == "1" && -n ${final} ]]; then
	cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd
	if [[ ${enabledb} -eq 1 ]]; then
		cd "${folder}/subscriptions" || exit
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
if [[ $(uname -n) == "azkware.net" ]]; then
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
if [[ ${track} -eq 1 ]]; then
	endtime=$(date +'%s')
	elapsedtime=$((endtime - starttime))
	elapsedtimehuman=$(date -d@"${elapsedtime}" -u +%Hh\ %Mm\ %Ss)
	echo "Time elapsed = ${elapsedtimehuman}"
fi
