#!/bin/bash
for i in ./*.sh; do
	shfmt -w "${i}"
	shellcheck -o all -e SC2312 -f diff "${i}" | patch -p1
	shellcheck -o all -e SC2312 "${i}"
	i_tmp="${i##./}"
	find /etc/cron.* -iname "${i_tmp%.sh}" | while read -r j; do
		echo "${j}"
		#diff <(sed -e "s/friendica.example.net/hub.azkware.net/g" -e "s/1\:-\"0\"/1\:-\"1\"/g" -e "s/#&>/\&\>/g" "${i}") "${j}"
		#sed -e "s/friendica.example.net/hub.azkware.net/g" -e "s/1\:-\"0\"/1\:-\"1\"/g" -e "s/#&>/\&\>/g" "${i}" | sudo tee "${j}" &>/dev/null
		diff <(sed -e "s/friendica.example.net/hub.azkware.net/g" -e "s/#&>/\&\>/g" "${i}") "${j}"
		sed -e "s/friendica.example.net/hub.azkware.net/g" -e "s/#&>/\&\>/g" "${i}" | sudo tee "${j}" &>/dev/null
	done
	find ../../Scripts -iname "${i_tmp}" | while read -r k; do
		echo "${k}"
		diff <(sed -e "s/friendica.example.net/hub.azkware.net/g" "${i}") "${k}"
		sed -e "s/friendica.example.net/hub.azkware.net/g" "${i}" | sudo tee "${k}" &>/dev/null
	done
done
