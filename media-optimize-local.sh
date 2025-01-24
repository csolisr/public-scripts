#!/bin/bash
IFS="
"
    #media-optimize
    find . -type f -iname "*.jp*" -size +50k | (
        while read p
	do
	    nice -n 15 jpegoptim -m 76 "${p}" &
	    if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]
	    then
	        wait -n
            fi
	done;
    	wait
    )
    find . -type f -iname "*.gif" -size +500k | (
        while read q
	do
            nice -n 15 gifsicle --batch -O3 --lossy=80 --colors=255 "${q}" &
	    if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]
	    then
	        wait -n
            fi
	done;
    	wait
    )
    find . -type f -iname "*.png" -size +300k | (
        while read r
	do
	    nice -n 15 oxipng -o max "${r}" &
	    if [[ $(jobs -r -p | wc -l) -ge $(getconf _NPROCESSORS_ONLN) ]]
	    then
	        wait -n
            fi
	done;
    	wait
    )
    #compress-webp
    find . -type f -iname "*.webp" -size +200k | (
        while read s
	do
            nice -n 15 cwebp -mt -af -quiet "${s}" -o /tmp/"${s##.*\/}"_temp.webp
            if [[ -f /tmp/"${s##.*\/}"_temp.webp ]]
            then
                size_new=$(stat -c%s /tmp/"${s##.*\/}"_temp.webp)
                size_original=$(stat -c%s "${s}")
                if [[ "${size_original}" -gt "${size_new}" ]]
                then
                    mv /tmp/"${s##.*\/}"_temp.webp "${s}"
                else
                    rm /tmp/"${s##.*\/}"_temp.webp
                fi
            fi
        done;
	wait
    )
