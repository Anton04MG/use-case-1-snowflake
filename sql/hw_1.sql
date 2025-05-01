CREATE DATABASE STINGRAY_ECOMERSE_DB;

CREATE SCHEMA MANAGER_TOOLSET;

CREATE STAGE STAGE_RAW_DATA;

CREATE SCHEMA INIT_DATA;

CREATE TABLE raw_data(
    order_id NUMBER,
    customer_id STRING,
    customer_name STRING,
    order_date STRING,
    product STRING,
    quantity NUMBER,
    price FLOAT,
    discount FLOAT,
    total_amount FLOAT,
    payment_method STRING,
    shipping_address STRING,
    status STRING
);

CREATE OR REPLACE TABLE td_for_review LIKE raw_data;

CREATE OR REPLACE TABLE td_suspisios_records LIKE raw_data;

CREATE OR REPLACE TABLE td_invalid_date_format LIKE raw_data;

CREATE OR REPLACE TABLE td_invalid_quantity_price LIKE raw_data;

CREATE OR REPLACE TABLE td_clean_records LIKE raw_data;

COPY INTO STINGRAY_ECOMERSE_DB.INIT_DATA.raw_data
FROM (
SELECT  $1, 
        $2, 
        $3, 
        $4,
        $5, 
        $6, 
        $7, 
        $8,
        $9, 
        $10, 
        $11, 
        $12
        FROM
@STINGRAY_ECOMERSE_DB.MANAGER_TOOLSET.STAGE_RAW_DATA/ecommerce_orders.csv
)
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1);

INSERT INTO td_for_review
SELECT *
FROM raw_data
WHERE shipping_address IS NULL AND status = 'Delivered';

INSERT INTO td_suspisios_records
SELECT *
FROM raw_data
WHERE customer_name IS NULL;

UPDATE raw_data
SET payment_method = 'Unknown'
WHERE payment_method IS NULL;

INSERT INTO td_invalid_date_format
SELECT *
FROM raw_data
WHERE TRY_TO_DATE(order_date, 'YYYY-MM-DD') IS NULL;

INSERT INTO td_invalid_quantity_price
SELECT *
FROM raw_data
WHERE quantity <= 0 OR price <= 0;

DELETE FROM raw_data
WHERE quantity <= 0 OR price <= 0;

UPDATE raw_data
SET discount = CASE 
                  WHEN discount < 0 THEN 0
                  WHEN discount > 0.5 THEN 0.5
                  ELSE discount
               END;

UPDATE raw_data
SET total_amount = quantity * price * (1 - discount);

UPDATE raw_data
SET status = 'Pending'
WHERE status = 'Delivered' AND shipping_address IS NULL;

CREATE OR REPLACE TABLE temp_dedup AS
SELECT DISTINCT * FROM raw_data;

TRUNCATE TABLE raw_data;

INSERT INTO raw_data
SELECT * FROM temp_dedup;

DROP TABLE temp_dedup;

INSERT INTO td_clean_records
SELECT *
FROM raw_data
WHERE customer_name IS NOT NULL
  AND TRY_TO_DATE(order_date, 'YYYY-MM-DD') IS NOT NULL
  AND quantity > 0 AND price > 0;
