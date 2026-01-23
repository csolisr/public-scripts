#!/bin/bash
IFS="
"
#Set your parameters here
#Name of the database
db=friendica
#User of the database
user=root
#Folder with the storage files to check
storagefolder=/var/www/friendica/storage
#The folder storage name, with slashes escaped to work through sed
folderescaped=${storagefolder////\\/}
target_size=${1:-100}
target_time=${2:-8}

loop_1() {
	ks=$(echo "${p}" | sed -e "s/${folderescaped}//g" -e "s/\///g")
	e=$(sudo -u "${user}" mariadb "${db}" -N -B -q -e "select \`backend-ref\` from photo where \`backend-ref\` = '${ks}'")
	#If the file was not found in the database, but still exists in the filesystem, delete it
	if [[ -z ${e} && -f ${p} ]]; then
		sudo rm -rfv "${p}" #&> /dev/null
	else
		t=$(file "${p}")
		if [[ ${t} =~ JPEG ]]; then
			nice -n 10 jpegoptim -m 76 "${p}" #&> /dev/null
		elif [[ ${t} =~ GIF ]]; then
			nice -n 10 gifsicle --batch -O3 --lossy=80 --colors=255 "${p}" #&> /dev/null
			#Specific compression for large GIF files
			while [[ $(stat -c%s "${p}" || 0) -ge 512000 ]]; do
				frameamount=$(($(exiftool -b -FrameCount "${p}" || 1) - 1))
				nice -n 10 gifsicle "${p}" $(seq -f "#%g" 0 2 "${frameamount}") -O3 --lossy=80 --colors=255 -o "${p}" #&> /dev/null
			done
		elif [[ ${t} =~ PNG ]]; then
			nice -n 10 oxipng -o max "${p}" #&> /dev/null
		elif [[ ${t} =~ Web/P ]]; then
			#If file is not animated
			if [[ -f ${p} ]]; then
				if grep -q -a -l -e "ANIM" -e "ANMF" "${p}"; then
					tmppic="/tmp/temp_$(date +%s).webp"
					nice -n 10 cwebp -mt -af -quiet "${p}" -o "${tmppic}" #&> /dev/null
					if [[ -f ${tmppic} ]]; then
						size_new=$(stat -c%s "${tmppic}" 2>/dev/null || echo 0)
						size_original=$(stat -c%s "${p}" 2>/dev/null || echo 0)
						if [[ ${size_original} -gt ${size_new} ]]; then
							mv -v "${tmppic}" "${p}" #&> /dev/null
						else
							rm -v "${tmppic}" #&> /dev/null
						fi
					fi
				fi
			fi
		fi
	fi
	printf "\r%s/%s %s\n\r" "${count}" "${total}" "${p}" #&> /dev/null
}

#Generate an index to make searches faster
echo "Generating photo index..."                                                                  #&> /dev/null
sudo mariadb "${db}" -e 'alter table photo add index if not exists backend_index (`backend-ref`)' #&> /dev/null
echo "Generating list of files..."                                                                #&> /dev/null
total=$(find "${storagefolder}" -depth -mindepth 2 -type f -size +"${target_size}"k -mtime -"${target_time}" -not -iname "index.html" | wc -l)
count=0
while read -r p; do
	count=$((count + 1))
	loop_1 "${p}" "${count}" "${total}" &
	until [[ $(jobs -r -p | wc -l) -lt $(($(getconf _NPROCESSORS_ONLN) / 2)) ]]; do
		wait -n
	done
	#done < <(find "${storagefolder}" -depth -mindepth 2 -type f -not -iname "index.html")
done < <(find "${storagefolder}" -depth -mindepth 2 -type f -size +"${target_size}"k -mtime -"${target_time}" -not -iname "index.html")
wait
printf "\r\n" #&> /dev/null
#Drop the index in the end to save storage
sudo mariadb "${db}" -e "alter table photo drop index backend_index" #&> /dev/null
