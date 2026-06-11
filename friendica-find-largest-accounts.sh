#!/bin/bash
#Check for mariadb vs. mysql
dbengine=""
if [[ -n $(type mariadb) ]]; then
	dbengine="mariadb"
elif [[ -n $(type mysql) ]]; then
	dbengine="mysql"
else
	exit
fi
db="friendica"
"${dbengine}" "${db}" -e "\
    create temporary table tmp_authors (\
        select \`author-id\`, \
        count(*) as amount \
        from \`post-user\` \
        group by \`author-id\` \
        order by count(*) desc \
        limit 1000 \
    ); \
    create temporary table tmp_authors_contact (\
        select c.\`id\`, \
        a.amount \
        from contact as c \
        right join tmp_authors as a \
        on c.id <=> a.\`author-id\` \
    ); \
    create temporary table tmp_owners (\
        select \`owner-id\`, \
        count(*) as amount \
        from \`post-user\` \
        group by \`owner-id\` \
        order by count(*) desc \
        limit 1000 \
    ); \
    create temporary table tmp_owners_contact (\
        select c.\`id\`, \
        o.amount \
        from contact as c \
        right join tmp_owners as o \
        on c.id <=> o.\`owner-id\` \
    ); \
    create temporary table tmp_causers (\
        select \`causer-id\`, \
        count(*) as amount \
        from \`post-user\` \
        group by \`causer-id\` \
        order by count(*) desc \
        limit 1000 \
    ); \
    create temporary table tmp_causers_contact (\
        select c.\`id\`, \
        t.amount \
        from contact as c \
        right join tmp_causers as t \
        on c.id <=> t.\`causer-id\` \
    ); \
    create temporary table tmp_contacts (\
        select c.\`id\`,
        c.\`gsid\`,
        c.name, \
        c.url \
        from contact as c \
        where c.\`id\` in (\
            select \`id\` from tmp_authors_contact \
        ) or c.\`id\` in (\
            select \`id\` from tmp_owners_contact \
        ) or c.\`id\` in (\
            select \`id\` from tmp_causers_contact \
        )\
    ); \
    select c.\`id\`, \
    c.name, \
    c.url, \
    ifnull(g.platform, \"\") as platform, \
    (ifnull(a.amount, 0) + ifnull(o.amount, 0) + ifnull(t.amount, 0)) as final_amount \
    from tmp_contacts as c \
    left join tmp_authors_contact as a \
    on c.\`id\` = a.\`id\` \
    left join tmp_owners_contact as o \
    on c.\`id\` = o.\`id\` \
    left join tmp_causers_contact as t \
    on c.\`id\` = t.\`id\` \
    left join gserver as g \
    on g.\`id\` = c.\`gsid\` \
    order by final_amount asc;"
