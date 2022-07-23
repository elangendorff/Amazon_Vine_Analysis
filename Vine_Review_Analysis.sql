-- The queries that create vine_table below are commented out so as to avoid
-- having to repopulate its data from the source file on subsequent runs.
/*
-- DROP TABLE IF EXISTS vine_table;
CREATE TABLE vine_table (
  review_id TEXT PRIMARY KEY,
  star_rating INTEGER,
  helpful_votes INTEGER,
  total_votes INTEGER,
  vine TEXT,
  verified_purchase TEXT
);

SELECT * FROM vine_table LIMIT 100;
*/


DROP TABLE IF EXISTS vine_table_many_votes;

SELECT *
INTO vine_table_many_votes
FROM vine_table
WHERE 20 <= total_votes
;

SELECT * FROM vine_table_many_votes LIMIT 100;


DROP TABLE IF EXISTS vine_table_helpful;

SELECT *
INTO vine_table_helpful
FROM vine_table_many_votes
WHERE 0.5 <= ( helpful_votes / total_votes::numeric )
;

SELECT * FROM vine_table_helpful LIMIT 100;


DROP TABLE IF EXISTS vine_table_helpful_paid;

SELECT *
INTO vine_table_helpful_paid
FROM vine_table_helpful
WHERE vine = 'Y'
;

SELECT * FROM vine_table_helpful_paid LIMIT 100;


DROP TABLE IF EXISTS vine_table_helpful_unpaid;

SELECT *
INTO vine_table_helpful_unpaid
FROM vine_table_helpful
WHERE vine = 'N'
;

SELECT * FROM vine_table_helpful_unpaid LIMIT 100;


-- All-in-one version. It's not very fast, but it requires no secondary tables.
-- It is, however, faster than making all of the secondary tables, above.
SELECT
    vine                                                                            AS paid_user,
    count(1) FILTER( WHERE star_rating = 5 )                                        AS "5-star_reviews",
    count(1)                                                                        AS total_reviews,
    round( count(1) FILTER( WHERE star_rating = 5 ) * 100 / count(1)::numeric, 2 )  AS "5-star_percentage"
FROM vine_table
WHERE 20 <= total_votes AND 0.5 <= ( helpful_votes / total_votes::numeric )
GROUP BY vine
ORDER BY paid_user DESC
;


-- Version that uses the secondary tables (above), subqueries, and a join.
SELECT
    total.paid_user,
    five_star."5-star_reviews",
    total.total_reviews,
    round( five_star."5-star_reviews" * 100 / total.total_reviews::numeric, 2 ) AS "5-star_percentage"
FROM (
    SELECT vine, count(1)
    FROM vine_table_helpful
    GROUP BY vine
) AS total(paid_user,total_reviews)
    INNER JOIN (
        SELECT vine, count(1)
        FROM vine_table_helpful
        WHERE star_rating = 5
        GROUP BY vine
    ) AS five_star(paid_user,"5-star_reviews")
    ON five_star.paid_user = total.paid_user
ORDER BY paid_user DESC
;


-- Similar to the all-in-one version, but takes advantage of the existence of
-- the (pre-filtered) vine_table_helpful table.
-- Slightly faster than the subquery-and-join version
SELECT
    vine                                                                            AS paid_user,
    count(1) FILTER( WHERE star_rating = 5 )                                        AS "5-star_reviews",
    count(1)                                                                        AS total_reviews,
    round( count(1) FILTER( WHERE star_rating = 5 ) * 100 / count(1)::numeric, 2 )  AS "5-star_percentage"
FROM vine_table_helpful
GROUP BY vine
ORDER BY paid_user DESC
;


-- Uses a union of two pre-filtered, secondary tables.
-- Very fast (provided the secondary tables already exist).
-- Takes approximately half the time of subquery-and-join (above).
SELECT
    'Y'                                                                             AS paid_user,
    count(1) FILTER( WHERE star_rating = 5 )                                        AS "5-star_reviews",
    count(1)                                                                        AS total_reviews,
    round( count(1) FILTER( WHERE star_rating = 5 ) * 100 / count(1)::numeric, 2 )  AS "5-star_percentage"
FROM vine_table_helpful_paid
UNION ALL
SELECT
    'N'                                                                             AS paid_user,
    count(1) FILTER( WHERE star_rating = 5 )                                        AS "5-star_reviews",
    count(1)                                                                        AS total_reviews,
    round( count(1) FILTER( WHERE star_rating = 5 ) * 100 / count(1)::numeric, 2 )  AS "5-star_percentage"
FROM vine_table_helpful_unpaid
ORDER BY paid_user DESC
;

