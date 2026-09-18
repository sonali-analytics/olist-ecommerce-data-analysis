/*
Project: Olist Brazilian E-commerce Analysis
File: 03_business_analysis.sql
Purpose: Answer key business questions using SQL
Author: Sonali
*/

USE OlistDB;
GO


/* =========================================================
   1. BUSINESS OVERVIEW
   Total orders, customers, date range and order outcomes
   ========================================================= */

SELECT COUNT(DISTINCT o.order_id) AS total_orders,
COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
MIN(o.order_purchase_timestamp) AS First_purchase_date,
MAX(o.order_purchase_timestamp) AS Latest_purchase_date,
MAX(
CASE WHEN o.order_status = 'delivered'
THEN o.order_purchase_timestamp
END) AS latest_delivered_purchase_date,
COUNT(DISTINCT CASE WHEN o.order_status='delivered' THEN o.order_id  END) AS Delivered_orders,
COUNT(DISTINCT CASE WHEN o.order_status='canceled' THEN o.order_id END) AS Cancelled_orders
FROM orders o
INNER JOIN customers c ON o.customer_id=c.customer_id;



/* =========================================================
   2. DELIVERED-SALES KPIs
   Sales, freight, orders and average order value
   ========================================================= */

SELECT SUM(oi.price) AS Delivered_sales,
COUNT(DISTINCT o.order_id) AS Delivered_orders,
SUM(oi.freight_value) AS Delivered_freight,
SUM(oi.price) + SUM(oi.freight_value) AS delivered_order_value,
CAST(SUM(oi.price)/ NULLIF(COUNT(DISTINCT o.order_id), 0) AS DECIMAL(12,2)
) AS average_order_value
FROM orders o
LEFT JOIN order_items oi
ON o.order_id=oi.order_id
WHERE o.order_status='delivered';


/* =========================================================
   3. MONTHLY DELIVERED-SALES TREND
   ========================================================= */

SELECT YEAR(o.order_purchase_timestamp) AS Order_Year,
MONTH(o.order_purchase_timestamp) AS Month_number,
DATENAME(MONTH, o.order_purchase_timestamp) AS Month_name,
COUNT(DISTINCT o.order_id) AS Delivered_orders,
SUM(oi.price) AS Delivered_sales,
SUM(oi.freight_value) AS total_freight,
SUM(oi.price)/NULLIF(COUNT(DISTINCT o.order_id),0) AS Average_order_value
FROM orders o
LEFT JOIN order_items oi
ON o.order_id=oi.order_id
WHERE o.order_status='delivered'
GROUP BY YEAR(o.order_purchase_timestamp),
MONTH(o.order_purchase_timestamp),
DATENAME(MONTH, o.order_purchase_timestamp)
ORDER BY Order_Year,Month_number;


/* =========================================================
   4. MONTH-OVER-MONTH SALES GROWTH
   ========================================================= */

WITH monthly_sales AS
(
SELECT
DATEFROMPARTS(YEAR(o.order_purchase_timestamp),
MONTH(o.order_purchase_timestamp),1) AS month_start,
SUM(oi.price) AS current_monthly_sales
FROM orders o
LEFT JOIN order_items oi
ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY YEAR(o.order_purchase_timestamp),
MONTH(o.order_purchase_timestamp)
),
sales_with_previous AS
(
SELECT *,
LAG(month_start) OVER (ORDER BY month_start) AS previous_month,
LAG(current_monthly_sales) OVER (ORDER BY month_start) AS previous_month_sales
FROM monthly_sales
)
SELECT
YEAR(month_start) AS order_year,
MONTH(month_start) AS month_number,
DATENAME(MONTH, month_start) AS month_name,
current_monthly_sales,
CASE
  WHEN DATEDIFF(MONTH, previous_month, month_start) = 1
  THEN previous_month_sales
END AS previous_month_sales,
CASE
  WHEN DATEDIFF(MONTH, previous_month, month_start) = 1
  THEN current_monthly_sales - previous_month_sales
END AS sales_difference,
CASE
  WHEN DATEDIFF(MONTH, previous_month, month_start) = 1
  THEN CAST(
            (current_monthly_sales - previous_month_sales) * 100.0
            / NULLIF(previous_month_sales, 0) AS DECIMAL(10,2)
 ) END AS mom_growth_percentage
FROM sales_with_previous
ORDER BY month_start;


/* =========================================================
   5. ORDER-STATUS DISTRIBUTION
   ========================================================= */

WITH status_counts AS
(
SELECT order_status,
COUNT(DISTINCT order_id) AS order_count
FROM orders
GROUP BY order_status
)
SELECT
order_status,
order_count,
CAST(
     order_count * 100.0 / SUM(order_count) OVER () AS DECIMAL(10,2)
) AS order_percentage
FROM status_counts
ORDER BY order_count DESC;


/* =========================================================
   6. PRODUCT-CATEGORY PERFORMANCE
   ========================================================= */

WITH category_sales AS(
SELECT COALESCE(
    ct.product_category_name_english,
    'Unknown'
) AS category_name,
SUM(oi.price) AS delivered_sales,
COUNT(DISTINCT o.order_id) AS delivered_orders,
COUNT(oi.order_item_id) AS no_of_items_sold,
AVG(oi.price) AS avg_selling_price
FROM orders o 
INNER JOIN order_items oi ON o.order_id=oi.order_id
INNER JOIN products p ON p.product_id=oi.product_id
LEFT JOIN category_translation ct ON p.product_category_name=ct.product_category_name
WHERE o.order_status='delivered'
GROUP BY COALESCE(
    ct.product_category_name_english,
    'Unknown'))
SELECT TOP 10 category_name, delivered_sales,
delivered_orders,no_of_items_sold,avg_selling_price,
CAST(delivered_sales * 100.0 / NULLIF(SUM(delivered_sales) OVER (), 0) AS DECIMAL(10,2)
   ) AS category_sales_percentage
FROM category_sales
ORDER BY delivered_sales DESC;

/* =========================================================
   7. CUSTOMER-STATE PERFORMANCE
   ========================================================= */

WITH state_sales AS(
SELECT c.customer_state,
COUNT(DISTINCT c.customer_unique_id) AS Unique_customers,
COUNT(DISTINCT o.order_id) AS delivered_orders,
SUM(oi.price) AS delivered_sales,
CAST(SUM(oi.price)/ NULLIF(COUNT(DISTINCT o.order_id), 0) AS DECIMAL(12,2)
) AS average_order_value
FROM orders o
INNER JOIN customers c ON c.customer_id=o.customer_id
LEFT JOIN order_items oi ON o.order_id=oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state)

SELECT customer_state,Unique_customers,
delivered_orders,delivered_sales,average_order_value,
CAST(delivered_sales * 100.0 / NULLIF(SUM(delivered_sales) OVER (), 0) AS DECIMAL(10,2)
   ) AS state_sales_percentage
FROM state_sales
ORDER BY delivered_sales DESC;

/* =========================================================
   8. PAYMENT-METHOD ANALYSIS
   ========================================================= */

WITH payment_method AS(
SELECT p.payment_type,
COUNT(DISTINCT o.order_id) AS delivered_orders,
COUNT(p.payment_sequential) AS number_of_payment_transactions,
SUM(p.payment_value) AS total_payment_value,
CAST(AVG(p.payment_value) AS DECIMAL(12,2))
    AS average_payment_value,
CAST(
    AVG(CAST(p.payment_installments AS DECIMAL(10,2)))
    AS DECIMAL(10,2)
) AS average_number_of_installments
FROM orders o 
INNER JOIN payments p
ON o.order_id=p.order_id
WHERE o.order_status='delivered'
GROUP BY p.payment_type)
SELECT  *,
CAST(total_payment_value*100.0/NULLIF(SUM(total_payment_value) OVER(),0) AS DECIMAL(10,2)
)AS Payment_type_percentage
FROM payment_method
ORDER BY total_payment_value DESC;

/* =========================================================
   9. REPEAT-CUSTOMER ANALYSIS
   ========================================================= */

WITH repeat_customer AS
(
SELECT c.customer_unique_id,
COUNT(DISTINCT o.order_id) AS delivered_orders
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
)
SELECT
COUNT(*) AS customers_with_at_least_one_delivered_order,
SUM(CASE WHEN delivered_orders = 1 THEN 1 ELSE 0 END) AS one_time_customers,
SUM(CASE WHEN delivered_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
CAST(AVG(CAST(delivered_orders AS DECIMAL(10,2))) AS DECIMAL(10,2)
 ) AS average_number_of_delivered_orders,
 CAST(
       SUM(CASE WHEN delivered_orders > 1 THEN 1 ELSE 0 END)
        * 100.0 / NULLIF(COUNT(*), 0) AS DECIMAL(10,2)
) AS repeat_customer_rate
FROM repeat_customer;


/* =========================================================
   10. DELIVERY PERFORMANCE
   Early, on-time, late and not-delivered orders
   ========================================================= */

WITH delivery_data AS
(
SELECT
order_id,
order_status,
order_delivered_customer_date,
CASE
WHEN order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL
THEN DATEDIFF(DAY, order_estimated_delivery_date,order_delivered_customer_date)
END AS delivery_diff_days
FROM orders
),
d_status AS
(
SELECT *,
CASE
WHEN order_status <> 'delivered'
OR order_delivered_customer_date IS NULL
THEN 'Not Delivered'
WHEN delivery_diff_days < 0
THEN 'Early'
WHEN delivery_diff_days = 0
THEN 'On Time'
WHEN delivery_diff_days > 0
THEN 'Late'
ELSE 'Unknown'
END AS delivery_status
FROM delivery_data
)
SELECT
delivery_status,
COUNT(*) AS number_of_orders,
CAST(COUNT(*) * 100.0/ NULLIF(SUM(COUNT(*)) OVER (), 0) AS DECIMAL(10,2)
 ) AS percentage_total_orders,
CAST(AVG(CAST(delivery_diff_days AS DECIMAL(10,2)))
 AS DECIMAL(10,2)) AS average_delivery_difference
FROM d_status
GROUP BY delivery_status
ORDER BY
CASE delivery_status
WHEN 'Early' THEN 1
WHEN 'On Time' THEN 2
WHEN 'Late' THEN 3
WHEN 'Not Delivered' THEN 4
ELSE 5
END;

/* =========================================================
   11. DELIVERY STATUS AND REVIEW SCORES
   Uses the latest available review per order
   ========================================================= */

WITH delivery_data AS
(
SELECT order_id,
CASE
WHEN order_status <> 'delivered'
OR order_delivered_customer_date IS NULL
THEN 'Not Delivered'
WHEN DATEDIFF(DAY,order_estimated_delivery_date,order_delivered_customer_date) < 0
THEN 'Early'
WHEN DATEDIFF(DAY,order_estimated_delivery_date,order_delivered_customer_date) = 0
THEN 'On Time'
WHEN DATEDIFF(DAY,order_estimated_delivery_date,order_delivered_customer_date) > 0
THEN 'Late'
ELSE 'Unknown'
END AS delivery_status
FROM orders
),
ranked_reviews AS
(
SELECT
order_id,
review_id,
review_score,
review_creation_date,
ROW_NUMBER() OVER(PARTITION BY order_id 
ORDER BY
review_creation_date DESC,
review_answer_timestamp DESC,
review_id DESC) AS rn
FROM order_reviews
)
SELECT
d.delivery_status,
COUNT(DISTINCT r.order_id) AS reviewed_orders,
CAST(
     AVG(CAST(r.review_score AS DECIMAL(10,2)))
     AS DECIMAL(10,2)
) AS average_review_score,

CAST(
SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)* 100.0 / NULLIF(COUNT(*), 0)
AS DECIMAL(10,2)) AS low_score_percentage,

CAST(
SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END)* 100.0 / NULLIF(COUNT(*), 0)
AS DECIMAL(10,2)) AS high_score_percentage
FROM delivery_data d
JOIN ranked_reviews r
ON d.order_id = r.order_id
AND r.rn = 1
GROUP BY d.delivery_status
ORDER BY
    CASE d.delivery_status
        WHEN 'Early' THEN 1
        WHEN 'On Time' THEN 2
        WHEN 'Late' THEN 3
        WHEN 'Not Delivered' THEN 4
        ELSE 5
    END;


/* =========================================================
   12. TOP-SELLER PERFORMANCE
   ========================================================= */

WITH seller_performance AS
(
SELECT
s.seller_id,
s.seller_state,
SUM(oi.price) AS delivered_sales,
COUNT(DISTINCT o.order_id) AS delivered_orders,
COUNT(oi.order_item_id) AS number_of_items_sold,
CAST(AVG(oi.price) AS DECIMAL(12,2)) AS average_selling_price
FROM orders o
JOIN order_items oi
ON o.order_id = oi.order_id
JOIN sellers s
ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state),
ranked_sellers AS
(
SELECT *,
DENSE_RANK() OVER ( ORDER BY delivered_sales DESC) AS sales_rank
FROM seller_performance
)
SELECT
seller_id,
seller_state,
delivered_sales,
delivered_orders,
number_of_items_sold,
average_selling_price,
sales_rank
FROM ranked_sellers
WHERE sales_rank <= 10
ORDER BY sales_rank, seller_id;


/* =========================================================
   13. MONTHLY COHORT RETENTION
   ========================================================= */

WITH customer_activity AS
(
SELECT DISTINCT c.customer_unique_id,
DATEFROMPARTS(YEAR(o.order_purchase_timestamp),MONTH(o.order_purchase_timestamp),1) 
AS activity_month
FROM orders o
JOIN customers c
ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
),
customer_cohorts AS
(
SELECT customer_unique_id, activity_month, 
MIN(activity_month) OVER(PARTITION BY customer_unique_id) AS cohort_month
FROM customer_activity
),
activity_with_index AS
(
SELECT customer_unique_id,
cohort_month,
activity_month,
DATEDIFF(MONTH,cohort_month,activity_month) AS months_since_first_purchase
FROM customer_cohorts
),
cohort_sizes AS
(
SELECT
cohort_month,
COUNT(DISTINCT customer_unique_id) AS cohort_size
FROM customer_cohorts
GROUP BY cohort_month
),
active_customers AS
(
SELECT
cohort_month,
months_since_first_purchase,
COUNT(DISTINCT customer_unique_id) AS active_customers
FROM activity_with_index
WHERE months_since_first_purchase BETWEEN 0 AND 12
GROUP BY cohort_month, months_since_first_purchase
)
SELECT
a.cohort_month,
a.months_since_first_purchase,
c.cohort_size,
a.active_customers,
CAST(a.active_customers * 100.0/ NULLIF(c.cohort_size, 0)
AS DECIMAL(10,2)) AS retention_percentage
FROM active_customers a
JOIN cohort_sizes c
ON a.cohort_month = c.cohort_month
ORDER BY a.cohort_month, a.months_since_first_purchase;

/* =========================================================
   14. CUSTOMER RFM ANALYSIS
   Recency, frequency and monetary value
   ========================================================= */

WITH rfm_base AS
(
SELECT
c.customer_unique_id,
MAX(o.order_purchase_timestamp) AS last_purchase_date,
DATEDIFF(DAY,MAX(o.order_purchase_timestamp),CAST('2018-08-30' AS DATE)) AS recency_days,
COUNT(DISTINCT o.order_id) AS frequency,
COALESCE(SUM(oi.price), 0) AS monetary
FROM customers c
JOIN orders o
ON c.customer_id = o.customer_id
LEFT JOIN order_items oi
ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
),
rfm_ranked AS
(
SELECT *,
RANK() OVER (ORDER BY recency_days ASC) AS recency_rank,
RANK() OVER (ORDER BY monetary DESC) AS monetary_rank,
COUNT(*) OVER () AS total_customers
FROM rfm_base
),
rfm_scored AS
(
SELECT *,
CASE
    WHEN recency_rank <= total_customers * 0.20 THEN 5
    WHEN recency_rank <= total_customers * 0.40 THEN 4
    WHEN recency_rank <= total_customers * 0.60 THEN 3
    WHEN recency_rank <= total_customers * 0.80 THEN 2
    ELSE 1 END AS r_score,

CASE
    WHEN frequency = 1 THEN 1
    WHEN frequency = 2 THEN 2
    WHEN frequency = 3 THEN 3
    WHEN frequency <= 5 THEN 4
    ELSE 5
    END AS f_score,

CASE
   WHEN monetary_rank <= total_customers * 0.20 THEN 5
   WHEN monetary_rank <= total_customers * 0.40 THEN 4
   WHEN monetary_rank <= total_customers * 0.60 THEN 3
   WHEN monetary_rank <= total_customers * 0.80 THEN 2
   ELSE 1 END AS m_score
FROM rfm_ranked
),
rfm_segmented AS
(
SELECT *,
CASE
WHEN r_score >= 4 AND m_score >= 4
THEN 'High-Value Recent'
WHEN r_score >= 4 AND m_score <= 2
THEN 'Recent, Low Spend'
WHEN r_score <= 2 AND m_score >= 4
THEN 'High-Value At Risk'
WHEN r_score <= 2 AND m_score <= 2
THEN 'Low-Value Lapsed'
ELSE 'Mid-Tier'
END AS customer_segment
FROM rfm_scored
)
SELECT
customer_unique_id,
last_purchase_date,
recency_days,
frequency,
monetary,
r_score,
f_score,
m_score,
r_score + f_score + m_score AS rfm_score,
customer_segment
FROM rfm_segmented
ORDER BY rfm_score DESC, monetary DESC;


/* =========================================================
   15. SELLER REVENUE CONCENTRATION
   Cumulative share of delivered sales generated by the
   highest-contributing sellers
   ========================================================= */

WITH seller_sales AS
(
SELECT oi.seller_id,
SUM(oi.price) AS delivered_sales
FROM orders o
INNER JOIN order_items oi
ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.seller_id
),
ranked_sellers AS
(
SELECT
seller_id,
delivered_sales,
ROW_NUMBER() OVER (ORDER BY delivered_sales DESC, seller_id) AS seller_rank,
COUNT(*) OVER () AS total_sellers,
SUM(delivered_sales) OVER () AS total_delivered_sales
FROM seller_sales
)
SELECT
g.seller_group,
COUNT(*) AS sellers_in_group,
SUM(r.delivered_sales) AS group_delivered_sales,
CAST(SUM(r.delivered_sales) * 100.0/ NULLIF(MAX(r.total_delivered_sales), 0)
 AS DECIMAL(10,2)) AS delivered_sales_percentage
FROM ranked_sellers r
CROSS APPLY
(
    VALUES
        ('Top 5%',  0.05, 1),
        ('Top 10%', 0.10, 2),
        ('Top 20%', 0.20, 3),
        ('Top 50%', 0.50, 4),
        ('All Sellers', 1.00, 5)
) g(seller_group, cutoff_percentage, sort_order)
WHERE r.seller_rank <= CEILING(
    r.total_sellers * g.cutoff_percentage
)
GROUP BY
g.seller_group,
g.sort_order
ORDER BY g.sort_order;


/* =========================================================
   16. LATE-DELIVERY DURATION AND REVIEW SCORES
   Counts late delivered orders by delay duration and
   compares their average review ratings
   ========================================================= */

WITH late_orders AS
(
SELECT order_id,
DATEDIFF(DAY,order_estimated_delivery_date,order_delivered_customer_date) AS delay_days
FROM orders
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL
AND DATEDIFF(DAY,order_estimated_delivery_date,order_delivered_customer_date) > 0
),
ranked_reviews AS
(
SELECT order_id, review_score,
ROW_NUMBER() OVER(PARTITION BY order_id
ORDER BY
review_creation_date DESC,
review_answer_timestamp DESC,
review_id DESC) AS rn
FROM order_reviews
),
delay_groups AS
(
SELECT
l.order_id,
l.delay_days,
CASE
WHEN l.delay_days BETWEEN 1 AND 3
THEN '1-3 Days Late'
WHEN l.delay_days BETWEEN 4 AND 7
THEN '4-7 Days Late'
WHEN l.delay_days BETWEEN 8 AND 14
THEN '8-14 Days Late'
WHEN l.delay_days >= 15
THEN '15+ Days Late'
END AS delay_bucket,
CASE
 WHEN l.delay_days BETWEEN 1 AND 3 THEN 1
 WHEN l.delay_days BETWEEN 4 AND 7 THEN 2
 WHEN l.delay_days BETWEEN 8 AND 14 THEN 3
 WHEN l.delay_days >= 15 THEN 4
END AS bucket_sort,
r.review_score
FROM late_orders l
LEFT JOIN ranked_reviews r
ON l.order_id = r.order_id
AND r.rn = 1
)
SELECT delay_bucket,
COUNT(*) AS late_orders,
COUNT(review_score) AS reviewed_orders,
CAST(AVG(CAST(review_score AS DECIMAL(10,4)))
AS DECIMAL(10,4)) AS average_review_score
FROM delay_groups
GROUP BY
delay_bucket,
bucket_sort
ORDER BY bucket_sort;
