
---- Journeys from the rec page
-- But the iplayer.tv.recommendations.page AND iplayer.recommendations.page are not coded in the UDF so can't use the journey sequence.
-- Find things that go rec|episode or rec|TLEO|episode

--
SELECT app_type,  page_name_sequence
FROM central_insights_sandbox.dataforce_journey_complete
WHERE page_name_sequence ILIKE '%recommendations.page%' AND (length(page_sequence) - length(replace(page_sequence, '|', ''))) < 3
LIMIT 10;



-- how many times does watching page occur?
-- 99% of visits have 5 or less my_watching|episode_page pairs
SELECT (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', '')))/length('iplayer.tv.recommendations.page')  AS num_time_page_occurs,
       count(visit_id)
FROM central_insights_sandbox.dataforce_journey_complete
WHERE page_name_sequence ILIKE '%recommendations.page%'
GROUP BY 1;

/*
   Need to identify journeys with rec page. Because it's not coded need to use the page_name_sequence.
   Then find the page number within the visit where this occurs.
   Use the page number of the episode to get the right content id.
   Join this with the start watched table to see if that content was viewed.

   Some visits do this my_watching|episode_page journey more than once. Need to do this process of finding the id 5 times to capture most of the traffic.
   Then put them all in one table and join to the start watched
   */



--- Need to get the journeys with the rec page
DROP TABLE IF EXISTS rec_journeys_1;
CREATE TABLE rec_journeys_1 AS
    SELECT app_type,
           dt,
           visit_id,
           hashed_id,
           page_name_sequence,
           content_id_sequence,
           (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', ''))) /
           length('iplayer.tv.recommendations.page')                                                           AS num_time_page_pair_occurs,
           CHARINDEX('iplayer.tv.recommendations.page', page_name_sequence)                                         AS index,            -- position of the first time 'watching_page|episode_page' happens within the journey (position is of the 'w')
           RIGHT(page_name_sequence, length(page_name_sequence) -
                                (index + length('iplayer.tv.recommendations.page')))                         AS journey_after,    -- get everything from this position onwards
           length(LEFT(page_name_sequence, index)) -
           length(replace(LEFT(page_name_sequence, index), '|', '')) +1                                      AS watch_page_num,   -- Find what page the watching page was
           watch_page_num + 1                                                                           AS ep_page_num,      -- Find what page the ep page was
           REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1                                 AS pos,-- find the position of this page within the content_id string
           substring(content_id_sequence, pos-9, length(content_id_sequence))                             AS content_id_after, -- Get content IDs from the after the search page
           split_part(content_id_after, '|', 1)                                                         as content_id
    FROM central_insights_sandbox.dataforce_journey_complete
    WHERE page_name_sequence LIKE '%iplayer.tv.recommendations.page%'
      AND app_type != 'mobile-app'
      AND destination = 'PS_IPLAYER'
AND dt BETWEEN 20200601 AND 20200630
    AND split_part(page_name_sequence, '|',watch_page_num+1) ILIKE '%episode%'
;

-- Get any journeys that are rec_page|episode page AFTER this has already been found once by the table above.
DROP TABLE IF EXISTS rec_journeys_2;
CREATE TABLE rec_journeys_2 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_name_sequence, content_id_after AS content_id_sequence,
           watch_page_num AS rec_page_num_cumulative,
           ep_page_num AS ep_page_num_cumulative

    FROM rec_journeys_1
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_name_sequence,
       content_id_sequence,
       (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', ''))) /
       length('iplayer.tv.recommendations.page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('iplayer.tv.recommendations.page', page_name_sequence)               AS index,            -- position of the first time 'iplayer.tv.recommendations.page' happens within the journey (position is of the 'w')
       RIGHT(page_name_sequence, length(page_name_sequence) -
                            (index + length('iplayer.tv.recommendations.page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_name_sequence, index)) -
       length(replace(LEFT(page_name_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the page. -9 as length of content_id
       split_part(content_id_after, '|', 1)                                 as content_id,
       rec_page_num_cumulative + watch_page_num AS rec_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys
    WHERE split_part(page_name_sequence, '|',watch_page_num+1) ILIKE '%episode%';

-- Again for the third part
DROP TABLE IF EXISTS rec_journeys_3;
CREATE TABLE rec_journeys_3 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_name_sequence, content_id_after AS content_id_sequence,
           rec_page_num_cumulative,
           ep_page_num_cumulative
    FROM rec_journeys_2
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_name_sequence,
       content_id_sequence,
       (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', ''))) /
       length('iplayer.tv.recommendations.page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('iplayer.tv.recommendations.page', page_name_sequence)               AS index,            -- position of the first time 'iplayer.tv.recommendations.page' happens within the journey (position is of the 'w')
       RIGHT(page_name_sequence, length(page_name_sequence) -
                            (index + length('iplayer.tv.recommendations.page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_name_sequence, index)) -
       length(replace(LEFT(page_name_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the search page
       split_part(content_id_after, '|', 1)                                 as content_id,
       rec_page_num_cumulative + watch_page_num AS rec_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys
    WHERE split_part(page_name_sequence, '|',watch_page_num+1) ILIKE '%episode%';

-- Again for the fourth part
DROP TABLE IF EXISTS rec_journeys_4;
CREATE TABLE rec_journeys_4 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_name_sequence, content_id_after AS content_id_sequence,
           rec_page_num_cumulative,
           ep_page_num_cumulative
    FROM rec_journeys_3
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_name_sequence,
       content_id_sequence,
       (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', ''))) /
       length('iplayer.tv.recommendations.page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('iplayer.tv.recommendations.page', page_name_sequence)               AS index,            -- position of the first time 'iplayer.tv.recommendations.page' happens within the journey (position is of the 'w')
       RIGHT(page_name_sequence, length(page_name_sequence) -
                            (index + length('iplayer.tv.recommendations.page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_name_sequence, index)) -
       length(replace(LEFT(page_name_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the search page
       split_part(content_id_after, '|', 1)                                 as content_id,
       rec_page_num_cumulative + watch_page_num AS rec_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys
    WHERE split_part(page_name_sequence, '|',watch_page_num+1) ILIKE '%episode%';

-- Again for the fifth part -- less than 1% of visits this more than 5 times
DROP TABLE IF EXISTS rec_journeys_5;
CREATE TABLE rec_journeys_5 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_name_sequence, content_id_after AS content_id_sequence,
           rec_page_num_cumulative,
           ep_page_num_cumulative
    FROM rec_journeys_4
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_name_sequence,
       content_id_sequence,
       (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', ''))) /
       length('iplayer.tv.recommendations.page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('iplayer.tv.recommendations.page', page_name_sequence)               AS index,            -- position of the first time 'iplayer.tv.recommendations.page' happens within the journey (position is of the 'w')
       RIGHT(page_name_sequence, length(page_name_sequence) -
                            (index + length('iplayer.tv.recommendations.page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_name_sequence, index)) -
       length(replace(LEFT(page_name_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the search page
       split_part(content_id_after, '|', 1)                                 as content_id,
       rec_page_num_cumulative + watch_page_num AS rec_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys
    WHERE split_part(page_name_sequence, '|',watch_page_num+1) ILIKE '%episode%';

--- Checks - how many visits in each table
SELECT count(visit_id) FROM rec_journeys_1; --339,833
SELECT count(visit_id) FROM rec_journeys_2; -- 65,322
SELECT count(visit_id) FROM rec_journeys_3; -- 19,316
SELECT count(visit_id) FROM rec_journeys_4; --  7,790
SELECT count(visit_id) FROM rec_journeys_5; --  3,921


-- Join into one table
DROP TABLE IF EXISTS rec_journeys_complete;
CREATE TABLE rec_journeys_complete AS
    SELECT *, watch_page_num as rec_page_num_cumulative, ep_page_num as ep_page_num_cumulative FROM rec_journeys_1;

INSERT INTO rec_journeys_complete
SELECT * FROM rec_journeys_2;

INSERT INTO rec_journeys_complete
SELECT * FROM rec_journeys_3;

INSERT INTO rec_journeys_complete
SELECT * FROM rec_journeys_4;

INSERT INTO rec_journeys_complete
SELECT * FROM rec_journeys_5;


SELECT * FROM rec_journeys_complete
ORDER BY visit_id LIMIT 200;


-- Join with the journeys start rec table to find out what they rec or not
WITH rec_journeys AS (
    -- Get the journeys iplayer.tv.recommendations.page
SELECT DISTINCT app_type, dt,visit_id, hashed_id, rec_page_num_cumulative, ep_page_num_cumulative, content_id
    FROM rec_journeys_complete
),
     watch_ep_flags AS (
         SELECT a.dt,
                a.visit_id,
                a.hashed_id,
                a.app_type,
                a.ep_page_num_cumulative                                   as content_page_num,
                b.page_count,
                a.content_id                         AS content_id_1,
                b.content_id,
                cast('rec_page' as varchar ) AS click_placement,
                CASE WHEN b.start_flag = 'iplxp-ep-started' THEN 1 ELSE 0 END   as start_flag,
                CASE WHEN b.watched_flag = 'iplxp-ep-watched' THEN 1 ELSE 0 END as watched_flag
         FROM rec_journeys a
                  LEFT JOIN central_insights_sandbox.dataforce_journey_start_watch_complete b
                            ON a.dt = b.dt AND a.visit_id = b.visit_id AND
                               a.content_id = b.content_id AND
                               a.ep_page_num_cumulative  = b.page_count
)
SELECT click_placement,
       count(distinct hashed_id) AS num_si_users,
       count(visit_id)           as num_clicks,
       sum(start_flag)           as num_starts,
       sum(watched_flag)         as num_completes
FROM watch_ep_flags
GROUP BY 1;



--------------- The same as above but rec page - TLEO - episode --------


--- Need to get the journeys with the rec page
DROP TABLE IF EXISTS rec_tleo_journeys_1;
CREATE TABLE rec_tleo_journeys_1 AS
    SELECT app_type,
           dt,
           visit_id,
           hashed_id,
           page_name_sequence,
           content_id_sequence,
           (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', ''))) /
           length('iplayer.tv.recommendations.page')                                                           AS num_time_page_pair_occurs,
           CHARINDEX('iplayer.tv.recommendations.page', page_name_sequence)                                         AS index,            -- position of the first time the page happens within the journey (position is of the 'w')
           RIGHT(page_name_sequence, length(page_name_sequence) -
                                (index + length('iplayer.tv.recommendations.page')))                         AS journey_after,    -- get everything from this position onwards
           length(LEFT(page_name_sequence, index)) -
           length(replace(LEFT(page_name_sequence, index), '|', '')) +1                                      AS watch_page_num,   -- Find what page the watching page was
           watch_page_num + 2                                                                           AS ep_page_num,      -- Find what page the ep page was given rec-page - TLEO -ep page
           REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1                                 AS pos,-- find the position of this page within the content_id string
           substring(content_id_sequence, pos-9, length(content_id_sequence))                             AS content_id_after, -- Get content IDs from the after the page
           split_part(content_id_after, '|', 1)                                                         as content_id
    FROM central_insights_sandbox.dataforce_journey_complete
    WHERE page_name_sequence LIKE '%iplayer.tv.recommendations.page%'
      AND app_type != 'mobile-app'
      AND destination = 'PS_IPLAYER'
AND dt BETWEEN 20200601 AND 20200630
    AND split_part(page_name_sequence, '|',watch_page_num+1) ILIKE '%tleo%' AND split_part(page_name_sequence, '|',watch_page_num+2) ILIKE '%episode%'

;

-- Get any journeys that are rec_page|episode page AFTER this has already been found once by the table above.
DROP TABLE IF EXISTS rec_tleo_journeys_2;
CREATE TABLE rec_tleo_journeys_2 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_name_sequence, content_id_after AS content_id_sequence,
           watch_page_num AS rec_page_num_cumulative,
           ep_page_num AS ep_page_num_cumulative

    FROM rec_tleo_journeys_1
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_name_sequence,
       content_id_sequence,
       (length(page_name_sequence) - length(replace(page_name_sequence, 'iplayer.tv.recommendations.page', ''))) /
       length('iplayer.tv.recommendations.page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('iplayer.tv.recommendations.page', page_name_sequence)               AS index,            -- position of the first time 'iplayer.tv.recommendations.page' happens within the journey (position is of the 'w')
       RIGHT(page_name_sequence, length(page_name_sequence) -
                            (index + length('iplayer.tv.recommendations.page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_name_sequence, index)) -
       length(replace(LEFT(page_name_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 2                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the page. -9 as length of content_id
       split_part(content_id_after, '|', 1)                                 as content_id,
       rec_page_num_cumulative + watch_page_num AS rec_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys
    WHERE  split_part(page_name_sequence, '|',watch_page_num+1) ILIKE '%tleo%' AND split_part(page_name_sequence, '|',watch_page_num+2) ILIKE '%episode%';


--- Checks - how many visits in each table
SELECT count(visit_id) FROM rec_tleo_journeys_1; --1,046
SELECT count(visit_id) FROM rec_tleo_journeys_2; --    8



-- Join into one table
DROP TABLE IF EXISTS rec_tleo_journeys_complete;
CREATE TABLE rec_tleo_journeys_complete AS
    SELECT *, watch_page_num as rec_page_num_cumulative, ep_page_num as ep_page_num_cumulative FROM rec_tleo_journeys_1;

INSERT INTO rec_tleo_journeys_complete
SELECT * FROM rec_tleo_journeys_2;


SELECT * FROM rec_tleo_journeys_complete
ORDER BY visit_id LIMIT 200;


-- Join with the journeys start rec table to find out what they rec or not
WITH rec_tleo_journeys AS (
    -- Get the journeys iplayer.tv.recommendations.page
SELECT DISTINCT app_type, dt,visit_id, hashed_id, rec_page_num_cumulative, ep_page_num_cumulative, content_id
    FROM rec_tleo_journeys_complete
),
     watch_ep_flags AS (
         SELECT a.dt,
                a.visit_id,
                a.hashed_id,
                a.app_type,
                a.ep_page_num_cumulative                                   as content_page_num,
                b.page_count,
                a.content_id                         AS content_id_1,
                b.content_id,
                cast('rec_page' as varchar ) AS click_placement,
                CASE WHEN b.start_flag = 'iplxp-ep-started' THEN 1 ELSE 0 END   as start_flag,
                CASE WHEN b.watched_flag = 'iplxp-ep-watched' THEN 1 ELSE 0 END as watched_flag
         FROM rec_tleo_journeys a
                  LEFT JOIN central_insights_sandbox.dataforce_journey_start_watch_complete b
                            ON a.dt = b.dt AND a.visit_id = b.visit_id AND
                               a.content_id = b.content_id AND
                               a.ep_page_num_cumulative  = b.page_count
)
SELECT click_placement,
       count(distinct hashed_id) AS num_si_users,
       count(visit_id)           as num_clicks,
       sum(start_flag)           as num_starts,
       sum(watched_flag)         as num_completes
FROM watch_ep_flags
GROUP BY 1;

--- All journeys
CREATE TABLE rec_all_journeys_complete AS
    SELECT * FROM rec_tleo_journeys_complete;

INSERT INTO rec_all_journeys_complete
SELECT * FROM rec_journeys_complete;

SELECT count(visit_id) FROM rec_all_journeys_complete;

WITH rec_all_journeys AS (
    -- Get the journeys iplayer.tv.recommendations.page
SELECT DISTINCT app_type, dt,visit_id, hashed_id, rec_page_num_cumulative, ep_page_num_cumulative, content_id
    FROM rec_all_journeys_complete
),
     watch_ep_flags AS (
         SELECT a.dt,
                a.visit_id,
                a.hashed_id,
                a.app_type,
                a.ep_page_num_cumulative                                   as content_page_num,
                b.page_count,
                a.content_id                         AS content_id_1,
                b.content_id,
                cast('rec_page' as varchar ) AS click_placement,
                CASE WHEN b.start_flag = 'iplxp-ep-started' THEN 1 ELSE 0 END   as start_flag,
                CASE WHEN b.watched_flag = 'iplxp-ep-watched' THEN 1 ELSE 0 END as watched_flag
         FROM rec_all_journeys a
                  LEFT JOIN central_insights_sandbox.dataforce_journey_start_watch_complete b
                            ON a.dt = b.dt AND a.visit_id = b.visit_id AND
                               a.content_id = b.content_id AND
                               a.ep_page_num_cumulative  = b.page_count
)
SELECT click_placement,
       count(distinct hashed_id) AS num_si_users,
       count(visit_id)           as num_clicks,
       sum(start_flag)           as num_starts,
       sum(watched_flag)         as num_completes
FROM watch_ep_flags
GROUP BY 1;