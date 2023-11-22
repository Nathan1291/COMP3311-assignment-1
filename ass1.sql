-- COMP3311 23T3 Assignment 1
--
-- Fill in the gaps ("...") below with your code
-- You can add any auxiliary views/function that you like
-- but they must be defined in this file *before* their first use
-- The code in this file *MUST* load into an empty database in one pass
-- It will be tested as follows:
-- createdb test; psql test -f ass1.dump; psql test -f ass1.sql
-- Make sure it can load without error under these conditions

-- Put any views/functions that might be useful in multiple questions here



---- Q1

CREATE OR REPLACE VIEW Q1(state, nbreweries) AS
SELECT locations.region, COUNT(*)
FROM   locations, breweries
WHERE  breweries.located_in = locations.id AND
    locations.country = 'Australia'
GROUP BY locations.region
;

---- Q2

CREATE OR REPLACE VIEW Q2(style, min_abv, max_abv) AS
SELECT styles.name, styles.min_abv, styles.max_abv
FROM styles
WHERE styles.max_abv - styles.min_abv = ( SELECT MAX(styles.max_abv - styles.min_abv) FROM styles)
;

---- Q3

CREATE OR REPLACE VIEW Q3(style, lo_abv, hi_abv, min_abv, max_abv) AS
SELECT styles.name, MIN(beers.abv), MAX(beers.abv), styles.min_abv, styles.max_abv
FROM styles, beers
WHERE beers.style = styles.id AND
    NOT (min_abv = max_abv) AND
    ((SELECT MAX(beers.abv) FROM beers WHERE beers.style = styles.id) > styles.max_abv OR (SELECT MIN(beers.abv) FROM beers WHERE beers.style = styles.id) < styles.min_abv)
GROUP BY styles.name, styles.min_abv, styles.max_abv
;


---- Q4

CREATE OR REPLACE VIEW Q4(brewery, rating) AS
SELECT breweries.name, CAST(AVG(beers.rating) AS NUMERIC(3,1))
from breweries, beers, brewed_by
WHERE brewed_by.beer = beers.id AND
    brewed_by.brewery = breweries.id AND
    (SELECT COUNT(*) FROM brewed_by WHERE brewed_by.brewery=breweries.id) >= 5
GROUP BY breweries.name
HAVING CAST(AVG(beers.rating) AS NUMERIC(3,1)) = (SELECT MAX(avg_ratings)
from (SELECT CAST(AVG(beers.rating) AS NUMERIC(3,1))
    as avg_ratings, breweries.name
    from breweries, beers, brewed_by
    WHERE brewed_by.beer = beers.id AND
    brewed_by.brewery = breweries.id AND
    (SELECT COUNT(*) FROM brewed_by WHERE brewed_by.brewery=breweries.id) >= 5
    GROUP BY breweries.name) AS avg_ratings)
;

---- Q5

CREATE OR REPLACE FUNCTION Q5(pattern TEXT)
returns table(beer TEXT, container TEXT, std_drinks NUMERIC)
AS $$
    SELECT beers.name AS beer,
        CONCAT(beers.volume, 'ml ', beers.sold_in) AS container,
        CAST(beers.volume*beers.abv*0.0008 AS NUMERIC(3,1)) AS std_drinks
    FROM beers
    WHERE beers.name ILIKE '%' || pattern || '%'
$$
LANGUAGE SQL;

---- Q6

CREATE OR REPLACE FUNCTION Q6(pattern TEXT)
RETURNS table(country TEXT, first INTEGER, nbeers INTEGER, rating NUMERIC)
AS $$
    SELECT locations.country,
        MIN(beers.brewed),
        COUNT(brewed_by.beer),
        CAST(AVG(rating) AS NUMERIC(3, 1))
    FROM beers
        JOIN brewed_by ON beers.id = brewed_by.beer
        JOIN breweries ON brewed_by.brewery = breweries.id
        JOIN locations ON breweries.located_in = locations.id
    WHERE locations.country ILIKE '%' || pattern || '%'
    GROUP BY locations.country
$$
LANGUAGE SQL
;

---- Q7

CREATE OR REPLACE FUNCTION Q7(_beerID INTEGER)
RETURNS TEXT
AS $$
    DECLARE
        beer_name TEXT := '';
    BEGIN
        IF (_beerID NOT IN (SELECT id FROM beers)) THEN
            RETURN 'No such beer (' || _beerID || ')';
        ELSE
            beer_name = (select name FROM beers WHERE beers.id = _beerID);
            IF (SELECT COUNT(contains.ingredient) FROM contains WHERE contains.beer = _beerID) = 0 THEN
                RETURN '"' || beer_name || '"' || E'\n  no ingredients recorded';
            ELSE
                RETURN '"' || beer_name || '"' || E'\n  contains:' || E'\n' ||
                    (SELECT STRING_AGG('    ' || ingredient_name || ' (' || ingredient_type || ')', E'\n')
                     FROM (
                        SELECT ingredients.name AS ingredient_name, ingredients.itype as ingredient_type
                        FROM contains
                            JOIN ingredients ON contains.ingredient = ingredients.id
                        WHERE contains.beer = _beerID
                        ORDER BY Ingredients.name
                    ) AS ingredient
                );
            END IF;
        END IF;
    END;
$$
LANGUAGE plpgsql;


drop type if exists BeerHops cascade;
create type BeerHops as (beer text, brewery text, hops text);

create or replace function Q8(pattern TEXT)
returns setof BeerHops
as $$
    DECLARE
        record BeerHops;
    BEGIN
        FOR record in
            SELECT beer, brewery, string_agg(ingredient_names, ',')
            FROM (
                SELECT beer_names as beer, string_agg(brewery_names, '+') as brewery, ingredient_names
                FROM (SELECT breweries.name as brewery_names, beers.name as beer_names, ingredients.name as ingredient_names
                    FROM beers
                    JOIN brewed_by ON beers.id = brewed_by.beer
                    JOIN breweries ON brewed_by.brewery = breweries.id
                    LEFT JOIN Contains ON beers.id = Contains.beer
                    LEFT JOIN Ingredients ON Contains.ingredient = Ingredients.id
                    WHERE beers.name ILIKE '%' || pattern || '%'
                    ORDER BY Ingredients.name, breweries.name
                ) as list
                WHERE beer_names ILIKE '%' || pattern || '%'
                GROUP BY beer_names, ingredient_names
                ORDER BY beer_names
            ) as list
            GROUP BY beer, brewery
            ORDER BY beer
        LOOP
        IF record.beer IS NOT NULL THEN
            IF record.hops IS NULL THEN
                record.hops := 'no hops recorded';
                RETURN next record;
            ELSE
                record.hops := (SELECT string_agg(ingredients.name, ',' ORDER BY ingredients.name)
                                 From beers
                                 LEFT JOIN Contains ON beers.id = Contains.beer
                                 LEFT JOIN Ingredients ON Contains.ingredient = Ingredients.id
                                 WHERE beers.name = record.beer AND ingredients.itype = 'hop'
                );
                RETURN next record;
            END IF;
        END IF;
        END LOOP;
    END;
$$
LANGUAGE plpgsql;
