#!/bin/bash
#Insert your script credentials here.
credentials_file="./credentials.csv"
#Insert your file settings here.
settings_file="./settings.csv"
#Via https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
folder=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "${folder}" || exit
folder_user=$(stat -c "%U" "${folder}")
folder_group=$(stat -c "%G" "${folder}")
#Populate some values from our settings file
#Name of the server as output from `uname -n`.
serveruname="localhost"
#URL of the server you'll use for the Friendica scripts.
serverurl="friendica.example.net"
#Target for the cron folder.
cronfolder="/etc/cron.*"
#Target for the scripts folder.
scriptsfolder="../../Scripts"
if [[ -f "${settings_file}" ]]; then
	while read -r key value; do
		case "${key}" in
		"serveruname")
			serveruname="${value}"
			echo "serveruname=${serveruname}"
			;;
		"serverurl")
			serverurl="${value}"
			echo "serverurl=${serverurl}"
			;;
		"cronfolder")
			cronfolder="${value}"
			echo "cronfolder=${cronfolder}"
			;;
		"scriptsfolder")
			scriptsfolder="${value}"
			echo "scriptsfolder=${scriptsfolder}"
			;;
		*) ;;
		esac
	done <"${settings_file}"
else
	echo "You must first make a copy of the existing \"settings_default.csv\" file, edit it with your settings, then save it as \"settings.csv\" in this folder." && exit
fi
#Check each of our shell scripts in the folder
while read -r i; do
	#Trim the file to be Unix-compatible (using /tmp as a pivot folder)
	#Then, set the correct permissions on the files
	tr -d '\r' <"${i}" >"/tmp/${i}" && mv "/tmp/${i}" "${i}" && chmod 755 "${i}" && chown "${folder_user}:${folder_group}" "${i}"
	#`shfmt` is used to format the shell scripts
	shfmt -w "${i}"
	#`shellcheck` is used to find any issues with the shell scripts, and if possible, fix them (see first line)
	#We're skipping optional check SC2312 as we use command substitutions heavily,
	#and replacing some of the outputs for "true" or "false" in case of failure would break some logic.
	shellcheck -o all -e SC2312 -f diff "${i}" | patch -p1 "${i}"
	#This line shows any issues that could not be auto-fixed.
	shellcheck -o all -e SC2312 "${i}"
	#As the scripts have no file extension in our cron folder, we will use this truncated name for its subfolders.
	i_tmp="${i##./}"
	#Populate the corresponding file credentials for the ones in the credentials file.
	credential=""
	if [[ -f "${credentials_file}" ]]; then
		while read -r credential_key credential_value; do
			if [[ "${credential_key}" == "${i}" ]]; then
				credential="${credential_value}"
			fi
		done <"${credentials_file}"
	else
		echo "You must first make a copy of the existing \"credentials_default.csv\" file, edit it with your settings, then save it as \"credentials.csv\" in this folder." &&
			echo "Each credential needs to be generated using something like GetAuth and the \"read\" permission ( https://getauth.thms.uk/?scopes=read )." && exit
	fi
	#These changes apply to the cron folder.
	if [[ $(uname -n) == "${serveruname}" ]]; then
		while read -r j; do
			#Show the name of the target file
			echo "${j}"
			#Show the differences between the current target file and the modified file
			diff <(sed -e "s/friendica.example.net/${serverurl}/g" -e "s/#&>/\&\>/g" -e "s/\(token=\${.*:-\"\)[0-9a-f]*\"/\1${credential}\"/g" "${i}") "${j}"
			#Write the modified file to the target file, with the following modifications:
			#- Replace the placeholder server URL
			#- Uncomment all the commented `#&> /dev/null` to prevent the cron file from printing unneeded data
			#- Replace the corresponding file credentials for the ones in the credentials file
			sed -e "s/friendica.example.net/${serverurl}/g" -e "s/#&>/\&\>/g" "${i}" -e "s/\(token=\${.*:-\"\)[0-9a-f]*\"/\1${credential}\"/g" | sudo tee "${j}" &>/dev/null
		done < <(find "${cronfolder%\/*}" -ipath "${cronfolder}" -iname "${i_tmp%.sh}")
	fi
	#These changes apply to the scripts folder.
	while read -r k; do
		#Show the name of the target file
		echo "${k}"
		#Show the differences between the current target file and the modified file
		diff <(sed -e "s/friendica.example.net/${serverurl}/g" -e "s/\(token=\${.*:-\"\)[0-9a-f]*\"/\1${credential}\"/g" "${i}") "${k}"
		#Write the modified file to the target file, with the following modifications:
		#- Replace the placeholder server URL
		#- Replace the corresponding file credentials for the ones in the credentials file
		sed -e "s/friendica.example.net/${serverurl}/g" -e "s/\(token=\${.*:-\"\)[0-9a-f]*\"/\1${credential}\"/g" "${i}" | tee "${k}" &>/dev/null
	done < <(find "${scriptsfolder}" -iname "${i_tmp}")
done < <(find . -iname "*.sh")
