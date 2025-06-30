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
			frameamount=$(($(exiftool -b -FrameCount "${p}" || 1) - 1))
			nice -n 10 gifsicle "${p}" $(seq -f "#%g" 0 2 "${frameamount}") -O3 --lossy=80 --colors=255 -o "${p}" #&> /dev/null
		done
	elif [[ "${t}" =~ PNG ]]; then
		nice -n 10 oxipng -o max "${p}" #&> /dev/null
	elif [[ "${t}" =~ Web/P ]]; then
		#If file is not animated
		if [[ -f "${p}" ]]; then
			if grep -q -a -l -e "ANIM" -e "ANMF" "${p}"; then
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

find "${folder}/${storagefolder}" -depth -mindepth 2 -type f -size +50k -atime -8 -not -iname "index.html" | (
	while read -r p; do
		loop_1 "${p}" &
		until [[ $(jobs -r -p | wc -l) -lt $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; do
			wait -n
		done
	done
)
wait
