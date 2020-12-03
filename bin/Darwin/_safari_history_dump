#!/usr/bin/env bash

read -r -d '' select << EOM
SELECT title, url
FROM history_visits
INNER JOIN history_items
ON history_visits.history_item = history_items.id
ORDER BY visit_time desc
LIMIT 1000;
EOM

sqlite3 -noheader -separator $'\t' ~/Library/Safari/History.db \
  "$select" 2>/dev/null \
  | uniq
