SELECT *
FROM central_insights_sandbox.vb_foi_final_no_tleo
LIMIT 5;
SELECT *
FROM central_insights_sandbox.vb_foi_2_final_tleo
LIMIT 5;

-- How many distinct SI users in total?
SELECT count(distinct bbc_hid3) FROM central_insights_sandbox.vb_foi_final_no_tleo; -- 10,769,709
SELECT count(distinct bbc_hid3) FROM central_insights_sandbox.vb_foi_2_final_tleo; --  11,305,564

-- How many distinct visits in total?
SELECT count(distinct dt||visit_id) FROM central_insights_sandbox.vb_foi_final_no_tleo; -- 82,568,001
SELECT count(distinct dt||visit_id) FROM central_insights_sandbox.vb_foi_2_final_tleo; --  90,128,569

---- From homepage modules
with both_paths_comb AS (
    -- homepage -> content and homepage -> TLEO -> content
    SELECT central_insights_sandbox.udf_dataforce_page_type(click_placement) AS page_type,
           click_container,
           count(distinct bbc_hid3)                                          AS num_si_users,
           count(visit_id)                                                   as num_clicks,
           sum(start_flag)                                                   as num_starts,
           sum(watched_flag)                                                 as num_completes
    FROM central_insights_sandbox.vb_foi_final_no_tleo
    WHERE click_placement = 'iplayer.tv.page' --homepage
    GROUP BY 1, 2
),
     direct_path AS (
         -- homepage -> content only
         SELECT central_insights_sandbox.udf_dataforce_page_type(click_placement) AS page_type,
                click_container,
                count(distinct bbc_hid3)                                          AS num_si_users,
                count(visit_id)                                                   as num_clicks,
                sum(start_flag)                                                   as num_starts,
                sum(watched_flag)                                                 as num_completes
         FROM central_insights_sandbox.vb_foi_2_final_tleo
         WHERE click_placement = 'iplayer.tv.page' --homepage
         GROUP BY 1, 2)

SELECT a.page_type,
       a.click_container,
       CASE
           WHEN a.num_si_users > b.num_si_users THEN a.num_si_users
           ELSE b.num_si_users END as num_si_users,
       CASE
           WHEN a.num_clicks > b.num_clicks THEN a.num_clicks
           ELSE b.num_clicks END   as num_clicks,
       a.num_starts,
       a.num_completes,
       b.num_starts,
       b.num_completes
FROM both_paths_comb a
         JOIN direct_path b ON a.page_type = b.page_type and a.click_container = b.click_container
WHERE a.click_container = 'module-recommendations-recommended-for-you'
   OR a.click_container = 'module-watching-continue-watching'
OR a.click_container = 'module-if-you-liked'
;

SELECT DISTINCT click_container FROM central_insights_sandbox.vb_foi_final_no_tleo WHERE click_placement = 'iplayer.tv.page';

--- From end of playback
SELECT distinct central_insights_sandbox.udf_dataforce_page_type(click_placement) AS page_type,
                CASE
                    WHEN click_container ILIKE '%rec%' THEN 'rec'
                    ELSE 'next-episode' END                                       AS click_container,
                count(distinct bbc_hid3)                                          AS num_si_users,
                count(visit_id)                                                   as num_clicks,
                sum(start_flag)                                                   as num_starts,
                sum(watched_flag)                                                 as num_completes
FROM central_insights_sandbox.vb_foi_2_final_tleo
WHERE page_type = 'episode_page'
  AND click_container ILIKE '%next%'
GROUP BY 1, 2;


--- From the TLEO
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
SELECT click_container,
       --attribute,
       count(distinct bbc_hid3) AS num_si_users,
       count(visit_id)          as num_clicks,
       sum(start_flag)          as num_starts,
       sum(watched_flag)        as num_completes
FROM combined
GROUP BY 1--,2;


---- Getting a final distinct set of users
--tables
SELECT count(DISTINCT hashed_id) FROM rec_all_journeys_complete; -- 30,691
SELECT count(DISTINCT hashed_id) FROM watched_all_journeys_complete; -- 127,750
SELECT count(DISTINCT bbc_hid3) FROM cta_TLEO_clicks;

