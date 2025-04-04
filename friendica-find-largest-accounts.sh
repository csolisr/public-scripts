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
    create temporary table tmp_owners (\
        select \`owner-id\`, \
        count(*) as amount \
        from \`post-user\` \
        group by \`owner-id\` \
        order by count(*) desc \
        limit 1000 \
    ); \
    create temporary table tmp_causers (\
        select \`causer-id\`, \
        count(*) as amount \
        from \`post-user\` \
        group by \`causer-id\` \
        order by count(*) desc \
        limit 1000 \
    ); \
    select \
        c.\`id\`, \
        c.name, \
        c.url, \
	    g.platform, \
        (a.amount + o.amount + t.amount) as final_amount \
    from contact as c \
	right join tmp_authors as a \
        on c.id = a.\`author-id\` \
	right join tmp_owners as o \
	    on c.id = o.\`owner-id\` \
	right join tmp_causers as t \
	    on c.id = t.\`causer-id\` \
	inner join gserver as g \
	    on g.id = c.gsid \
    order by final_amount asc \
	limit 1000;"
