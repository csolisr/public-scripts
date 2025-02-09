#!/bin/bash
IFS="
"
#Set your parameters here
url=friendica.example.net
db=friendica
folder=/var/www/friendica
folderavatar=/var/www/friendica/avatar
loop() {
	#Parse each file in folder
	folderescaped=${folder////\\/}
	ky=$(echo "${y}" | sed -e "s/${folderescaped}/https:\/\/${url}/g" -e "s/-[0-9]*\..*\$//g")
	f=$(mariadb "${db}" -N -B -q -e "select photo from contact where photo like '${ky}%' limit 1")
	if [[ $? -eq 0 && -z ${f} && -f ${y} ]]; then
		rm -rvf "${y}" &
		if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; then
			wait -n
		fi

		d=$((d + 1))
	fi
	#printf "\rPhotos: %s\tFolder %s\tEntry %s   " "$d" "$n" "$m"
	printf "\rFolder %s\tEntry %s  " "${n}" "${m}"
	return "${d}"
}

date
#Go to the Friendica installation
cd "${folderavatar}" || exit
#indexlength=$((49 + ${#url}))
#mariadb "${db}" -e "alter table contact add index if not exists photo_index (photo(${indexlength}))"
n=0
d=0
while read -r x; do
	n=$((n + 1))
	#If the directory still exists
	if [[ -d "${x}" ]]; then
		m=0
		while read -r y; do
			m=$((m + 1))
			loop "${x}" "${m}" "${n}" "${d}" "${y}" &
			if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; then
				wait -n
			fi
		done < <(find "${x}" -type f)
	fi
done < <(find "${folderavatar}" -depth -mindepth 1 -maxdepth 1 -type d)
#mariadb "${db}" -e "alter table contact drop index photo_index"
date
