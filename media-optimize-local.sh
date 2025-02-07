#!/bin/bash
IFS="
"
#media-optimize
while read -r p; do
	nice -n 15 jpegoptim -m 76 "${p}" #&>/dev/null &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -iname "*.jp*" \( -size +50k -and -mtime -8 \))
wait
while read -r q; do
	nice -n 15 gifsicle --batch -O3 --lossy=80 --colors=255 "${q}" #&>/dev/null &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -iname "*.gif" \( -size +500k -and -mtime -8 \))
wait
while read -r p; do
	(while [[ $(stat -c%s "${p}" || 0) -ge 512000 ]]; do
		frameamount=$(($(exiftool -b -FrameCount "${p}" || 1) - 1))
		nice -n 15 gifsicle "${p}" $(seq -f "#%g" 0 2 "${frameamount}") -O3 --lossy=80 --colors=255 -o "${p}" #&>/dev/null
	done) &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -size +500k \( -iname "*-320.gif" -or -iname "*-80.gif" -or -iname "*-48.gif" \))
wait
while read -r r; do
	nice -n 15 oxipng -o max "${r}" #&>/dev/null &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -iname "*.png" -size +500k)

wait
#compress-webp
while read -r s; do
	#If file is not animated
	if ! grep -v -q -e "ANIM" -e "ANMF" "${s}"; then
		cwebp -mt -af -quiet "${s}" -o /tmp/"${s##.*\/}"_temp.webp #&>/dev/null
		if [[ -f /tmp/"${s##.*\/}"_temp.webp ]]; then
			size_new=$(stat -c%s /tmp/"${s##.*\/}"_temp.webp || 0)
			size_original=$(stat -c%s "${s}" || 0)
			if [[ -n "${size_original}" && -n "${size_new}" && "${size_original}" -gt "${size_new}" ]]; then
				mv /tmp/"${s##.*\/}"_temp.webp "${s}"
			else
				rm /tmp/"${s##.*\/}"_temp.webp
			fi
		fi
	fi
done < <(find . -type f -iname "*.webp" \( -size +50k -and -mtime -8 \))
wait
while read -r i; do
	if file -b "${i}" | grep -vq "PNG" | grep -vq "empty" | grep -vq "symbolic link" | grep -vq "directory" | grep -vq "text"; then
		if file -b "${i}" | grep -q "JPEG"; then
			mv "${i}" "${i%.*}".jpg
			jpegoptim -m76 "${i%.*}".jpg #&>/dev/null
		elif file "${i}" | grep -q "GIF"; then
			mv "${i}" "${i%.*}".gif
			gifsicle --batch -O3 --lossy=80 --colors=255 "${i%.*}".gif #&>/dev/null
		elif file "${i}" | grep -q "Web/P"; then
			mv "${i}" "${i%.*}".webp
			#cwebp -mt -af -quiet $i
		fi
	fi
done < <(find . -iname "*.png" -mtime -8)
while read -r j; do
	if file -b "${j}" | grep -v -q -e "JPEG" -e "empty" -e "symbolic link" -e "directory" -e "text"; then
		if file -b "${j}" | grep -q "PNG"; then
			mv "${j}" "${j%.*}".png
			oxipng -o max "${j%.*}".png #&>/dev/null
		elif file -b "${j}" | grep -q "GIF"; then
			mv "${j}" "${j%.*}".gif
			gifsicle --batch -O3 --lossy=80 --colors=255 "${j%.*}".gif #&>/dev/null
		elif file -b "${j}" | grep -q "Web/P"; then
			mv "${j}" "${j%.*}".webp
			#If file is not animated
			if ! grep -v -q -e "ANIM" -e "ANMF" "${s}"; then
				cwebp -mt -af -quiet "${s}" -o /tmp/"${s##.*\/}"_temp.webp #&>/dev/null
				if [[ -f /tmp/"${s##.*\/}"_temp.webp ]]; then
					size_new=$(stat -c%s /tmp/"${s##.*\/}"_temp.webp || 0)
					size_original=$(stat -c%s "${s}" || 0)
					if [[ -n "${size_original}" && -n "${size_new}" && "${size_original}" -gt "${size_new}" ]]; then
						mv /tmp/"${s##.*\/}"_temp.webp "${s}"
					else
						rm /tmp/"${s##.*\/}"_temp.webp
					fi
				fi
			fi
		fi
	fi
done < <(find . -mtime -8 \( -iname "*.jpg" -and -iname "*.jpeg" \))
while read -r k; do
	if file -b "${k}" | grep -v -q -e "GIF" -e "empty" -e "symbolic link" -e "directory" -e "text"; then
		if file -b "${k}" | grep -q "JPEG"; then
			mv "${k}" "${k%.*}".jpg
			jpegoptim -m76 "${k%.*}".jpg #&>/dev/null
		elif file -b "${k}" | grep -q "PNG"; then
			mv "${k}" "${k%.*}".png
			oxipng -o max "${k%.*}".png #&>/dev/null
		elif file -b "${k}" | grep -q "Web/P"; then
			mv "${k}" "${k%.*}".webp
			#If file is not animated
			if ! grep -v -q -e "ANIM" -e "ANMF" "${s}"; then
				cwebp -mt -af -quiet "${s}" -o /tmp/"${s##.*\/}"_temp.webp #&>/dev/null
				if [[ -f /tmp/"${s##.*\/}"_temp.webp ]]; then
					size_new=$(stat -c%s /tmp/"${s##.*\/}"_temp.webp || 0)
					size_original=$(stat -c%s "${s}" || 0)
					if [[ -n "${size_original}" && -n "${size_new}" && "${size_original}" -gt "${size_new}" ]]; then
						mv /tmp/"${s##.*\/}"_temp.webp "${s}"
					else
						rm /tmp/"${s##.*\/}"_temp.webp
					fi
				fi
			fi
		fi
	fi
done < <(find . -iname "*.gif" -mtime -8)
while read -r l; do
	if file -b "${l}" | grep -v -q -e "Web/P" -e "empty" -e "symbolic link" -e "directory" -e "text"; then
		if file -b "${l}" | grep -q "JPEG"; then
			mv "${l}" "${l%.*}".jpg
			jpegoptim -m76 "${l%.*}".jpg #&>/dev/null
		elif file -b "${l}" | grep -q "PNG"; then
			mv "${l}" "${l%.*}".png
			oxipng -o max "${l%.*}".png #&>/dev/null
		elif file -b "${l}" | grep -q "GIF"; then
			mv "${l}" "${l%.*}".gif
			gifsicle --batch -O3 --lossy=80 --colors=255 "${l%.*}".gif #&>/dev/null
		fi
	fi
done < <(find . -iname "*.webp" -mtime -8)
