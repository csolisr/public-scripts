#!/bin/bash
IFS="
"
#media-optimize
find . -type f -iname "*.jp*" -size +50k | (
	while read p; do
		nice -n 15 jpegoptim -m 76 "${p}" &
		if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
			wait -n
		fi
	done
	wait
)
find . -type f -iname "*.gif" -size +500k | (
	while read q; do
		nice -n 15 gifsicle --batch -O3 --lossy=80 --colors=255 "${q}" &
		if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
			wait -n
		fi
	done
	wait
)
#Specific compression for large GIF files: halving the frame rate
find . -type f -size +500k -iname "*-320.gif" -or -iname "*-80.gif" -or -iname "*-48.gif" | (
	while read p; do
		while [[ $(stat -c%s "${p}" || 0) -ge 512000 ]]; do
			frameamount=$(($(exiftool -b -FrameCount "${p}" || 1) - 1))
			nice -n 15 gifsicle "${p}" $(seq -f "#%g" 0 2 "${frameamount}") -O3 --lossy=80 --colors=255 -o "${p}"
		done
	done
)
find . -type f -iname "*.png" -size +500k | (
	while read r; do
		nice -n 15 oxipng -o max "${r}" &
		if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
			wait -n
		fi
	done
	wait
)
#compress-webp
find . -type f -iname "*.webp" -size +50k | (
	while read s; do
		#If file is not animated
		if ! grep -v -q -e "ANIM" -e "ANMF" "${s}"; then
			cwebp -mt -af -quiet "${s}" -o /tmp/"${s##.*\/}"_temp.webp
			if [[ -f /tmp/"${s##.*\/}"_temp.webp ]]; then
				size_new=$(stat -c%s /tmp/"${s##.*\/}"_temp.webp || 0)
				size_original=$(stat -c%s "${s}" || 0)
				if [[ "${size_original}" -gt "${size_new}" ]]; then
					mv /tmp/"${s##.*\/}"_temp.webp "${s}"
				else
					rm /tmp/"${s##.*\/}"_temp.webp
				fi
			fi
		fi
	done
	wait
)
