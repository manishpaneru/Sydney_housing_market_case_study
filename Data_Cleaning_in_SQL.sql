USE sydsub;

-- Display all data to understand the table structure and content before cleaning.
SELECT * FROM data;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 1: Disable Safe Update Mode
-- Safe update mode is turned off temporarily to allow updates to the table without restrictions.
SET SQL_SAFE_UPDATES = 0;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 2: Handle Missing Categorical Values
-- Replace missing values in the "Nearest Train Station" column with 'Unknown' to standardize the data.
UPDATE data
SET `Nearest Train Station` = 'Unknown'
WHERE `Nearest Train Station` IS NULL;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 3: Handle Missing and Invalid Numeric Values for Housing Prices
-- Calculate the average of "Median House Price (2020)" to replace NULL values in the column.
SET @avg_house_price_2020 = (
    SELECT AVG(CAST(`Median House Price (2020)` AS DECIMAL(10,2)))
    FROM data
    WHERE `Median House Price (2020)` IS NOT NULL
);

-- Replace NULL values in "Median House Price (2020)" with the calculated average.
UPDATE data
SET `Median House Price (2020)` = @avg_house_price_2020
WHERE `Median House Price (2020)` IS NULL;

-- Check for invalid data in "Median House Price (2020)" and replace invalid rows with NULL.
UPDATE data
SET `Median House Price (2020)` = NULL
WHERE REPLACE(REPLACE(`Median House Price (2020)`, '$', ''), ',', '') NOT REGEXP '^[0-9]+(\.[0-9]+)?$';

-- Convert the valid monetary values in "Median House Price (2020)" to numeric format for analysis.
UPDATE data
SET `Median House Price (2020)` = CAST(REPLACE(REPLACE(`Median House Price (2020)`, '$', ''), ',', '') AS DECIMAL(10,2))
WHERE `Median House Price (2020)` IS NOT NULL;

-- Repeat the process for other numeric fields like "Median House Price (2021)" or "Median Apartment Price (2020)."

-- ----------------------------------------------------------------------------------------------------------------
-- Step 4: Handle Percentage Values
-- Identify invalid or non-numeric values in the "% Change" column.
SELECT `% Change`
FROM data
WHERE `% Change` NOT REGEXP '^-?[0-9]+(\.[0-9]+)?$' OR `% Change` IS NULL;

-- Replace invalid values in "% Change" with NULL.
UPDATE data
SET `% Change` = NULL
WHERE `% Change` NOT REGEXP '^-?[0-9]+(\.[0-9]+)?$';

-- Convert valid percentage strings in "% Change" to DECIMAL format.
UPDATE data
SET `% Change` = CAST(`% Change` AS DECIMAL(10,4))
WHERE `% Change` IS NOT NULL;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 5: Create Derived Metrics
-- Add a column to calculate the percentage price change between 2020 and 2021 for houses.
ALTER TABLE data ADD COLUMN `Price Change (%)` FLOAT;

-- Populate "Price Change (%)" with calculated values for rows with valid data.
UPDATE data
SET `Price Change (%)` = (
    (CAST(`Median House Price (2021)` AS DECIMAL(10,2)) - CAST(`Median House Price (2020)` AS DECIMAL(10,2))) /
    CAST(`Median House Price (2020)` AS DECIMAL(10,2)) * 100
)
WHERE `Median House Price (2020)` IS NOT NULL
  AND `Median House Price (2021)` IS NOT NULL;

-- Add a column for "Affordability Index" and calculate its value as the average of rental and buying affordability scores.
ALTER TABLE data ADD COLUMN `Affordability Index` FLOAT;

UPDATE data
SET `Affordability Index` = (`Affordability (Rental)` + `Affordability (Buying)`) / 2;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 6: Standardize and Clean Categorical Data
-- Standardize region names to ensure consistency (e.g., "Upper N. Shore" → "Upper North Shore").
UPDATE data
SET `Region` = 'Upper North Shore'
WHERE `Region` LIKE 'Upper N. Shore';

UPDATE data
SET `Region` = 'Inner West'
WHERE `Region` LIKE 'Inner W.';

-- ----------------------------------------------------------------------------------------------------------------
-- Step 7: Drop Irrelevant Columns
-- Remove columns that are not relevant to the analysis, such as "Review Link" and "Highlights/Attractions."
ALTER TABLE data DROP COLUMN `Review Link`;
ALTER TABLE data DROP COLUMN `Highlights/Attractions`;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 8: Handle Duplicates
-- Turn off "ONLY_FULL_GROUP_BY" mode to group by multiple columns temporarily.
SET SESSION sql_mode = (SELECT REPLACE(@@sql_mode, 'ONLY_FULL_GROUP_BY', ''));

-- Create a temporary table to remove duplicates based on "Name," "Region," and "Postcode."
CREATE TEMPORARY TABLE temp_data AS
SELECT * 
FROM data
GROUP BY `Name`, `Region`, `Postcode`;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 9: Data Validation
-- Check for NULL values in critical columns like "Median House Price (2020)" or "Price Change (%)."
SELECT *
FROM data
WHERE `Median House Price (2020)` IS NULL OR `Price Change (%)` IS NULL;

-- Perform statistical checks for housing prices to identify outliers.
SELECT 
    MIN(`Median House Price (2020)`), MAX(`Median House Price (2020)`), AVG(`Median House Price (2020)`), STD(`Median House Price (2020)`),
    MIN(`Median House Price (2021)`), MAX(`Median House Price (2021)`), AVG(`Median House Price (2021)`), STD(`Median House Price (2021)`)
FROM data;

-- ----------------------------------------------------------------------------------------------------------------
-- Step 10: Export Cleaned Data
-- Export the cleaned dataset for further analysis or visualization.
SELECT * INTO OUTFILE '/path/to/cleaned_data.csv'
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
FROM data;




