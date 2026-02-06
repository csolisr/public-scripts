#!/bin/bash
nextcloud_folder_default="/var/www/nextcloud"
if [[ -d "/home/yunohost.app/nextcloud/data" ]]; then
	nextcloud_folder_default="/home/yunohost.app/nextcloud"
fi
target_size=${1:-"100"}
target_time=${2:-"2"}
nextcloud_folder=${3:-"${nextcloud_folder_default}"}
appdata_folder=$(find "${nextcloud_folder}/data" -maxdepth 1 -type d -iname "appdata_oc*" | head -n 1)
cache_folder="${appdata_folder}/bookmarks/cache"

compress_loop() {
	file_type=$(jq -r .contentType "${i}")
	#Extract file from JSON, recompress, reinsert into JSON
	case "${file_type}" in
	"image/jpeg")
		(printf "\n\r" &&
			echo "${count}/${total} JSON: ${i_trimmed} > ${file_type}" &&
			jq -r .data "${i}" | base64 -d -i >"/tmp/${i_trimmed}" &&
			jpegoptim -m 76 "/tmp/${i_trimmed}" &&
			base64 -w 0 "/tmp/${i_trimmed}" >"/tmp/${i_trimmed}.base64" &&
			jq -n --arg contentType "${file_type}" --rawfile data "/tmp/${i_trimmed}.base64" --arg lastCompression "$(date '+%s')" '{"contentType": $ARGS.named["contentType"], "data": $ARGS.named["data"], "lastCompression": $ARGS.named["lastCompression"]}' >"${i}") || rm -rfv "${i}"
		rm "/tmp/${i_trimmed}" "/tmp/${i_trimmed}.base64" &>/dev/null
		;;
	"image/png")
		(printf "\n\r" &&
			echo "${count}/${total} JSON: ${i_trimmed} > ${file_type}" &&
			jq -r .data "${i}" | base64 -d -i >"/tmp/${i_trimmed}" &&
			oxipng -o max "/tmp/${i_trimmed}" &&
			base64 -w 0 "/tmp/${i_trimmed}" >"/tmp/${i_trimmed}.base64" &&
			jq -n --arg contentType "${file_type}" --rawfile data "/tmp/${i_trimmed}.base64" --arg lastCompression "$(date '+%s')" '{"contentType": $ARGS.named["contentType"], "data": $ARGS.named["data"], "lastCompression": $ARGS.named["lastCompression"]}' >"${i}") || rm -rfv "${i}"
		rm "/tmp/${i_trimmed}" "/tmp/${i_trimmed}.base64" &>/dev/null
		;;
	"image/gif")
		(printf "\n\r" &&
			echo "${count}/${total} JSON: ${i_trimmed} > ${file_type}" &&
			jq -r .data "${i}" | base64 -d -i >"/tmp/${i_trimmed}" &&
			gifsicle -O3 "/tmp/${i_trimmed}" -o "/tmp/${i_trimmed}" &&
			base64 -w 0 "/tmp/${i_trimmed}" >"/tmp/${i_trimmed}.base64" &&
			jq -n --arg contentType "${file_type}" --rawfile data "/tmp/${i_trimmed}.base64" --arg lastCompression "$(date '+%s')" '{"contentType": $ARGS.named["contentType"], "data": $ARGS.named["data"], "lastCompression": $ARGS.named["lastCompression"]}' >"${i}") || rm -rfv "${i}"
		rm "/tmp/${i_trimmed}" "/tmp/${i_trimmed}.base64" &>/dev/null
		;;
	"image/webp")
		(printf "\n\r" &&
			echo "${count}/${total} JSON: ${i_trimmed} > ${file_type}" &&
			jq -r .data "${i}" | base64 -d -i >"/tmp/${i_trimmed}" &&
			cwebp -mt -af "/tmp/${i_trimmed}" -o "/tmp/${i_trimmed}" &&
			base64 -w 0 "/tmp/${i_trimmed}" >"/tmp/${i_trimmed}.base64" &&
			jq -n --arg contentType "${file_type}" --rawfile data "/tmp/${i_trimmed}.base64" --arg lastCompression "$(date '+%s')" '{"contentType": $ARGS.named["contentType"], "data": $ARGS.named["data"], "lastCompression": $ARGS.named["lastCompression"]}' >"${i}") || rm -rfv "${i}"
		rm "/tmp/${i_trimmed}" "/tmp/${i_trimmed}.base64" &>/dev/null
		;;
	"image/svg+xml")
		(printf "\n\r" &&
			echo "${count}/${total} JSON: ${i_trimmed} > ${file_type}" &&
			jq -r .data "${i}" | base64 -d -i >"/tmp/${i_trimmed}" &&
			scour -i "/tmp/${i_trimmed}" -o "/tmp/${i_trimmed}.tmp" --enable-viewboxing --enable-id-stripping --enable-comment-stripping --shorten-ids --indent=none && mv "/tmp/${i_trimmed}.tmp" "/tmp/${i_trimmed}" &&
			base64 -w 0 "/tmp/${i_trimmed}" >"/tmp/${i_trimmed}.base64" &&
			jq -n --arg contentType "${file_type}" --rawfile data "/tmp/${i_trimmed}.base64" --arg lastCompression "$(date '+%s')" '{"contentType": $ARGS.named["contentType"], "data": $ARGS.named["data"], "lastCompression": $ARGS.named["lastCompression"]}' >"${i}") || rm -rfv "${i}"
		rm "/tmp/${i_trimmed}" "/tmp/${i_trimmed}.base64" &>/dev/null
		;;
	*)
		:
		#printf "\n\r" && echo "${count}/${total} JSON: ${i_trimmed} > ${file_type}"
		;;
	esac
}

main_loop() {
	printf "\r%s/%s %s " "${count}" "${total}" "${i}" #&> /dev/null
	if [[ $(stat -c%s "${i}") -gt 4 ]]; then
		#i_trimmed=$(echo "${i}" | sed -e "s/.*-//g")
		i_trimmed="${i//*-/}"
		sed -e 's/\\//g' -e 's/\n//g' -e 's/\r//g' "${i}" >"/tmp/${i_trimmed}.tmp"
		if [[ -f "/tmp/${i_trimmed}.tmp" ]]; then
			if file "/tmp/${i_trimmed}.tmp" | grep -q "ASCII text"; then
				last_compression=$(jq -r .lastCompression "/tmp/${i_trimmed}.tmp")
				if [[ ${last_compression} == "null" ]]; then
					compress_loop #&> /dev/null
				fi
			elif file "/tmp/${i_trimmed}.tmp" | grep -q "JSON text"; then
				last_compression=$(jq -r .lastCompression "/tmp/${i_trimmed}.tmp")
				if [[ ${last_compression} == "null" ]]; then
					compress_loop #&> /dev/null
				#elif [[ "${last_compression}" =~ '^[0-9]+$' && "${last_compression}" -lt $(date -d '7 days ago' '+%s') ]]; then
				#compress_loop "${i}"
				#else
				#echo "${count}/${total} JSON: $i_trimmed"
				#file_type=$(jq -r .contentType "$i")
				#echo "${file_type}"
				fi
			else
				printf "\n\r"                     #&> /dev/null
				stat -c%s "/tmp/${i_trimmed}.tmp" #&> /dev/null
				file "/tmp/${i_trimmed}.tmp"      #&> /dev/null
			fi
			rm -rf "/tmp/${i_trimmed}.tmp" #&> /dev/null
		fi
	fi
}

count=0
total=$(find "${cache_folder}" -type f -mtime "-${target_time}" -size "+${target_size}" | wc -l)
find "${cache_folder}" -type f -mtime "-${target_time}" -size "+${target_size}" | while read -r i; do
	count=$((count + 1))
	main_loop "${i}" &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done
wait
printf "\n\r" #&> /dev/null
