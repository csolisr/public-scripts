#!/bin/bash
#Set your parameters here
url=friendica.example.net
user=friendica
group=www-data
fileperm=640
folderperm=750
db=friendica
folder=/var/www/friendica
#Internal parameters:
#Amount of times the loop has run
iteration=0
#Number of invalid avatars found. Set to 1 initially so we can run the loop at least once
n=1
#Number of entries processed
nx=0
#Last known ID to have been successfully processed
lastid=0
#Generate an index to make searches faster
((indexlength=37+${#url}))
echo "Generating photo index..."
mariadb $db -e "alter table contact add index if not exists photo_index (photo($indexlength))"
#Go to the Friendica installation
cd $folder || exit
#Loop at least once, until no invalid avatars are found
until [[ $n -eq 0 ]]
do
        #Add to the loop, reset values
        iteration=$(("$iteration" + 1))
        n=0
        nx=0
        dblist=$(mariadb $db -B -N -q -e "select id, photo, thumb, micro from contact where id > $lastid and photo like 'https:\/\/$url/avatar/%' order by id")
        m=$(echo "$dblist" | wc -l)
        echo "$dblist" | while read -r id photo thumb micro
        do
                nx=$(("$nx" + 1))
                folderescaped=${folder////\\/}
                #Substitute the URL path with the folder path so we can search for it in the local file system
                #Photo is nominally 320px, actually 300px
                k_photo=$(echo "$photo" | sed -e "s/https:\/\/$url/$folderescaped/g" -e "s/\?ts=.*//g")
                #Thumb is 80px
                k_thumb=$(echo "$thumb" | sed -e "s/https:\/\/$url/$folderescaped/g" -e "s/\?ts=.*//g")
                #Micro is 48px
                k_micro=$(echo "$micro" | sed -e "s/https:\/\/$url/$folderescaped/g" -e "s/\?ts=.*//g")
                #If any of the images is not found in the filesystem
                if [[ ! -e "$k_photo" || ! -e "$k_thumb" || ! -e "$k_micro" ]]
                then
                        #If the avatar uses the standard fallback picture or is local, we cannot use it as a base
                        avatar=$(mariadb $db -B -N -q -e "select avatar from contact where id = \"$id\" and not avatar like \"%$url\" and not avatar like \"%images/person%\"")
                        #If we have a remote avatar as a fallback, download it
                        if [[ $! -eq 0 && -n $avatar ]]
                        then
				echo "$id $avatar"
                                sudo -u $user curl "$avatar" -s -o "$k_photo"
                                #If the file is a valid picture (not empty, not text)
                                if file "$k_photo" | grep -q -v -e "text" -e "empty" -e "symbolic link" -e "directory"
                                then
                                        #Also fetch for thumb/micro and resize
                                        #As the photo is the largest version we have, we will use it as the base, and leave it last to convert
                                        convert "$k_photo" -resize 80x80 -depth 16 "$k_thumb" && chmod "$fileperm" "$k_thumb" && chown "$user:$group" "$k_thumb"
                                        convert "$k_photo" -resize 48x48 -depth 16 "$k_micro" && chmod "$fileperm" "$k_micro" && chown "$user:$group" "$k_micro"
                                        convert "$k_photo" -resize 300x300 -depth 16 "$k_photo" && chmod "$fileperm" "$k_photo" && chown "$user:$group" "$k_photo"
                                else
                                        #If the avatar is not valid, set it as blank in the database
                                        mariadb $db -e "update contact set avatar= \"\", photo = \"\", thumb = \"\", micro = \"\" where id = \"$id\""
                                        rm -rf "$k_photo"
                                fi
                        else
                                #If no remote avatar is found, then we blank the photo/thumb/micro and let the avatar cache process fix them later
                                mariadb $db -e "update contact set photo = \"\", thumb = \"\", micro = \"\" where id = \"$id\""
                        fi
                        n=$(( n + 1 ))
                fi
                lastid="${id}"
                printf "\rIteration %s\tPhotos: %s\tEntry %s/%s " "$iteration" "$n" "$nx" "$m"
        done
        wait
        printf "\nFixing folders and moving to avatar cache...\n"
        sudo -u $user bin/console movetoavatarcache #&> /dev/null
        find ./avatar -depth -not -user "$user" -or -not -group "$group" -exec chown -v "$user:$group" {} \;
        find ./avatar -depth -type f -and -not -type d -and -not -perm "$fileperm" -exec chmod -v "$fileperm" {} \;
        find ./avatar -depth -type d -and -not -perm "$folderperm" -exec chmod -v "$folderperm" {} \;
	#chown -R "$user:$group" ./avatar
done
#Drop index in the end to save storage
mariadb $db -e "alter table contact drop index photo_index"
