#!/bin/bash
IFS="
"
#Set your parameters here
site=hub.example.net
user=friendica
group=friendica
fileperm=644
folderperm=755
folder=/var/www/friendica
folderescaped=${folder////\\/}
tmpfile=/tmp/friendica-fix-avatar-permissions.txt
avatarfolder=avatar
cd "$folder" || exit
if [ ! -f "$tmpfile" ]
then
	sudo -u "$user" bin/console movetoavatarcache | sudo tee "$tmpfile" #&> /dev/null
fi
grep -e "https://$site/$avatarfolder/" "$tmpfile" | sed -e "s/.*$site/$folderescaped/g" -e "s/-.*/\*/g" | (
	while read n
	do
		find "$folder/$avatarfolder" -path "$n" -type f | (
			while read p
			do
				if [[ "${p}" =~ ".jpeg" || "${p}" =~ ".jpg" ]]
				then
					jpegoptim -m 76 "${p}" & #&> /dev/null
					if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]
					then
						wait -n
					fi
				fi
				if [[ "${p}" =~  ".gif" ]]
				then
					gifsicle --batch -O3 --lossy=80 --colors=255 "${p}" & #&> /dev/null
					if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]
					then
						wait -n
					fi
					#Specific compression for large GIF files
					while [[ $(stat -c%s "${p}") -ge 512000 ]]
					do
						gifsicle "${p}" $(seq -f "#%g" 0 2 99) -O3 --lossy=80 --colors=255 -o "${p}" & #&> /dev/null
						if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]
						then
							wait -n
						fi
					done
				fi
				if [[ "${p}" =~ ".png" ]]
				then
					oxipng -o max "${p}" & #&> /dev/null
					if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]
					then
						wait -n
					fi
				fi
				if [[ "${p}" =~ ".webp" ]]
				then
					cwebp -mt -af -quiet "${p}" -o /tmp/temp.webp #&> /dev/null
					if [ -f /tmp/temp.webp ]
					then
						size_new=$(stat -c%s "/tmp/temp.webp")
						size_original=$(stat -c%s "${p}")
						if [ "$size_original" -gt "$size_new" ]
						then
							mv /tmp/temp.webp "${p}"
						else
							rm /tmp/temp.webp
						fi
					fi
				fi
			done
		)
	done
)
wait
rm "$tmpfile"
/usr/bin/find $folder/avatar -type d -empty -delete
/usr/bin/chmod $folderperm $folder/avatar
/usr/bin/chown -R $user:$group $folder/avatar
/usr/bin/find $folder/avatar -depth -not -user $user -or -not -group $group -print0 | xargs -0 -r sudo chown -v $user:$group #&> /dev/null
/usr/bin/find $folder/avatar -depth -type d -and -not -type f -and -not -perm $folderperm -print0 | xargs -0 -r sudo chmod -v $folderperm #&> /dev/null
/usr/bin/find $folder/avatar -depth -type f -and -not -type d -and -not -perm $fileperm -print0 | xargs -0 -r sudo chmod -v $fileperm #&> /dev/null
