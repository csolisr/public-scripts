#!/bin/bash
#Enables optimizations to make the deletion take less time. Set to 0 to delete more items. Set to 2 to also delete items from your followed accounts (this will break reposts and mentions)
intense_optimizations=${1:-"1"}
#Determines the interval of deletion. Defaults to 365 days.
i=${2:-"365"}
interval="${i} DAY"
dbengine="mariadb"
db="friendica"

#Show only in case we're not optimizing for speed.
if [[ "${intense_optimizations}" -eq 0 ]]; then
	#For safety, find all the posts that would somehow match both criteria and thus be wrongly deleted. We want this to return no results.
	#Then, show how many posts would be deleted this way, sorted by date.
	sudo "${dbengine}" "${db}" -vvve "\
		create temporary table tmp_post_matches (\
			select distinct p.\`uri-id\` from \`post\` p \
			where p.\`author-id\` in (select \`cid\` from \`user-contact\`) \
			or p.\`causer-id\` in (select \`cid\` from \`user-contact\`) \
			or p.\`owner-id\` in (select \`cid\` from \`user-contact\`) \
			or p.\`author-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`causer-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`owner-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`author-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`causer-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`owner-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`author-id\` in (select \`contact-id\` from \`group_member\`) \
			or p.\`causer-id\` in (select \`contact-id\` from \`group_member\`) \
			or p.\`owner-id\` in (select \`contact-id\` from \`group_member\`) \
		); \
		create temporary table tmp_post (\
			select distinct p.\`uri-id\` from \`post\` p \
			where p.\`uri-id\` not in (select \`uri-id\` from \`tmp_post_matches\`) \
			and p.\`created\` < CURDATE() - INTERVAL ${interval} \
		); \
		select t.\`id\`, t.\`name\`, t.\`addr\`, p.\`created\`, c.\`body\` from \`tmp_post\` tmp \
			inner join \`post\` p on p.\`uri-id\` = tmp.\`uri-id\` \
			inner join \`post-content\` c on p.\`uri-id\` = c.\`uri-id\` \
			inner join \`contact\` t on t.\`id\` = p.\`author-id\` \
			where p.\`author-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`causer-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`owner-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`author-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`causer-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`owner-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			order by p.\`created\` desc limit 100; \
		select count(p.\`uri-id\`), p.\`created\` from \`post\` p \
			inner join tmp_post tmp on p.\`uri-id\` = tmp.\`uri-id\` \
			group by date_format(p.\`created\`, \"%y%m\") \
			order by \`created\` desc;"
fi

if [[ "${intense_optimizations}" -lt 2 ]]; then
	#First, search all reserved matches where:
	#- the post is from a followed contact,
	#- the post if from a user of this instance, whether due to the "user" or "contact" IDs,
	#- or the post is from a member of a group.
	#Then, filter all the non-matching items (which we do want to delete) that are older than the given interval.
	#Finally, proceed with the deletion.
	sudo "${dbengine}" "${db}" -vvve "\
		create temporary table tmp_post_matches (\
			select distinct p.\`uri-id\` from \`post\` p \
			where p.\`author-id\` in (select \`cid\` from \`user-contact\`) \
			or p.\`causer-id\` in (select \`cid\` from \`user-contact\`) \
			or p.\`owner-id\` in (select \`cid\` from \`user-contact\`) \
			or p.\`author-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`causer-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`owner-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`author-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`causer-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`owner-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`author-id\` in (select \`contact-id\` from \`group_member\`) \
			or p.\`causer-id\` in (select \`contact-id\` from \`group_member\`) \
			or p.\`owner-id\` in (select \`contact-id\` from \`group_member\`) \
		); \
		create temporary table tmp_post (\
			select distinct p.\`uri-id\` from \`post\` p \
			where p.\`uri-id\` not in (select \`uri-id\` from \`tmp_post_matches\`) \
			and p.\`created\` < CURDATE() - INTERVAL ${interval} \
		); \
		delete from \`post-thread\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-thread-user\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-user\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-tag\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-content\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-media\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-counts\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-category\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-history\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
	" # &> /dev/null
fi

#Show only in case we're not optimizing for speed.
if [[ "${intense_optimizations}" -eq 0 ]]; then
	#Find any posts created before the first user of the instance registered.
	#For safety, search all reserved matches where:
	#- the post is from a followed contact,
	#- the post if from a user of this instance, whether due to the "user" or "contact" IDs,
	#- or the post is from a member of a group.
	#Find all the posts that would somehow match the criteria and thus be wrongly deleted. We want this to return no results.
	#Then, show how many posts would be deleted this way, sorted by date.
	#Finally, proceed with the deletion.
	sudo "${dbengine}" "${db}" -vvve "\
		create temporary table tmp_post (\
			select distinct p.\`uri-id\` from \`post\` p \
			where p.\`created\` < (
				select \`register_date\` from \`user\` \
				order by \`register_date\` asc limit 1 \
			) \
		); \
		select t.\`id\`, t.\`name\`, t.\`addr\`, p.\`created\`, c.\`body\` from \`tmp_post\` tmp \
			inner join \`post\` p on p.\`uri-id\` = tmp.\`uri-id\` \
			inner join \`post-content\` c on p.\`uri-id\` = c.\`uri-id\` \
			inner join \`contact\` t on t.\`id\` = p.\`author-id\` \
			where p.\`author-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`causer-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`owner-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`author-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`causer-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`owner-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			order by p.\`created\` desc limit 100; \
		select count(p.\`uri-id\`), p.\`created\` from \`post\` p \
			inner join tmp_post tmp on p.\`uri-id\` = tmp.\`uri-id\` \
			group by date_format(p.\`created\`, \"%y%m\") \
			order by \`created\` desc; \
		delete from \`post-thread\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-thread-user\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-user\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-tag\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-content\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-media\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-counts\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-category\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-history\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
	" # &> /dev/null
fi

#Execute only for the most intensive deletion.
if [[ "${intense_optimizations}" -eq 2 ]]; then
	#First, search all reserved matches where the post if from a user of this instance, whether due to the "user" or "contact" IDs.
	#Then, filter all the non-matching items (which we do want to delete) that are older than the given interval.
	#For safety, find all the posts that would somehow match the standard criteria and thus be wrongly deleted. We want this to return no results.
	#Then, show how many posts would be deleted this way, sorted by date.
	#Finally, proceed with the deletion.
	sudo "${dbengine}" "${db}" -vvve "\
		create temporary table tmp_post_matches (\
			select distinct p.\`uri-id\` from \`post\` p \
			where p.\`author-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`causer-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`owner-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`author-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`causer-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`owner-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
		); \
		create temporary table tmp_post (\
			select distinct p.\`uri-id\` from \`post\` p \
			where p.\`uri-id\` not in (select \`uri-id\` from \`tmp_post_matches\`) \
			and p.\`created\` < CURDATE() - INTERVAL ${interval} \
		); \
		select t.\`id\`, t.\`name\`, t.\`addr\`, p.\`created\`, c.\`body\` from \`tmp_post\` tmp \
			inner join \`post\` p on p.\`uri-id\` = tmp.\`uri-id\` \
			inner join \`post-content\` c on p.\`uri-id\` = c.\`uri-id\` \
			inner join \`contact\` t on t.\`id\` = p.\`author-id\` \
			where p.\`author-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`causer-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`owner-id\` in (select \`uid\` from \`user\` where \`uid\` != \"0\") \
			or p.\`author-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`causer-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			or p.\`owner-id\` in (select \`id\` from \`contact\` where \`gsid\` = \"1\") \
			order by p.\`created\` desc limit 100; \
		select count(p.\`uri-id\`), p.\`created\` from \`post\` p \
			inner join tmp_post tmp on p.\`uri-id\` = tmp.\`uri-id\` \
			group by date_format(p.\`created\`, \"%y%m\") \
			order by \`created\` desc; \
		delete from \`post-thread\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-thread-user\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-user\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-tag\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-content\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-media\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-counts\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-category\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post-history\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
		delete from \`post\` where \`uri-id\` in (select \`uri-id\` from \`tmp_post\`); \
	" # &> /dev/null
fi
#Show all the leftover posts, sorted by date.
sudo "${dbengine}" "${db}" -e "select count(*), \`created\` from \`post\` group by date_format(\`created\`, \"%y%m\") order by \`created\` desc" # &> /dev/null

#Fix the auto-increment for the affected tables.
sudo "${dbengine}" "${db}" -v -e "\
	alter table \`post-thread\` auto_increment = 1; \
	alter table \`post-thread-user\` auto_increment = 1; \
	alter table \`post-user\` auto_increment = 1; \
	alter table \`post-tag\` auto_increment = 1; \
	alter table \`post-content\` auto_increment = 1; \
	alter table \`post-media\` auto_increment = 1; \
	alter table \`post-counts\` auto_increment = 1; \
	alter table \`post-category\` auto_increment = 1; \
	alter table \`post-history\` auto_increment = 1; \
	alter table \`post\` auto_increment = 1;"
