#!/bin/bash
IFS="
"
#media-optimize

folder=${1:-"."}

cd "${folder}" || exit

#jpeg
p_jpeg_loop() {
	quality=$(identify -verbose "${p}" | grep "Quality" | sed -e "s/.*Quality: //g")
	if [[ ! -s "${quality}" ]]; then
		quality="76"
	fi
	if [[ -n "${quality}" ]]; then
		keep_compressing_picture=1
		while [[ "${keep_compressing_picture}" -gt 0 ]]; do
			j=$(nice -n 15 jpegoptim -m "${quality}" "${p}")
			echo "${j}"
			jr=$(echo "${j}" | grep -e "[OK]" | grep -e ", optimized.")
			if [[ -z "${jr}" ]]; then
				keep_compressing_picture=0
			fi
		done
	fi
	#until grep -q -e "[OK]" -e ", skipped." <<<"${j}" || [[ -z "${j}" ]]; do
	#j=$(nice -n 15 jpegoptim -m "${quality}" "${p}")
	#echo "${j}" #&>/dev/null
	#done
}
while read -r p; do
	p_jpeg_loop "${p}" & #&>/dev/null &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -iname "*.jp*" \( -size +10k \))
wait

#gif
q_gif_loop() {
	nice -n 15 gifsicle --batch -O3 --lossy=80 --colors=255 "${q}" #&>/dev/null
}
while read -r q; do
	q_gif_loop "${q}" & #&>/dev/null &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -iname "*.gif" \( -size +100k \))
wait

q_gif_recompress_loop() {
	while [[ $(stat -c%s "${p}" || 0) -ge 512000 ]]; do
		frameamount=$(($(exiftool -b -FrameCount "${p}" || 1) - 1))
		nice -n 15 gifsicle "${p}" $(seq -f "#%g" 0 2 "${frameamount}") -O3 --lossy=80 --colors=255 -o "${p}" #&>/dev/null
	done
}
while read -r p; do
	q_gif_recompress_loop "${p}" &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -size +500k \( -iname "*-320.gif" -or -iname "*-80.gif" -or -iname "*-48.gif" \))
wait

#png
r_png_loop() {
	nice -n 15 oxipng -o max "${r}" #&>/dev/null
}
while read -r r; do
	r_png_loop "${r}" & #&>/dev/null &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -iname "*.png" -size +100k)
wait

#webp
s_webp_loop() {
	keep_compressing_picture=1
	while [[ "${keep_compressing_picture}" -gt 0 ]]; do
		#If file is not animated
		if [[ -f "${s}" ]]; then
			#if [[ -z $(grep -o -a -e "ANIM" -e "ANMF" "${s}") ]]; then
			if ! grep -q -o -a -e "ANIM" -e "ANMF" "${s}"; then
				cwebp -mt -af -quiet "${s}" -o /tmp/"${s##.*\/}"_temp.webp #&>/dev/null
				if [[ -f /tmp/"${s##.*\/}"_temp.webp ]]; then
					size_new=$(stat -c%s /tmp/"${s##.*\/}"_temp.webp || 0)
					size_original=$(stat -c%s "${s}" || 0)
					if [[ -n "${size_original}" && -n "${size_new}" && "${size_original}" -gt "${size_new}" && "${size_new}" -gt "0" ]]; then
						size_diff=$((size_original - size_new))
						echo "${s}: Saved ${size_diff} bytes" #&> /dev/null
						mv /tmp/"${s##.*\/}"_temp.webp "${s}" #&> /dev/null
					else
						echo "${s}: Minimum size is ${size_original} bytes" #&> /dev/null
						rm /tmp/"${s##.*\/}"_temp.webp                      #&> /dev/null
						keep_compressing_picture=0
					fi
				else
					keep_compressing_picture=0
				fi
			else
				keep_compressing_picture=0
			fi
		else
			keep_compressing_picture=0
		fi
	done
}
while read -r s; do
	s_webp_loop "${s}" & #&>/dev/null &
	if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]; then
		wait -n
	fi
done < <(find . -type f -iname "*.webp" \( -size +10k \))
wait

#Fix extensions
while read -r i; do
	if file -b "${i}" | grep -vq "PNG" | grep -vq "empty" | grep -vq "symbolic link" | grep -vq "directory" | grep -vq "text"; then
		if file -b "${i}" | grep -q "JPEG"; then
			mv "${i}" "${i%.*}".jpg
			#p="${i%.*}.jpg"
			#p_jpeg_loop "${p}"
			#jpegoptim -m76 "${i%.*}".jpg #&>/dev/null
		elif file "${i}" | grep -q "GIF"; then
			mv "${i}" "${i%.*}".gif
			#gifsicle --batch -O3 --lossy=80 --colors=255 "${i%.*}".gif #&>/dev/null
		elif file "${i}" | grep -q "Web/P"; then
			mv "${i}" "${i%.*}".webp
			#cwebp -mt -af -quiet $i
		fi
	fi
done < <(find . -iname "*.png")
while read -r j; do
	if file -b "${j}" | grep -v -q -e "JPEG" -e "empty" -e "symbolic link" -e "directory" -e "text"; then
		if file -b "${j}" | grep -q "PNG"; then
			mv "${j}" "${j%.*}".png
			#oxipng -o max "${j%.*}".png #&>/dev/null
		elif file -b "${j}" | grep -q "GIF"; then
			mv "${j}" "${j%.*}".gif
			#gifsicle --batch -O3 --lossy=80 --colors=255 "${j%.*}".gif #&>/dev/null
		elif file -b "${j}" | grep -q "Web/P"; then
			mv "${j}" "${j%.*}".webp
			#cwebp -mt -af -quiet $i
		fi
	fi
done < <(find . \( -iname "*.jpg" -or -iname "*.jpeg" \))
while read -r k; do
	if file -b "${k}" | grep -v -q -e "GIF" -e "empty" -e "symbolic link" -e "directory" -e "text"; then
		if file -b "${k}" | grep -q "JPEG"; then
			mv "${k}" "${k%.*}".jpg
			#jpegoptim -m76 "${k%.*}".jpg #&>/dev/null
		elif file -b "${k}" | grep -q "PNG"; then
			mv "${k}" "${k%.*}".png
			#oxipng -o max "${k%.*}".png #&>/dev/null
		elif file -b "${k}" | grep -q "Web/P"; then
			mv "${k}" "${k%.*}".webp
			#cwebp -mt -af -quiet $i
		fi
	fi
done < <(find . -iname "*.gif")
while read -r l; do
	if file -b "${l}" | grep -v -q -e "Web/P" -e "empty" -e "symbolic link" -e "directory" -e "text"; then
		if file -b "${l}" | grep -q "JPEG"; then
			mv "${l}" "${l%.*}".jpg
			#jpegoptim -m76 "${l%.*}".jpg #&>/dev/null
		elif file -b "${l}" | grep -q "PNG"; then
			mv "${l}" "${l%.*}".png
			#oxipng -o max "${l%.*}".png #&>/dev/null
		elif file -b "${l}" | grep -q "GIF"; then
			mv "${l}" "${l%.*}".gif
			#gifsicle --batch -O3 --lossy=80 --colors=255 "${l%.*}".gif #&>/dev/null
		fi
	fi
done < <(find . -iname "*.webp")
