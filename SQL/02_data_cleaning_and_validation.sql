/*
Project: Olist Brazilian E-commerce Analysis
File: 02_data_cleaning_and_validation.sql
Purpose: Document the data-cleaning process and perform data-quality validation
Author: Sonali
*/

USE OlistDB;
GO


/* =========================================================
     1. DATA IMPORT AND CLEANING APPROACH
   ========================================================= */

/*
CSV files containing dates and long-text fields were initially imported
into staging tables using NVARCHAR columns.

Blank strings were converted to NULL using NULLIF, while TRY_CONVERT
was used to safely convert valid text values into DATETIME2 values
before loading them into the final destination tables.

The final tables use appropriate SQL data types. The staging tables
were temporary import-support objects and are not included in the
final project schema.

Portuguese product categories were mapped to English using the
category_translation table. Missing categories and missing translations
were handled as 'Unknown' during analysis using COALESCE.
*/

/* =========================================================
   2. TABLE ROW COUNTS
   ========================================================= */

SELECT 'orders' AS table_name, COUNT(*) AS row_count FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'customers', COUNT(*) FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'category_translation', COUNT(*) FROM category_translation;


/* =========================================================
   3. PRIMARY-KEY DUPLICATE CHECKS
  
   ========================================================= */

SELECT order_id, COUNT(*) AS duplicate_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;

SELECT customer_id, COUNT(*) AS duplicate_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT product_id, COUNT(*) AS duplicate_count
FROM products
GROUP BY product_id
HAVING COUNT(*) > 1;

SELECT seller_id, COUNT(*) AS duplicate_count
FROM sellers
GROUP BY seller_id
HAVING COUNT(*) > 1;


/* Composite key check for order items */

SELECT
order_id,
order_item_id,
COUNT(*) AS duplicate_count
FROM order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

/* Composite key check for payments */

SELECT
order_id,
payment_sequential,
COUNT(*) AS duplicate_count
FROM payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1;


/* =========================================================
   4. NULL DATE VALIDATION
   ========================================================= */

SELECT
SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END)
 AS missing_approved_dates,

SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END)
AS missing_carrier_dates,

SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END)
 AS missing_delivery_dates
FROM orders;


/* =========================================================
   5. DATE RANGE VALIDATION
   ========================================================= */

SELECT
MIN(order_purchase_timestamp) AS first_purchase_timestamp,
MAX(order_purchase_timestamp) AS latest_purchase_timestamp
FROM orders;

SELECT
MIN(order_purchase_timestamp) AS first_delivered_purchase,
MAX(order_purchase_timestamp) AS latest_delivered_purchase
FROM orders
WHERE order_status = 'delivered';


/* =========================================================
   6. ORDER STATUS VALIDATION
   ========================================================= */

SELECT
order_status,
COUNT(DISTINCT order_id) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


/* =========================================================
   7. REFERENTIAL-INTEGRITY CHECKS
   ========================================================= */

SELECT COUNT(*) AS order_items_without_matching_order
FROM order_items oi
LEFT JOIN orders o
ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS orders_without_matching_customer
FROM orders o
LEFT JOIN customers c
ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

SELECT COUNT(*) AS order_items_without_matching_product
FROM order_items oi
LEFT JOIN products p
ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

SELECT COUNT(*) AS order_items_without_matching_seller
FROM order_items oi
LEFT JOIN sellers s
ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;

SELECT COUNT(*) AS payments_without_matching_order
FROM payments p
LEFT JOIN orders o
ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

SELECT COUNT(*) AS reviews_without_matching_order
FROM order_reviews r
LEFT JOIN orders o
ON r.order_id = o.order_id
WHERE o.order_id IS NULL;


/* =========================================================
   8. CATEGORY-TRANSLATION VALIDATION
   ========================================================= */

SELECT
CASE
    WHEN p.product_category_name IS NULL
       THEN 'Missing category'
    WHEN ct.product_category_name_english IS NULL
       THEN 'No translation'
    ELSE 'Translated'
    END AS category_status,
COUNT(DISTINCT p.product_category_name) AS distinct_categories,
COUNT(*) AS product_count
FROM products p
LEFT JOIN category_translation ct
ON p.product_category_name = ct.product_category_name
GROUP BY
    CASE
        WHEN p.product_category_name IS NULL
            THEN 'Missing category'
        WHEN ct.product_category_name_english IS NULL
            THEN 'No translation'
        ELSE 'Translated'
END;

/* Final category name used during analysis */

SELECT TOP 10
p.product_id,
COALESCE(
 ct.product_category_name_english,
  'Unknown' ) AS category_name
FROM products p
LEFT JOIN category_translation ct
ON p.product_category_name = ct.product_category_name
ORDER BY p.product_id;

/* =========================================================
   9. DELIVERY-DATE ANOMALY
   Six cancelled orders were found with recorded delivery dates.
   This was retained and documented rather than removed.
   ========================================================= */

SELECT
order_id,
order_status,
order_delivered_customer_date
FROM orders
WHERE order_status = 'canceled'
AND order_delivered_customer_date IS NOT NULL;


/* =========================================================
   10. REVIEW-GRAIN VALIDATION

   Review IDs and order IDs may appear more than once in the
   source data.

   SQL analysis uses ROW_NUMBER to select the latest review
   per order. The Power BI preparation process applies the
   equivalent deduplication before review metrics are calculated.
   ========================================================= */

SELECT
review_id,
COUNT(*) AS review_count
FROM order_reviews
GROUP BY review_id
HAVING COUNT(*) > 1;

SELECT
order_id,
COUNT(*) AS review_count
FROM order_reviews
GROUP BY order_id
HAVING COUNT(*) > 1;


