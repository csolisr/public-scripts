#!/bin/bash
IFS="
"
dbengine=""
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
else
	exit
fi
intense_optimizations=${1:-"0"}
input_id=${2:-"1"}
#Set your parameters here
url=friendica.example.net
db=friendica
folder=/var/www/friendica
folderavatar=/var/www/friendica/avatar
folderescaped=${folder////\\/}
loop() {
	#Parse each file in folder
	ky=$(echo "${y}" | sed -e "s/${folderescaped}/https:\/\/${url}/g" -e "s/-[0-9]*\..*\$//g")
	f=$("${dbengine}" "${db}" -N -B -q -e "select photo from contact where photo like '${ky}%' limit 1")
	if [[ $? -eq 0 && -z ${f} && -f ${y} ]]; then
		yb="${y%%-48*}"
		yc="${yb%/*}"
		if [[ "${intense_optimizations}" -eq 1 ]]; then
			find "${yc}" -path "${yb}*" -exec rm -f {} \; &
		else
			find "${yc}" -path "${yb}*" -exec rm -rfv {} \; &
		fi
		if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 2)) ]]; then
			wait -n
		fi
	fi
	if [[ "${intense_optimizations}" -eq 0 ]]; then
		printf "\rFolder %s\tEntry %s  " "${n}" "${m}"
	fi
	return "${d}"
}

date
#Go to the Friendica installation
cd "${folderavatar}" || exit
indexlength=$((49 + ${#url}))
"${dbengine}" "${db}" -e "alter table contact add index if not exists photo_index (photo(${indexlength}))"
n=0
d=0
while read -r x; do
	n=$((n + 1))
	#If the directory still exists
	if [[ -d "${x}" && "${n}" -ge "${input_id}" ]]; then
		m=0
		while read -r y; do
			m=$((m + 1))
			loop "${x}" "${m}" "${n}" "${d}" "${y}" #&
		done < <(find "${x}" -type f \( -iname "*-48*" -or -iname "*-80*" -or -iname "*-320*" \) )
	fi
	if [[ "${intense_optimizations}" -eq 1 ]]; then
		printf "\rFolder %d\tDone     " "${n}"
	else
		printf "\r\nFolder %d done - %s\n" "${n}" "${x}"
	fi
done < <(find "${folderavatar}" -depth -mindepth 1 -maxdepth 1 -type d)
"${dbengine}" "${db}" -e "alter table contact drop index photo_index"
date
