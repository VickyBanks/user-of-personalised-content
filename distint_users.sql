-- Get all the user hids from across each peice of work and distinct them

SELECT count(DISTINCT hashed_id) FROM rec_all_journeys_complete; --       30,691
SELECT count(DISTINCT hashed_id) FROM watched_all_journeys_complete; -- 127,750
SELECT count(DISTINCT bbc_hid3) FROM cta_TLEO_clicks; --  4,556,852
SELECT count(DISTINCT bbc_hid3) FROM end_of_playback; --  7,296,023
SELECT count(DISTINCT bbc_hid3) FROM homepage_modules; -- 6,756,069

SELECT count(DISTINCT bbc_hid3) FROM dist_users;

-- All users in one table
DROP TABLE IF EXISTS dist_users;
CREATE TABLE dist_users AS
    SELECT DISTINCT hashed_id AS bbc_hid3 FROM rec_all_journeys_complete;

INSERT INTO dist_users
SELECT DISTINCT hashed_id AS bbc_hid3 FROM watched_all_journeys_complete;

INSERT INTO dist_users
SELECT DISTINCT bbc_hid3 FROM cta_TLEO_clicks;

INSERT INTO dist_users
SELECT DISTINCT bbc_hid3 FROM end_of_playback;

INSERT INTO dist_users
SELECT DISTINCT bbc_hid3 FROM homepage_modules;

--- CTA clicks on TLEO
DROP TABLE IF EXISTS  cta_TLEO_clicks;
CREATE TABLE cta_TLEO_clicks AS
WITH cta_clicks AS (
    SELECT dt,
           bbc_hid3,
           visit_id,
           click_event_position,
           click_container,
           content_id,
           start_flag,
           watched_flag
    FROM central_insights_sandbox.vb_foi_2_final_tleo
    WHERE central_insights_sandbox.udf_dataforce_page_type(click_placement) ILIKE '%TLEO%'
      AND click_container ILIKE '%CTA%'
),
     all_clicks AS (
         SELECT dt,
                bbc_hid3,
                visit_id,
                container,
                attribute
         FROM central_insights_sandbox.vb_foi_2_all_content_clicks
         WHERE central_insights_sandbox.udf_dataforce_page_type(placement) ILIKE '%TLEO%'
     ),
     combined AS (
         SELECT a.*, b.attribute
         FROM cta_clicks a
                  JOIN all_clicks b
                       ON a.dt = b.dt AND a.bbc_hid3 = b.bbc_hid3 AND a.visit_id = b.visit_id AND
                          a.click_container = b.container
     )
SELECT bbc_hid3
FROM combined;

-- From the end of playback
CREATE TABLE end_of_playback AS
SELECT distinct central_insights_sandbox.udf_dataforce_page_type(click_placement) AS page_type,
                CASE
                    WHEN click_container ILIKE '%rec%' THEN 'rec'
                    ELSE 'next-episode' END                                       AS click_container,
                bbc_hid3
FROM central_insights_sandbox.vb_foi_2_final_tleo
WHERE page_type = 'episode_page'
  AND click_container ILIKE '%next%';

--- From homepage modules
CREATE TABLE homepage_modules AS
with both_paths_comb AS (
    -- homepage -> content and homepage -> TLEO -> content
    SELECT central_insights_sandbox.udf_dataforce_page_type(click_placement) AS page_type,
           click_container,
           bbc_hid3
    FROM central_insights_sandbox.vb_foi_final_no_tleo
    WHERE click_placement = 'iplayer.tv.page' --homepage
)
SELECT a.page_type,
       a.click_container,
       a.bbc_hid3
FROM both_paths_comb a
WHERE a.click_container = 'module-recommendations-recommended-for-you'
   OR a.click_container = 'module-watching-continue-watching'
;
