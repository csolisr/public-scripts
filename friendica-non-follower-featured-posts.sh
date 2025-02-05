#!/bin/bash
ca=100
camax=0
while [[ ${ca} -gt 0 ]]; do
	ca=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`)) and \`command\` = \"UpdateContact\" limit ${ca}; select row_count();")
	camax=$((camax + ca))
	printf "\rUpdateContact\t\t%s\r" "${camax}"
done
printf "\rUpdateContact\t\t%s\n\r" "${camax}"
#echo "UpdateContact      $camax"

cb=100
cbmax=0
while [[ ${cb} -gt 0 ]]; do
	cb=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(regexp_replace(\`parameter\`, '\\\[', ''), '\\\]', '') not in (select \`id\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`)) and \`command\` = \"ContactDiscovery\" limit ${cb}; select row_count();")
	cbmax=$((cbmax + cb))
	printf "\rContactDiscovery\t%s\r" "${cbmax}"
done
printf "\rContactDiscovery\t%s\n\r" "${cbmax}"
#echo "ContactDiscovery   $cbmax"

cc=100
ccmax=0
while [[ ${cc} -gt 0 ]]; do
	cc=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`)) and \`command\` = \"FetchFeaturedPosts\" limit ${cc}; select row_count();")
	ccmax=$((ccmax + cc))
	printf "\rFetchFeaturedPosts\t%s\r" "${ccmax}"

done
printf "\rFetchFeaturedPosts\t%s\n\r" "${ccmax}"
#echo "FetchFeaturedPosts $ccmax"

cd=100
cdmax=0
while [[ ${cd} -gt 0 ]]; do
	cd=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where regexp_replace(substring_index(substring_index(\`parameter\`, '\\\"', -2), '\\\"', 1), '\\\\\\\\', '') not in (select \`url\` from \`contact\` where \`id\` in (select \`contact-id\` from \`group_member\`)) and \`command\` = \"UpdateGServer\" limit ${cd}; select row_count();")
	cdmax=$((cdmax + cd))
	printf "\rUpdateGServer\t\t%s\r" "${cdmax}"
done
printf "\rUpdateGServer\t\t%s\n\r" "${cdmax}"
#echo "UpdateGServer      $cdmax"

ce=100
cemax=0
while [[ ${ce} -gt 0 ]]; do
	ce=$(sudo mariadb friendica -B -N -q -e "delete from workerqueue where command=\"ProcessQueue\" and pid=0 and done=0 limit ${ce}; select row_count();")
	cemax=$((cemax + ce))
	printf "\rProcessQueue\t\t%s\r" "${cemax}"
done
printf "\rProcessQueue\t\t%s\n\r" "${cemax}"
#echo "ProcessQueue       $cemax"
