#!/bin/bash
IFS="
"
#Set your parameters here
site=friendica.example.net
user=friendica
group=www-data
fileperm=660
folderperm=770
folder=/var/www/friendica
folderescaped=${folder////\\/}
tmpfile=/tmp/friendica-fix-avatar-permissions.txt
avatarfolder=avatar

loop_1() {
	if [[ "${p}" =~ .jpeg || "${p}" =~ .jpg ]]; then
		nice -n 10 jpegoptim -m 76 "${p}" #&> /dev/null
	elif [[ "${p}" =~ .gif ]]; then
		nice -n 10 gifsicle --batch -O3 --lossy=80 --colors=255 "${p}" #&> /dev/null
		#Specific compression for large GIF files
		while [[ $(stat -c%s "${p}" 2>/dev/null || echo 0) -ge 512000 ]]; do
			frameamount=$(($(exiftool -b -FrameCount "${p}" || 1) - 1))
			nice -n 10 gifsicle "${p}" $(seq -f "#%g" 0 2 "${frameamount}") -O3 --lossy=80 --colors=255 -o "${p}" #&> /dev/null
		done
	elif [[ "${p}" =~ .png ]]; then
		nice -n 10 oxipng -o max "${p}" #&> /dev/null
	elif [[ "${p}" =~ .webp ]]; then
		#If file is not animated
		if [[ -f "${p}" ]]; then
			if grep -q -v -e "ANIM" -e "ANMF" "${p}"; then
				tmppic="/tmp/temp_$(date +%s).webp"
				nice -n 10 cwebp -mt -af -quiet "${p}" -o "${tmppic}" #&> /dev/null
				if [[ -f "${tmppic}" ]]; then
					size_new=$(stat -c%s "${tmppic}" 2>/dev/null || echo 0)
					size_original=$(stat -c%s "${p}" 2>/dev/null || echo 0)
					if [[ "${size_original}" -gt "${size_new}" ]]; then
						mv "${tmppic}" "${p}" #&> /dev/null
					else
						rm "${tmppic}" #&> /dev/null
					fi
				fi
			fi
		fi
	fi
}

cd "${folder}" || exit
if [[ ! -f "${tmpfile}" ]]; then
	sudo bin/console movetoavatarcache | sudo tee "${tmpfile}" #&> /dev/null
fi
grep -e "https://${site}/${avatarfolder}/" "${tmpfile}" | sed -e "s/.*${site}/${folderescaped}/g" -e "s/?ts=.*//g" | (
	while read -r i; do
		for p in "${i}" "${i//-320/-80}" "${i//-320/-48}"; do
			loop_1 "${p}" &
			if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
				wait -n
			fi
		done
	done
)
wait
rm "${tmpfile}"
/usr/bin/find "${folder}"/avatar -type d -empty -delete
/usr/bin/chmod "${folderperm}" "${folder}"/avatar
/usr/bin/chown -R "${user}":"${group}" "${folder}"/avatar
/usr/bin/find "${folder}"/avatar -depth -not -user "${user}" -or -not -group "${group}" -print0 | xargs -0 -r chown -v "${user}":"${group}"      #&> /dev/null
/usr/bin/find "${folder}"/avatar -depth -type d -and -not -type f -and -not -perm "${folderperm}" -print0 | xargs -0 -r chmod -v "${folderperm}" #&> /dev/null
/usr/bin/find "${folder}"/avatar -depth -type f -and -not -type d -and -not -perm "${fileperm}" -print0 | xargs -0 -r chmod -v "${fileperm}"     #&> /dev/null
