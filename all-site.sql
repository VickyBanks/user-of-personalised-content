/*
Scrip to follow user journeys from their click to content to starting and completing content.
Focused on journeys from homepage, identifying which homepage module was clicked and led to viewing
Created for experimental work so the user's experiment group is identified and carried throughout

Step 0: Initially set a date range table for ease of changing later and VMB to guard against pipeline issues
Step 1: Identify the user group
Step 2: Impressions - Web only
Step 3: Identify all the clicks to content
Step 4: Select all the ixpl-start impressions and link them back to the click to content
Step 5: Get all watched flags and join to start flags
Step 6: Simplify table and enrich with user data
Step 7: END - delete table
Step 8: Look at results
Step 9: Data for R Statistical Analysis


*/

-- Step 0: Initially set a date range table for ease of changing later and VMB to guard against pipeline issues
DROP TABLE IF EXISTS central_insights_sandbox.vb_date_range;
create table central_insights_sandbox.vb_date_range (
    min_date varchar(20),
    max_date varchar(20));
insert into central_insights_sandbox.vb_date_range
values ('20200601','20200630');


SELECT * FROM central_insights_sandbox.vb_date_range;

--- Create VMB table for ease (and if the vmb pipeline goes down)
DROP TABLE IF EXISTS central_insights_sandbox.vb_vmb_foi_2_temp;
CREATE TABLE central_insights_sandbox.vb_vmb_foi_2_temp AS
SELECT DISTINCT master_brand_name,
                master_brand_id,
                brand_title,
                brand_id,
                series_title,
                series_id,
                episode_id,
                episode_title,
                --programme_duration,
                pips_genre_level_1_names
FROM prez.scv_vmb;



----------------------------------------- Step 1: Identify the user group -----------------------------

DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_ids_temp;
CREATE TABLE central_insights_sandbox.vb_foi_2_ids_temp AS
SELECT DISTINCT a.destination,
                a.dt,
                a.unique_visitor_cookie_id,
                a.visit_id,
                CASE
                    WHEN b.app_type iLIKE '%bigscreen-html%' THEN 'bigscreen'
                    WHEN b.app_type ILIKE '%responsive%' THEN 'web'
                    ELSE 'unknown'
                    END AS platform
FROM s3_audience.publisher a
    LEFT JOIN (
    -- Use the audience activity table to find the app type as the metadata field in publisher is currently blank
    SELECT DISTINCT dt, visit_id, app_type
    FROM s3_audience.audience_activity
    WHERE destination = 'PS_IPLAYER'
      AND dt between (SELECT min_date FROM central_insights_sandbox.vb_date_range)
          AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
      AND app_type IS NOT NULL
        ) b ON a.dt = b.dt AND a.visit_id = b.visit_id

WHERE a.dt between (SELECT min_date FROM central_insights_sandbox.vb_date_range)
    AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
  AND a.destination = 'PS_IPLAYER'
  AND (b.app_type ILIKE '%bigscreen-html%' OR b.app_type ILIKE '%responsive%') --Only keep tv and web as mobile is much harder to track
;



DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_ids;
CREATE TABLE central_insights_sandbox.vb_foi_2_ids AS
    SELECT * FROM central_insights_sandbox.vb_foi_2_ids_temp;


-- This will removed non-signed in users (which we want as exp is only for signed in)
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_ids_hid;
CREATE TABLE central_insights_sandbox.vb_foi_2_ids_hid AS
SELECT DISTINCT a.*,
                c.bbc_hid3,
                CASE WHEN d.frequency_band ISNULL THEN 'new' ELSE d.frequency_band END   AS frequency_band,
                central_insights_sandbox.udf_dataforce_frequency_groups(d.frequency_band) AS frequency_group_aggregated,
                CASE
                    WHEN c.age >= 35 THEN '35+'
                    WHEN c.age <= 10 THEN 'under 10'
                    WHEN c.age >= 11 AND c.age <= 15 THEN '11-15'
                    WHEN c.age >= 16 AND c.age <= 24 THEN '16-24'
                    WHEN c.age >= 25 AND c.age <= 34 then '25-34'
                    ELSE 'unknown'
                    END                                                                   AS age_range
FROM central_insights_sandbox.vb_foi_2_ids a -- all the IDs from publisher
         JOIN (SELECT DISTINCT dt, unique_visitor_cookie_id, visit_id, audience_id, destination
               FROM s3_audience.visits
               WHERE destination = 'PS_IPLAYER'
                 AND dt between (SELECT min_date
                                 FROM central_insights_sandbox.vb_date_range) AND (SELECT max_date
                                                                                                FROM central_insights_sandbox.vb_date_range)
             ) b -- get the audience_id
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.visit_id = b.visit_id AND a.dt = b.dt AND
                 a.destination = b.destination
         JOIN prez.id_profile c ON b.audience_id = c.bbc_hid3 -- gives hid and age
         JOIN iplayer_sandbox.iplayer_weekly_frequency_calculations d -- give frequency groups
              ON (c.bbc_hid3 = d.bbc_hid3 and
                  trunc(date_trunc('week', cast(a.dt as date))) = d.date_of_segmentation)
ORDER BY a.dt, c.bbc_hid3, visit_id
;
SELECT count(distinct bbc_hid3) FROM central_insights_sandbox.vb_foi_2_ids_hid; --13,153,950
------------------------------------------------------- Step 2: Impressions - Web only--------------------------------------------------------------------------------------------


---------------------------------------- Step 3: Identify all the clicks to content ---------------------------------------

-- Need to identify all the clicks to content and link them to the ixpl-start flag.
-- Need all the clicks, not just from homepage, to make sure a click from homepage is not incorrectly linked to (for example) content autoplaying.
-- Need to eliminate clicks from the TLEO because these are a middle step from homepage.


-- All standard clicks
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_content_clicks;
CREATE TABLE central_insights_sandbox.vb_foi_2_content_clicks AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                CASE
                    WHEN a.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked' --simplify this group
                    ELSE a.container END AS container,
                a.attribute,
                a.placement,
                a.result
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_foi_2_ids_hid b -- this is to bring in only those visits in our exp group
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE (a.attribute LIKE 'content-item%' OR a.attribute LIKE 'start-watching%' OR a.attribute = 'resume' OR
       a.attribute = 'next-episode' OR a.attribute = 'search-result-episode~click' OR a.attribute = 'page-section-related~select')
  AND a.publisher_clicks = 1
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;

-- Clicks can come from the autoplay system starting an episode
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_autoplay_clicks;
CREATE TABLE central_insights_sandbox.vb_foi_2_autoplay_clicks AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                CASE
                    WHEN a.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
                    ELSE a.container END AS container,
                a.attribute,
                a.placement,
                CASE
                    WHEN left(right(a.placement, 13), 8) SIMILAR TO '%[0-9]%'
                        THEN left(right(a.placement, 13), 8) -- if this contains a number then its an ep id, if not make blank
                    ELSE 'none' END AS current_ep_id,
                a.result            AS next_ep_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_foi_2_ids_hid b -- this is to bring in only those visits in our journey table
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE (a.attribute LIKE '%squeeze-auto-play%' OR a.attribute LIKE '%squeeze-play%' OR a.attribute LIKE '%end-play%' OR
       a.attribute LIKE '%end-auto-play%' OR a.attribute LIKE '%select-play%')
  AND a.publisher_clicks = 1
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;

-- The autoplay on web doesn't currently send any click. It just shows the countdown to autoplay completing as an impression.
-- Include this as a click for now until better tracking is in place
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_autoplay_web_complete;
CREATE TABLE central_insights_sandbox.vb_foi_2_autoplay_web_complete AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                CASE
                    WHEN a.container iLIKE '%module-if-you-liked%' THEN 'module-if-you-liked'
                    ELSE a.container END AS container,
                a.attribute,
                a.placement,
                CASE
                    WHEN left(right(a.placement, 13), 8) SIMILAR TO '%[0-9]%'
                        THEN left(right(a.placement, 13), 8) -- if this contains a number then its an ep id, if not make blank
                    ELSE 'none' END AS current_ep_id,
                a.result            AS next_ep_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_foi_2_ids_hid  b -- this is to bring in only those visits in our journey table
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE ((a.attribute LIKE '%onward-journey-panel~complete%'
  AND a.publisher_impressions = 1) OR (a.attribute LIKE '%onward-journey-panel~select%'
  AND a.publisher_clicks = 1))
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;


-- Deep links into content from off platform. This needs to regex to identify the content pid the link took users too.
-- Not all pids can be identified and not all links go direct to content.
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_deeplinks_temp;
CREATE TABLE central_insights_sandbox.vb_foi_2_deeplinks_temp AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.url,
                CASE
                    WHEN a.url ILIKE '%/playback%' THEN SUBSTRING(
                            REVERSE(regexp_substr(REVERSE(a.url), '[[:alnum:]]{6}[0-9]{1}[pbwnmlc]{1}/')), 2,
                            8) -- Need the final instance of the phrase'/playback' to get the episode ID so reverse url so that it's now first.
                    ELSE 'unknown' END                                                                   AS click_result,
                row_number()
                over (PARTITION BY a.dt,a.unique_visitor_cookie_id,a.visit_id ORDER BY a.event_position) AS row_count
FROM s3_audience.events a
         JOIN central_insights_sandbox.vb_foi_2_ids_hid  b -- this is to bring in only those visits in our journey table
              ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                 b.visit_id = a.visit_id
WHERE a.destination = b.destination
  AND a.url LIKE '%deeplink%'
  AND a.url IS NOT NULL
  AND a.destination = b.destination
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;

-- Take only the first deep link instance
-- Later this will be joined to VMB to ensure link takes directly to a content page.
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_deeplinks;
CREATE TABLE central_insights_sandbox.vb_foi_2_deeplinks AS
SELECT *
FROM central_insights_sandbox.vb_foi_2_deeplinks_temp
WHERE row_count = 1;

------------- Join all the different types of click to content into one table -------------

DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_all_content_clicks;
-- Regular clicks
CREATE TABLE central_insights_sandbox.vb_foi_2_all_content_clicks
AS
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       result AS click_destination_id
FROM central_insights_sandbox.vb_foi_2_content_clicks;


-- Autoplay
INSERT INTO central_insights_sandbox.vb_foi_2_all_content_clicks
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       next_ep_id AS click_destination_id
FROM central_insights_sandbox.vb_foi_2_autoplay_clicks;


-- Web autoplay
INSERT INTO central_insights_sandbox.vb_foi_2_all_content_clicks
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       next_ep_id AS click_destination_id
FROM central_insights_sandbox.vb_foi_2_autoplay_web_complete;

-- Deeplinks
INSERT INTO central_insights_sandbox.vb_foi_2_all_content_clicks
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       CAST('deeplink' AS varchar) AS container,
       CAST('deeplink' AS varchar) AS attribute,
       CAST('deeplink' AS varchar) AS placement,
       click_result                AS click_destination_id
FROM central_insights_sandbox.vb_foi_2_deeplinks;



-------------------------------------- Step 4: Select all the ixpl-start impressions and link them back to the click to content -----------------------------------------------------------------

-- For every dt/user/visit combination find all the ixpl start labels from the user group
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_play_starts;
CREATE TABLE central_insights_sandbox.vb_foi_2_play_starts AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.container,
                a.attribute,
                a.placement,
                a.result AS content_id,
                ISNULL(c.series_id,'unknown') AS series_id,
                ISNULL(c.brand_id, 'unknown') AS brand_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_foi_2_ids_hid  b
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.dt = b.dt AND a.visit_id = b.visit_id
LEFT JOIN central_insights_sandbox.vb_vmb_foi_2_temp c ON a.result = c.episode_id
WHERE a.publisher_impressions = 1
  AND a.attribute = 'iplxp-ep-started'
  AND a.destination = 'PS_IPLAYER'
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;


-- Join clicks and starts into one master table. (some clicks will not be to a content page i.e homepage > TLEO and will be dealt with later)
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_clicks_and_starts_temp;
-- Add in start events
CREATE TABLE central_insights_sandbox.vb_foi_2_clicks_and_starts_temp AS
SELECT *
FROM central_insights_sandbox.vb_foi_2_play_starts;

-- Add in click events
INSERT INTO central_insights_sandbox.vb_foi_2_clicks_and_starts_temp
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       event_position,
       container,
       attribute,
       placement,
       click_destination_id AS content_id
FROM central_insights_sandbox.vb_foi_2_all_content_clicks;

-- Add in row number for each visit
-- This is used to match a content click to a start if the click carried no ID (i.e with categories or channels pages)
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_clicks_and_starts;
CREATE TABLE central_insights_sandbox.vb_foi_2_clicks_and_starts AS
SELECT *, row_number() over (PARTITION BY dt,unique_visitor_cookie_id,bbc_hid3, visit_id ORDER BY event_position)
FROM central_insights_sandbox.vb_foi_2_clicks_and_starts_temp
ORDER BY dt, unique_visitor_cookie_id, bbc_hid3, visit_id, event_position;

-- Join the table back on itself to match the content click to the ixpl start by the content_id.
-- For categories and channels the click ID is often unknown so need to create one master table so the click event before ixpl start can be taken in these cases
-- If that's ever fixed then can simply join play starts with clicks
-- The clicks and start flags are split into two temp tables for ease of reading code. Can't just join the two original tables because we need the row count for when the content_id is unknown.
DROP TABLE IF EXISTS vb_temp_starts;
DROP TABLE IF EXISTS vb_temp_clicks;
CREATE TEMP TABLE vb_temp_starts AS SELECT * FROM central_insights_sandbox.vb_foi_2_clicks_and_starts WHERE attribute = 'iplxp-ep-started';
CREATE TEMP TABLE vb_temp_clicks AS SELECT * FROM central_insights_sandbox.vb_foi_2_clicks_and_starts WHERE attribute != 'iplxp-ep-started';


DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_clicks_linked_starts_temp;
CREATE TABLE central_insights_sandbox.vb_foi_2_clicks_linked_starts_temp AS
SELECT a.dt,
       a.unique_visitor_cookie_id,
       a.bbc_hid3,
       a.visit_id,
       a.event_position                     AS click_event_position,
       a.container                          AS click_container,
       a.attribute                          AS click_attibute,
       a.placement                          AS click_placement,
       a.content_id                         AS click_id,
       b.container                          AS content_container,
       ISNULL(b.attribute, 'no-start-flag') AS content_attribute,
       b.placement                          AS content_placement,
       b.content_id                         AS content_id,
       b.event_position                     AS content_start_event_position,
       CASE
           WHEN b.event_position IS NOT NULL THEN CAST(b.event_position - a.event_position AS integer)
           ELSE 0 END                       AS content_start_diff
FROM vb_temp_clicks a
         LEFT JOIN vb_temp_starts b
                   ON a.dt = b.dt AND a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND
                      a.visit_id = b.visit_id AND CASE
                                                      WHEN a.content_id != 'unknown' AND a.content_id = b.content_id
                                                          THEN a.content_id = b.content_id -- Check the content IDs match if possible
                                                      WHEN a.content_id != 'unknown' AND
                                                           a.content_id != b.content_id AND a.content_id = b.series_id
                                                          THEN a.content_id = b.series_id -- see if the click's content id is actually a series
                                                      WHEN a.content_id != 'unknown' AND
                                                           a.content_id != b.content_id AND
                                                           a.content_id != b.series_id AND a.content_id = b.brand_id
                                                          THEN a.content_id = b.brand_id -- see if the click's content id is actually a series
                                                      WHEN a.content_id = 'unknown'
                                                          THEN a.row_number = b.row_number - 1 -- Click is row above start - if you can't check IDs or master brands, just link with row above (click is one above start)
                          END
WHERE content_start_diff >= 0 -- For the null cases with no matching start flag the value given = 0.
ORDER BY a.visit_id, a.event_position
;


-- Prevent the join over counting
-- Prevent one click being joined to multiple starts
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid_temp;
CREATE TABLE central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid_temp AS
SELECT *,
       CASE
           WHEN content_attribute = 'iplxp-ep-started' THEN row_number()
                                                            over (PARTITION BY dt,unique_visitor_cookie_id,bbc_hid3, visit_id,click_event_position ORDER BY content_start_diff)
           ELSE 1 END AS duplicate_count,
       CASE
           WHEN content_attribute = 'iplxp-ep-started' THEN row_number()
                                                            over (PARTITION BY dt,unique_visitor_cookie_id,bbc_hid3, visit_id, content_start_event_position ORDER BY content_start_diff)
           ELSE 1 END AS duplicate_count2
FROM central_insights_sandbox.vb_foi_2_clicks_linked_starts_temp
ORDER BY dt, bbc_hid3, visit_id, content_start_event_position;


-- Update table so duplicate joins have the ixpl-ep-started label set to null.
-- If two clicks are joined to the same start, make null the record for row with the largest content_start_diff as this is an incorrect join.
-- This retains both clicks and just the one start
UPDATE central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid_temp
SET content_container = NULL,
    content_attribute = 'no-start-flag',
    content_placement = NULL,
    content_id = NULL,
    content_start_event_position = NULL,
    content_start_diff = NULL
WHERE duplicate_count2 != 1;

-- Remove records where a click has been accidentally duplicated.
DELETE FROM central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid_temp
WHERE duplicate_count != 1;

-- The clicks and starts are now validated
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid;
CREATE TABLE central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid
AS SELECT * FROM central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid_temp;

-- Define value if there's no start
UPDATE central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid
SET content_attribute = (CASE
                             WHEN content_attribute IS NULL THEN 'no-start-flag'
                             ELSE content_attribute END);


-- simplify table
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_valid_starts;
CREATE TABLE central_insights_sandbox.vb_foi_2_valid_starts AS
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,

       click_attibute,
       click_container,
       click_placement,
       click_id,
       click_event_position,
       content_attribute,
       content_placement,
       content_id,
       content_start_event_position
FROM central_insights_sandbox.vb_foi_2_clicks_linked_starts_valid;


--------------------------------------  Step 5: Get all watched flags and join to start flags -------------------------------------------------

-- For every dt/user/visit combination find all the ixpl watched labels
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_play_watched;
CREATE TABLE central_insights_sandbox.vb_foi_2_play_watched AS
SELECT DISTINCT a.dt,
                a.unique_visitor_cookie_id,
                b.bbc_hid3,
                a.visit_id,
                a.event_position,
                a.container,
                a.attribute,
                a.placement,
                a.result AS content_id
FROM s3_audience.publisher a
         JOIN central_insights_sandbox.vb_foi_2_ids_hid b
              ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.dt = b.dt AND a.visit_id = b.visit_id
WHERE a.publisher_impressions = 1
  AND a.attribute = 'iplxp-ep-watched'
  AND a.destination = 'PS_IPLAYER'
  AND a.dt BETWEEN (SELECT min_date FROM central_insights_sandbox.vb_date_range) AND (SELECT max_date FROM central_insights_sandbox.vb_date_range)
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.event_position;


-- Join the watch events to the validated start events, ensuring the same content_id
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_starts_and_watched;
CREATE TABLE central_insights_sandbox.vb_foi_2_starts_and_watched AS
SELECT a.*,
       ISNULL(b.attribute, 'no-watched-flag') AS watched_flag,
       b.event_position                       AS content_watched_event_position,
       b.content_id                           AS watched_content_id,
       CASE
           WHEN b.event_position Is NOT NULL THEN CAST(b.event_position - a.content_start_event_position AS integer)
           ELSE 0 END                         AS start_watched_diff,
       CASE
           WHEN watched_flag = 'iplxp-ep-watched' THEN row_number()
                                                             over (PARTITION BY a.dt,a.unique_visitor_cookie_id,a.bbc_hid3, a.visit_id,a.content_start_event_position ORDER BY start_watched_diff)
           ELSE 1 END                         AS duplicate_count,
       CASE
           WHEN content_attribute = 'iplxp-ep-started' AND watched_flag = 'iplxp-ep-watched' THEN
                       row_number() over (partition by a.dt,a.unique_visitor_cookie_id,a.bbc_hid3, a.visit_id, content_watched_event_position ORDER BY start_watched_diff)
           ELSE 1 END AS duplicate_count2
FROM central_insights_sandbox.vb_foi_2_valid_starts a
         LEFT JOIN central_insights_sandbox.vb_foi_2_play_watched b
                   ON a.unique_visitor_cookie_id = b.unique_visitor_cookie_id AND a.dt = b.dt AND
                      a.visit_id = b.visit_id AND a.content_id = b.content_id
WHERE start_watched_diff >= 0
ORDER BY a.dt, b.bbc_hid3, a.visit_id, a.click_event_position;


-- Set values to null where a watched event has been incorrectly joined to a second start.
UPDATE central_insights_sandbox.vb_foi_2_starts_and_watched
SET watched_content_id = NULL,
    content_watched_event_position = NULL,
    start_watched_diff = NULL,
    watched_flag = 'no-watched_flag'
WHERE duplicate_count2 != 1;

-- remove records accidentally duplicated
DELETE FROM central_insights_sandbox.vb_foi_2_starts_and_watched
WHERE duplicate_count != 1;

--------------------------------------  Step 6: Simplify table and enrich with user data -------------------------------------------------
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_valid_watched;
CREATE TABLE central_insights_sandbox.vb_foi_2_valid_watched AS
SELECT dt,
       unique_visitor_cookie_id,
       bbc_hid3,
       visit_id,
       click_event_position,
       click_container,
       click_placement,
       content_placement,
       content_id,
       content_start_event_position,
       content_watched_event_position,
       content_attribute  AS start_flag,
       watched_flag
FROM central_insights_sandbox.vb_foi_2_starts_and_watched;


--In case any null values have slipped through
UPDATE central_insights_sandbox.vb_foi_2_valid_watched
SET start_flag = (CASE
                      WHEN start_flag IS NULL THEN 'no-start-flag'
                      ELSE start_flag END);
UPDATE central_insights_sandbox.vb_foi_2_valid_watched
SET watched_flag = (CASE
                        WHEN watched_flag IS NULL THEN 'no-watched-flag'
                        ELSE watched_flag END);

-- enrich with the data about users e.g age
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_valid_watched_enriched;
CREATE TABLE central_insights_sandbox.vb_foi_2_valid_watched_enriched AS
SELECT a.dt,
       a.unique_visitor_cookie_id,
       a.bbc_hid3,
       b.frequency_band,
       b.frequency_group_aggregated,
       a.visit_id,
       a.click_event_position,
       a.click_container,
       a.click_placement,
       a.content_placement,
       a.content_id,
       a.content_start_event_position,
       a.content_watched_event_position,
       CASE WHEN a.start_flag = 'iplxp-ep-started' THEN 1
           ELSE 0 END as start_flag,
       CASE WHEN a.watched_flag = 'iplxp-ep-watched' THEN 1
           ELSE 0 END as watched_flag,
       b.platform,
       b.age_range
FROM central_insights_sandbox.vb_foi_2_valid_watched a
         LEFT JOIN central_insights_sandbox.vb_foi_2_ids_hid b
                   ON a.dt = b.dt AND a.bbc_hid3 = b.bbc_hid3 AND a.visit_id = b.visit_id
;

-- This table ONLY contains people where content and clicks were identified.
-- There will be visits where nothing happened so this table will have fewer hids than the hid table.

-- Final table (labelled with exp name)
DROP TABLE IF EXISTS central_insights_sandbox.vb_foi_2_final_no_tleo;
CREATE TABLE central_insights_sandbox.vb_foi_2_final_no_tleo AS
    SELECT * FROM central_insights_sandbox.vb_foi_2_valid_watched_enriched;
