DROP TEMPORARY TABLE IF EXISTS tmp.game_ids_page;

CREATE TEMPORARY TABLE tmp.game_ids_page
SELECT 
    id 
FROM tmp.game_ids
ORDER BY id DESC
LIMIT {page_offset}, {page_size}