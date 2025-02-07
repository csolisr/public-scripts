#!/bin/bash
IFS="
"
#Set your parameters here
folder=/var/www/friendica
storagefolder=storage

loop_1() {
	t=$(file "${p}")
	if [[ "${t}" =~ JPEG ]]; then
		nice -n 10 jpegoptim -m 76 "${p}" #&> /dev/null
	elif [[ "${t}" =~ GIF ]]; then
		nice -n 10 gifsicle --batch -O3 --lossy=80 --colors=255 "${p}" #&> /dev/null
		#Specific compression for large GIF files
		while [[ $(stat -c%s "${p}" || 0) -ge 512000 ]]; do
			nice -n 10 gifsicle "${p}" $(seq -f "#%g" 0 2 99) -O3 --lossy=80 --colors=255 -o "${p}" #&> /dev/null
		done
	elif [[ "${t}" =~ PNG ]]; then
		nice -n 10 oxipng -o max "${p}" #&> /dev/null
	elif [[ "${p}" =~ Web/P ]]; then
		#If file is not animated
		if grep -v -q -e "ANIM" -e "ANMF" "${p}"; then
			nice -n 10 cwebp -mt -af -quiet "${p}" -o /tmp/temp.webp #&> /dev/null
			if [[ -f /tmp/temp.webp ]]; then
				size_new=$(stat -c%s "/tmp/temp.webp" || 0)
				size_original=$(stat -c%s "${p}")
				if [[ "${size_original}" -gt "${size_new}" ]]; then
					mv /tmp/temp.webp "${p}" #&> /dev/null
				else
					rm /tmp/temp.webp #&> /dev/null
				fi
			fi
		fi
	fi
}

find "${folder}/${storagefolder}" -depth -mindepth 2 -type f -size +50k -not -iname "index.html" | (
	while read -r p; do
		loop_1 "${p}" &
		until [[ $(jobs -r -p | wc -l) -lt $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; do
			wait -n
		done
	done
)
wait
