#!/bin/bash
channel=${1:-"subscriptions"}
breaktime=${2:-"today-1month"}
sleeptime=${3:-"1.0"}
#Via https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script
folder=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
#Required to download your own subscriptions.
#Obtain this file through the procedure listed at
# https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp
#and place it next to your script.
cookies="$folder/yt-cookies.txt"
subfolder="$folder/$channel"
archive="$subfolder/$channel.txt"
sortcsv="$subfolder/$channel-sort.csv"
csv="$subfolder/$channel.csv"
json="$subfolder/$channel.json"
python="python"
if [[ -f "/opt/venv/bin/python" ]]; then
    python="/opt/venv/bin/python"
fi
ytdl="/usr/bin/yt-dlp"
if [[ -f "/opt/venv/bin/yt-dlp" ]]; then
    ytdl="/opt/venv/bin/yt-dlp"
fi
if [[ -z "$subfolder" ]]; then
	mkdir "$subfolder"
fi
cd "$subfolder" || exit
#If available, you can use the cookies from your browser directly:
#    --cookies-from-browser "firefox"
url="https://www.youtube.com/@$channel"
if [[ "$channel" = "subscriptions" ]]; then
    url="https://www.youtube.com/feed/subscriptions"
fi
if [[ -z "$cookies" ]]; then
    "$python" "$ytdl" "$url" \
        --skip-download --download-archive "$archive" \
        --dateafter "$breaktime" \
        --extractor-args youtubetab:approximate_date \
        --break-on-reject --lazy-playlist --write-info-json \
        --sleep-requests "$sleeptime"
else
    "$python" "$ytdl" "$url" \
        --cookies "$cookies" \
        --skip-download --download-archive "$archive" \
        --dateafter "$breaktime" \
        --extractor-args youtubetab:approximate_date \
        --break-on-reject --lazy-playlist --write-info-json \
        --sleep-requests "$sleeptime"
fi
rm -rf "$csv"
ls -t | grep -e ".info.json" | while read -r x; do
    echo youtube $(jq -c '.id' "$x" | sed -e "s/\"//g") | tee -a "$archive" &
    jq -c '[.upload_date, .timestamp, .uploader , .title, .webpage_url]' "$subfolder/$x" | while read -r i; do
        echo "$i" | sed -e "s/^\[//g" -e "s/\]$//g" -e "s/\\\\\"/＂/g" | tee -a "$csv" &
    done
    jq -c '[.upload_date, .timestamp]' "$subfolder/$x" | while read -r i; do
        echo "$i,$x" | sed -e "s/^\[//g" -e "s/\],/,/g" -e "s/\\\\\"/＂/g" | tee -a "$sortcsv" &
    done
    if [[ $(jobs -r -p | wc -l) -ge $(($(getconf _NPROCESSORS_ONLN) * 3 * 2 )) ]]; then
        wait -n
    fi
done
wait
sort "$sortcsv" | uniq > "/tmp/$channel-sort-ordered.csv"
echo "{\"playlistName\":\"$channel\",\"protected\":false,\"description\":\"Videos to watch later\",\"videos\":[" > "/tmp/$channel.db"
cat "/tmp/$channel-sort-ordered.csv" | while read -r line; do
    file=$(echo "$line" | cut -d ',' -f3-)
    echo "$file"
    jq -c "{\"videoId\": .id, \"title\": .title, \"author\": .uploader, \"authorId\": .channel_id, \"lengthSeconds\": .duration, \"published\": .epoch, \"timeAdded\": $(date +%s), \"playlistItemId\": \"$(cat /proc/sys/kernel/random/uuid)\", \"type\": \"video\"}" "$subfolder/$file" | tee -a "/tmp/$channel.db"
    echo "," >> "/tmp/$channel.db"
done
echo "],\"_id\":\"$channel\",\"createdAt\":$(date +%s),\"lastUpdatedAt\":$(date +%s)}" >> "/tmp/$channel.db"
rm "$json"
cat "/tmp/$channel.db" | tr '\n' '\r' | sed -e "s/,\r\]/\]/g" | tr '\r' '\n' | jq -c "." > "$json" && rm "/tmp/$channel.db"
rm "/tmp/$channel-sort-ordered.csv"
sort "$csv" | uniq > "/tmp/$channel-without-header.csv"
echo '"Upload Date", "Timestamp", "Uploader", "Title", "Webpage URL"' > "/tmp/$channel.csv"
cat "/tmp/$channel-without-header.csv" >> "/tmp/$channel.csv"
mv "/tmp/$channel.csv" "$csv"
rm "/tmp/$channel-without-header.csv"
sort "$archive" | uniq > "/tmp/$channel.txt"
mv "/tmp/$channel.txt" "$archive"
