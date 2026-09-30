#!/bin/bash
learn_ham=${1:-"0"}
per_user=0
rspamd_process="localhost:11334"
rspamd_settings="/etc/rspamd"
mail_folder="/var/mail"
password=""
grep -Rhe '^#*password.*=.*' "${rspamd_settings}" | sed -e 's|password *= *||g' -e 's|"||g' | while read -r p; do
	password="${p}"
done
if grep -qRe '^#*per_user *= *true' "${rspamd_settings}" ; then
	per_user=1
fi
find "${mail_folder}" -mindepth 1 -maxdepth 1 -type d | sed -e "s|${mail_folder}||g" | while read -r u; do
	find "${mail_folder}/${u}" -iname "cur" | while read -r d; do
		grep -Rle 'X-Spam: Yes' "${d}" | while read -r i; do
			if [[ ${per_user} -gt 0 ]]; then
				rspamc -h "${rspamd_process}" -P "${password}" -d "${u}" learn_spam "${i}" -v #&>/dev/null
			else
				rspamc -h "${rspamd_process}" -P "${password}" learn_spam "${i}" -v #&>/dev/null
			fi
		done
		if [[ ${learn_ham} -gt 0 ]]; then
			grep -Rlve 'X-Spam: Yes' "${d}" | while read -r j; do
				if [[ ${per_user} -gt 0 ]]; then
					rspamc -h "${rspamd_process}" -P "${password}" -d "${u}" learn_ham "${j}" -v #&>/dev/null
				else
					rspamc -h "${rspamd_process}" -P "${password}" learn_ham "${j}" -v #&>/dev/null
				fi
			done
		fi
	done
done
