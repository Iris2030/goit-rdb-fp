—-------------------------------------------- 1 —------------------------------------------------
CREATE SCHEMA IF NOT EXISTS pandemic;


SET search_path TO pandemic;

—-------------------------------------------- 2 —------------------------------------------------

CREATE TABLE IF NOT EXISTS countries (
   id SERIAL PRIMARY KEY,
   code VARCHAR (8) UNIQUE,
   country VARCHAR (100) NOT NULL UNIQUE
);
INSERT INTO countries (code, country)
SELECT DISTINCT "Code", "Entity" FROM infectious_cases
ON CONFLICT (code) DO NOTHING;


CREATE TABLE IF NOT EXISTS normalized_infectious_cases AS
SELECT * FROM infectious_cases;
ALTER TABLE normalized_infectious_cases
   ADD COLUMN id SERIAL PRIMARY KEY,
   ADD COLUMN country_id INT,
   ADD CONSTRAINT fk_country_id FOREIGN KEY (country_id) REFERENCES countries(id);
UPDATE normalized_infectious_cases n
SET country_id = c.id FROM countries c
WHERE c.code = n."Code" AND c.country = n."Entity";
ALTER TABLE normalized_infectious_cases
DROP COLUMN "Entity",
DROP COLUMN "Code"



—-------------------------------------------- 3 —------------------------------------------------


WITH aggregated_values AS (
   SELECT
       id,
       MAX("Number_rabies") AS max_value,
       MIN("Number_rabies") AS min_value,
       AVG(CASE WHEN "Number_rabies" <> 0 THEN "Number_rabies" END) AS average_value,
       SUM("Number_rabies") AS sum_value
   FROM normalized_infectious_cases
   WHERE "Number_rabies" IS NOT NULL
   GROUP BY id
)
SELECT *
FROM aggregated_values
ORDER BY average_value DESC
LIMIT 10;


—-------------------------------------------- 4 —------------------------------------------------



WITH aggregated_values AS (
   SELECT
       id,
       MAX("Number_rabies") AS max_value,
       MIN("Number_rabies") AS min_value,
       AVG(CASE WHEN "Number_rabies" <> 0 THEN "Number_rabies" END) AS average_value,
       SUM("Number_rabies") AS sum_value
   FROM normalized_infectious_cases
   WHERE "Number_rabies" IS NOT NULL
   GROUP BY id
)
SELECT *
FROM aggregated_values
ORDER BY average_value DESC
LIMIT 10;


ALTER TABLE normalized_infectious_cases
ADD COLUMN year_difference INT;
CREATE OR REPLACE FUNCTION fn_year_difference(start_date_input DATE, end_date_input DATE)
RETURNS INT AS $$
BEGIN
   RETURN EXTRACT(YEAR FROM end_date_input) - EXTRACT(YEAR FROM start_date_input);
END;
$$ LANGUAGE plpgsql;
UPDATE infectious_cases_normalized
SET year_difference = fn_year_difference(start_date, cur_date);

—-------------------------------------------- 5 —------------------------------------------------


CREATE OR REPLACE FUNCTION fn_average_cases(period_length INT, frequency VARCHAR)
RETURNS NUMERIC AS $$
DECLARE
   total_infections NUMERIC := 0;
   periods_number INT := 0;
   period_start_date DATE := CURRENT_DATE;
BEGIN
   IF frequency = 'month' THEN
       period_start_date := period_start_date - INTERVAL '1 month' * period_length;
   ELSIF frequency = 'quarter' THEN
       period_start_date := period_start_date - INTERVAL '3 months' * period_length;
   ELSE
       RETURN NULL;
   END IF;
   SELECT
       SUM(CASE
               WHEN date_column >= period_start_date AND date_column < period_start_date + INTERVAL '1 ' || frequency THEN 1
               ELSE 0
           END),
       COUNT(DISTINCT CASE
               WHEN date_column >= period_start_date AND date_column < period_start_date + INTERVAL '1 ' || frequency THEN date_column::date
           END)
   INTO
       total_infections,
       periods_number
   FROM normalized_infectious_cases;
   IF periods_number = 0 THEN
       RETURN NULL; 
   END IF;
   RETURN total_infections / periods_number;
END;
$$ LANGUAGE plpgsql;

