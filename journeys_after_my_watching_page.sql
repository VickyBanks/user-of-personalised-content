
---- Journeys from the my-watching page and the my-rec page
-- Find things that go my-watching|episode or my-watching|TLEO|episode

SELECT dt, visit_id, RIGHT(page_sequence,length(page_sequence)-CHARINDEX('watching_page|tleo_page|episode_page', page_sequence)+1) AS journey_after
FROM central_insights_sandbox.dataforce_journey_complete
WHERE --page_sequence ILIKE '%watching_page|episode_page%' OR
      page_sequence ILIKE '%watching_page|tleo_page|episode_page%'
ORDER BY dt, visit_id
LIMIT 50;

-- how many times does watching page occur?
-- 99% of visits have 5 or less my_watching|episode_page pairs
SELECT (length(page_sequence) - length(replace(page_sequence, 'watching_page|episode_page', '')))/length('watching_page|episode_page')  AS num_time_page_occurs,
       count(visit_id)
FROM central_insights_sandbox.dataforce_journey_complete
WHERE page_sequence ILIKE '%watching_page|episode_page%'
GROUP BY 1;

/*
   Need to identify journeys with my_watching|episode_page.
   Then find the page number within the visit where this occurs.
   Use the page number of the episode to get the right content id.
   Join this with the start watched table to see if that content was viewed.

   Some visits do this my_watching|episode_page journey more than once. Need to do this process of finding the id 5 times to capture most of the traffic.
   Then put them all in one table and join to the start watched
   */



--- Need to get the journeys watched_page|episode page
DROP TABLE IF EXISTS watched_journeys_1;
CREATE TABLE watched_journeys_1 AS
    SELECT app_type,
           dt,
           visit_id,
           hashed_id,
           page_sequence,
           content_id_sequence,
           (length(page_sequence) - length(replace(page_sequence, 'watching_page|episode_page', ''))) /
           length('watching_page|episode_page')                                                           AS num_time_page_pair_occurs,
           CHARINDEX('watching_page|episode_page', page_sequence)                                         AS index,            -- position of the first time 'watching_page|episode_page' happens within the journey (position is of the 'w')
           RIGHT(page_sequence, length(page_sequence) -
                                (index + length('watching_page|episode_page')))                         AS journey_after,    -- get everything from this position onwards
           length(LEFT(page_sequence, index)) -
           length(replace(LEFT(page_sequence, index), '|', '')) +1                                      AS watch_page_num,   -- Find what page the watching page was
           watch_page_num + 1                                                                           AS ep_page_num,      -- Find what page the ep page was
           REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1                                 AS pos,-- find the position of this page within the content_id string
           substring(content_id_sequence, pos-9, length(content_id_sequence))                             AS content_id_after, -- Get content IDs from the after the search page
           split_part(content_id_after, '|', 1)                                                         as content_id
    FROM central_insights_sandbox.dataforce_journey_complete
    WHERE page_sequence LIKE '%watching_page|episode_page%'
      AND app_type != 'mobile-app'
      AND destination = 'PS_IPLAYER'
AND dt BETWEEN 20200601 AND 20200630;

-- Get any journeys that are watched_page|episode page AFTER this has already been found once by the table above.
DROP TABLE IF EXISTS watched_journeys_2;
CREATE TABLE watched_journeys_2 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_sequence, content_id_after AS content_id_sequence,
           watch_page_num AS watched_page_num_cumulative,
           ep_page_num AS ep_page_num_cumulative

    FROM watched_journeys_1
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_sequence,
       content_id_sequence,
       (length(page_sequence) - length(replace(page_sequence, 'watching_page|episode_page', ''))) /
       length('watching_page|episode_page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('watching_page|episode_page', page_sequence)               AS index,            -- position of the first time 'watching_page|episode_page' happens within the journey (position is of the 'w')
       RIGHT(page_sequence, length(page_sequence) -
                            (index + length('watching_page|episode_page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_sequence, index)) -
       length(replace(LEFT(page_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the page. -9 as length of content_id
       split_part(content_id_after, '|', 1)                                 as content_id,
       watched_page_num_cumulative + watch_page_num AS watched_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys;

-- Again for the third part
DROP TABLE IF EXISTS watched_journeys_3;
CREATE TABLE watched_journeys_3 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_sequence, content_id_after AS content_id_sequence,
           watched_page_num_cumulative,
           ep_page_num_cumulative
    FROM watched_journeys_2
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_sequence,
       content_id_sequence,
       (length(page_sequence) - length(replace(page_sequence, 'watching_page|episode_page', ''))) /
       length('watching_page|episode_page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('watching_page|episode_page', page_sequence)               AS index,            -- position of the first time 'watching_page|episode_page' happens within the journey (position is of the 'w')
       RIGHT(page_sequence, length(page_sequence) -
                            (index + length('watching_page|episode_page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_sequence, index)) -
       length(replace(LEFT(page_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the search page
       split_part(content_id_after, '|', 1)                                 as content_id,
       watched_page_num_cumulative + watch_page_num AS watched_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys;

-- Again for the fourth part
DROP TABLE IF EXISTS watched_journeys_4;
CREATE TABLE watched_journeys_4 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_sequence, content_id_after AS content_id_sequence,
           watched_page_num_cumulative,
           ep_page_num_cumulative
    FROM watched_journeys_3
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_sequence,
       content_id_sequence,
       (length(page_sequence) - length(replace(page_sequence, 'watching_page|episode_page', ''))) /
       length('watching_page|episode_page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('watching_page|episode_page', page_sequence)               AS index,            -- position of the first time 'watching_page|episode_page' happens within the journey (position is of the 'w')
       RIGHT(page_sequence, length(page_sequence) -
                            (index + length('watching_page|episode_page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_sequence, index)) -
       length(replace(LEFT(page_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the search page
       split_part(content_id_after, '|', 1)                                 as content_id,
       watched_page_num_cumulative + watch_page_num AS watched_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys;

-- Again for the fifth part -- less than 1% of visits this more than 5 times
DROP TABLE IF EXISTS watched_journeys_5;
CREATE TABLE watched_journeys_5 AS
with journeys AS (
    SELECT app_type, dt, visit_id, hashed_id, journey_after AS page_sequence, content_id_after AS content_id_sequence,
           watched_page_num_cumulative,
           ep_page_num_cumulative
    FROM watched_journeys_4
    WHERE num_time_page_pair_occurs > 1
)
SELECT app_type,
       dt,
       visit_id,
       hashed_id,
       page_sequence,
       content_id_sequence,
       (length(page_sequence) - length(replace(page_sequence, 'watching_page|episode_page', ''))) /
       length('watching_page|episode_page')                                 AS num_time_page_pair_occurs,
       CHARINDEX('watching_page|episode_page', page_sequence)               AS index,            -- position of the first time 'watching_page|episode_page' happens within the journey (position is of the 'w')
       RIGHT(page_sequence, length(page_sequence) -
                            (index + length('watching_page|episode_page'))) AS journey_after,    -- get everything from this position onwards
       length(LEFT(page_sequence, index)) -
       length(replace(LEFT(page_sequence, index), '|', '')) +
       1                                                                    AS watch_page_num,   -- Find what page the watching page was
       watch_page_num + 1                                                   AS ep_page_num,      -- Find what page the ep page was
       REGEXP_INSTR(content_id_sequence, '\\|', 1, ep_page_num) + 1         AS pos,-- find the position of this page within the content_id string
       substring(content_id_sequence, pos-9, length(content_id_sequence))     AS content_id_after, -- Get content IDs from the after the search page
       split_part(content_id_after, '|', 1)                                 as content_id,
       watched_page_num_cumulative + watch_page_num AS watched_page_num_cumulative,               -- need the page number within the whole visit not just this part
       ep_page_num_cumulative + ep_page_num AS ep_page_num_cumulative                             -- need the page number within the whole visit not just this part

FROM journeys;

--- Checks - how many visits in each table
SELECT count(visit_id) FROM watched_journeys_1; --339,833
SELECT count(visit_id) FROM watched_journeys_2; -- 65,322
SELECT count(visit_id) FROM watched_journeys_3; -- 19,316
SELECT count(visit_id) FROM watched_journeys_4; --  7,790
SELECT count(visit_id) FROM watched_journeys_5; --  3,921


-- Join into one table
DROP TABLE IF EXISTS watched_journeys_complete;
CREATE TABLE watched_journeys_complete AS
    SELECT *, watch_page_num as watched_page_num_cumulative, ep_page_num as ep_page_num_cumulative FROM watched_journeys_1;

INSERT INTO watched_journeys_complete
SELECT * FROM watched_journeys_2;

INSERT INTO watched_journeys_complete
SELECT * FROM watched_journeys_3;

INSERT INTO watched_journeys_complete
SELECT * FROM watched_journeys_4;

INSERT INTO watched_journeys_complete
SELECT * FROM watched_journeys_5;


SELECT * FROM watched_journeys_complete
ORDER BY visit_id LIMIT 200;


-- Join with the journeys start watched table to find out what they watched or not
WITH watched_journeys AS (
    -- Get the journeys watching_page|episode_page
SELECT app_type, dt,visit_id, hashed_id, watched_page_num_cumulative, ep_page_num_cumulative, content_id
    FROM watched_journeys_complete
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
                cast('watching_page' as varchar ) AS click_placement,
                CASE WHEN b.start_flag = 'iplxp-ep-started' THEN 1 ELSE 0 END   as start_flag,
                CASE WHEN b.watched_flag = 'iplxp-ep-watched' THEN 1 ELSE 0 END as watched_flag
         FROM watched_journeys a
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