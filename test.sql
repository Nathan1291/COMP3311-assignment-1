CREATE OR REPLACE VIEW test AS
SELECT beer_names as beer, string_agg(brewery_names, '+') as brewery, ingredient_names
    FROM (SELECT breweries.name as brewery_names, beers.name as beer_names, ingredients.name as ingredient_names, beers.id as beer_id
        FROM beers
        JOIN brewed_by ON beers.id = brewed_by.beer
        JOIN breweries ON brewed_by.brewery = breweries.id
        LEFT JOIN Contains ON beers.id = Contains.beer
        LEFT JOIN Ingredients ON Contains.ingredient = Ingredients.id
        WHERE beers.name ILIKE '%' || 'dank' || '%' and beers.id = brewed_by.beer
        ORDER BY Ingredients.name, breweries.name
    ) as list
    GROUP BY beer_names, ingredient_names
    ORDER BY beer_names
