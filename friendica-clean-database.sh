#!/bin/bash
interval=14
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-origin-deleted\` (SELECT \`uri-id\`, \`uid\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \
  \`deleted\` AND \`edited\` < (CURDATE() - INTERVAL "$interval" DAY)); \
DELETE FROM \`post-origin\` WHERE (\`parent-uri-id\`, \`uid\`) IN (SELECT * FROM \`tmp-post-origin-deleted\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-user-deleted\` (SELECT \`uri-id\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \
  \`deleted\` AND \`edited\` < (CURDATE() - INTERVAL "$interval" DAY)); \
DELETE FROM \`post-user\` WHERE \`uri-id\` IN (SELECT * FROM \`tmp-post-user-deleted\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-uri-id-not-in-post-user\` (SELECT \`uri-id\` FROM \`post\` \
  WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`)); \
DELETE FROM \`post\` WHERE \`uri-id\` IN (SELECT * FROM \`tmp-post-uri-id-not-in-post-user\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-content-uri-id-not-in-post-user\` (SELECT \`uri-id\` FROM \`post-content\` \
  WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`)); \
DELETE FROM \`post-content\` WHERE \`uri-id\` IN (SELECT * FROM \`tmp-post-content-uri-id-not-in-post-user\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-thread-uri-id-not-in-post-user\` (SELECT \`uri-id\` FROM \`post-thread\` \
  WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post-user\`)); \
DELETE FROM \`post-thread\` WHERE \`uri-id\` IN (SELECT * FROM \`tmp-post-thread-uri-id-not-in-post-user\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-user-uri-id-not-in-post\` (SELECT \`uri-id\` FROM \`post-user\` \
  WHERE \`uri-id\` NOT IN (SELECT \`uri-id\` FROM \`post\`)); \
DELETE FROM \`post-user\` WHERE \`uri-id\` IN (SELECT \`uri-id\` FROM \`tmp-post-user-uri-id-not-in-post\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-item-uri-not-in-valid-post-thread\` (SELECT \`id\` FROM \`item-uri\` WHERE \`id\` IN \
  (SELECT \`uri-id\` FROM \`post-thread\` WHERE \`received\` < (CURDATE() - INTERVAL $interval DAY) \
    AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-thread-user\` \
      WHERE (\`mention\` OR \`starred\` OR \`wall\`) AND \`uri-id\` = \`post-thread\`.\`uri-id\`) \
    AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-category\` \
      WHERE \`uri-id\` = \`post-thread\`.\`uri-id\`) \
    AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-collection\` \
      WHERE \`uri-id\` = \`post-thread\`.\`uri-id\`) \
    AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-media\` \
      WHERE \`uri-id\` = \`post-thread\`.\`uri-id\`) \
    AND NOT \`uri-id\` IN (SELECT \`parent-uri-id\` FROM \`post-user\` INNER JOIN \`contact\` ON \`contact\`.\`id\` = \`contact-id\` AND \`notify_new_posts\` \
      WHERE \`parent-uri-id\` = \`post-thread\`.\`uri-id\`) \
    AND NOT \`uri-id\` IN (SELECT \`parent-uri-id\` FROM \`post-user\` \
      WHERE (\`origin\` OR \`event-id\` != 0 OR \`post-type\` = 128) AND \`parent-uri-id\` = \`post-thread\`.\`uri-id\`) \
    AND NOT \`uri-id\` IN (SELECT \`uri-id\` FROM \`post-content\` \
      WHERE \`resource-id\` != 0 AND \`uri-id\` = \`post-thread\`.\`uri-id\`)) \
); \
DELETE FROM \`item-uri\` WHERE \`id\` IN (SELECT * FROM \`tmp-item-uri-not-in-valid-post-thread\`) ;"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-item-uri-not-in-valid-post-user\` (SELECT \`id\` FROM \`item-uri\` WHERE \`id\` IN (SELECT \`uri-id\` FROM \`post-user\` WHERE \`gravity\` = 0 AND \`uid\` = 0 \
  AND \`received\` < (CURDATE() - INTERVAL $interval DAY) \
  AND NOT \`uri-id\` IN ( \
    SELECT \`parent-uri-id\` FROM \`post-user\` AS \`i\` WHERE \`i\`.\`uid\` != 0 AND \`i\`.\`parent-uri-id\` = \`post-user\`.\`uri-id\` \
  ) AND NOT \`uri-id\` IN ( \
    SELECT \`parent-uri-id\` FROM \`post-user\` AS \`i\` WHERE \`i\`.\`uid\` = 0 AND \`i\`.\`parent-uri-id\` = \`post-user\`.\`uri-id\` AND \`i\`.\`received\` > (CURDATE() - INTERVAL $interval DAY) \
  ) \
)); \
DELETE FROM \`item-uri\` WHERE \`id\` IN (SELECT * FROM \`tmp-item-uri-not-in-valid-post-user\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-attach-not-in-post-media\` (SELECT \`id\` FROM \`attach\` WHERE \`id\` NOT IN (SELECT \`attach-id\` FROM \`post-media\`)); \
DELETE FROM \`attach\` WHERE \`id\` IN (SELECT * FROM \`tmp-attach-not-in-post-media\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-item-uri-not-valid\` (SELECT \`id\` FROM \`item-uri\` WHERE (\
  \`id\` < (\
    SELECT \`uri-id\` FROM \`post\` WHERE \`received\` < CURDATE() - INTERVAL 1 DAY ORDER BY \`received\` DESC LIMIT 1 \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`post-user\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`parent-uri-id\` FROM \`post-user\` WHERE \`parent-uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`thr-parent-id\` FROM \`post-user\` WHERE \`thr-parent-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`external-id\` FROM \`post-user\` WHERE \`external-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`replies-id\` FROM \`post-user\` WHERE \`replies-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`context-id\` FROM \`post-thread\` WHERE \`context-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`conversation-id\` FROM \`post-thread\` WHERE \`conversation-id\`= \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`mail\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`event\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`user-contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`apcontact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`diaspora-contact\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`inbox-status\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`post-delivery\` WHERE \`uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`uri-id\` FROM \`post-delivery\` WHERE \`inbox-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`parent-uri-id\` FROM \`mail\` WHERE \`parent-uri-id\` = \`item-uri\`.\`id\` \
  ) AND NOT EXISTS (\
    SELECT \`thr-parent-id\` FROM \`mail\` WHERE \`thr-parent-id\` = \`item-uri\`.\`id\` \
  )\
)); \
DELETE FROM \`item-uri\` WHERE \`id\` IN (SELECT * FROM \`tmp-item-uri-not-valid\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-item-uri-duplicate\` (SELECT \`id\` FROM \`item-uri\` t1 INNER JOIN \`item-uri\` t2 WHERE t1.\`id\` < t2.\`id\` AND t1.\`uri\` = t2.\`uri\`); \
DELETE FROM \`item-uri\` WHERE \`id\` IN (SELECT * FROM \`tmp-item-uri-duplicate\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-media-duplicate\` (SELECT \`id\` FROM \`post-media\` u1 INNER JOIN \`post-media\` u2 WHERE u1.\`id\` < u2.\`id\` AND u1.\`uri-id\` = u2.\`uri-id\` AND u1.\`url\`= u2.\`url\`); \
DELETE FROM \`post-media\` WHERE \`id\` IN (SELECT * FROM \`tmp-post-media-duplicate\`);"
sudo mariadb friendica --verbose -v -v --show-warnings --execute=\
"CREATE TEMPORARY TABLE \`tmp-post-user-duplicate\` (SELECT \`id\` FROM \`post-user\` v1 INNER JOIN \`post-media\` v2 WHERE v1.\`id\` = v2.\`id\` AND v1.\`uri-id\` = v2.\`uri-id\`); \
DELETE FROM \`post-user\` WHERE \`id\` IN (SELECT * FROM \`tmp-post-user-duplicate\`;"
