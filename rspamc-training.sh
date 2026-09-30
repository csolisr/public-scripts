#!/bin/bash
learn_ham=${1:-"0"}
per_user=0
location="localhost:11334"
if grep -qRe '^#*per_user *= *true' /etc/rspamd ; then
	per_user=1
fi
find /var/mail -mindepth 1 -maxdepth 1 -type d | sed -e 's|/var/mail/||g' | while read -r u; do
	find "/var/mail/${u}" -iname "cur" | while read -r d; do
		grep -Rle 'X-Spam: Yes' "${d}" | while read -r i; do
			if [[ ${per_user} -gt 0 ]]; then
				rspamc -h "${location}" -P q1 -d "${u}" learn_spam "${i}" -v #&>/dev/null
			else
				rspamc -h "${location}" -P q1 learn_spam "${i}" -v #&>/dev/null
			fi
		done
		if [[ ${learn_ham} -gt 0 ]]; then
			grep -Rlve 'X-Spam: Yes' "${d}" | while read -r j; do
				if [[ ${per_user} -gt 0 ]]; then
					rspamc -h "${location}" -P q1 -d "${u}" learn_ham "${j}" -v #&>/dev/null
				else
					rspamc -h "${location}" -P q1 learn_ham "${j}" -v #&>/dev/null
				fi
			done
		fi
	done
done
