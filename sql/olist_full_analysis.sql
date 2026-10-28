/*
Olist E-Commerce SQL Analytics | PostgreSQL
Run one labelled SELECT at a time in pgAdmin (highlight query, press F5).
Product sales value is SUM(order_items.price) for delivered orders; it is not profit.
Delivery/review comparisons indicate association, not causation.
*/

-- 01. Monthly sales trend
SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS sales_month,
       COUNT(DISTINCT o.order_id) AS delivered_orders,
       ROUND(SUM(oi.price), 2) AS product_sales_value,
       ROUND(SUM(oi.freight_value), 2) AS freight_value,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS total_order_item_value
FROM public.olist_orders o
JOIN public.olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1 ORDER BY 1;

-- 02. Monthly average order value and freight per order
SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS sales_month,
       COUNT(DISTINCT o.order_id) AS delivered_orders,
       ROUND(SUM(oi.price), 2) AS product_sales_value,
       ROUND(SUM(oi.price) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value,
       ROUND(SUM(oi.freight_value) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_freight_per_order
FROM public.olist_orders o
JOIN public.olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1 ORDER BY 1;

-- 03. Delivered-order performance by purchase weekday
SELECT EXTRACT(ISODOW FROM o.order_purchase_timestamp)::INTEGER AS day_number,
       TO_CHAR(o.order_purchase_timestamp, 'FMDay') AS day_of_week,
       COUNT(DISTINCT o.order_id) AS delivered_orders,
       ROUND(SUM(oi.price), 2) AS product_sales_value,
       ROUND(SUM(oi.price) / NULLIF(COUNT(DISTINCT o.order_id), 0), 2) AS average_order_value
FROM public.olist_orders o
JOIN public.olist_order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1, 2 ORDER BY 1;

-- 04. Rank months by sales value and order volume
WITH monthly_sales AS (
    SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS sales_month,
           COUNT(DISTINCT o.order_id) AS delivered_orders,
           SUM(oi.price) AS product_sales_value
    FROM public.olist_orders o
    JOIN public.olist_order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT sales_month, delivered_orders, ROUND(product_sales_value, 2) AS product_sales_value,
       RANK() OVER (ORDER BY product_sales_value DESC) AS sales_rank,
       RANK() OVER (ORDER BY delivered_orders DESC) AS order_volume_rank
FROM monthly_sales ORDER BY sales_rank, sales_month;

-- 05. Monthly order coverage/status
SELECT DATE_TRUNC('month', order_purchase_timestamp)::DATE AS sales_month,
       COUNT(*) AS all_orders,
       COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_orders,
       CASE WHEN COUNT(*) FILTER (WHERE order_status = 'delivered') = 0 THEN 'No delivered orders'
            WHEN COUNT(*) FILTER (WHERE order_status = 'delivered') < 100 THEN 'Very low delivered-order volume'
            ELSE 'Activity recorded' END AS coverage_status
FROM public.olist_orders
GROUP BY 1 ORDER BY 1;

-- 06. Month-over-month order and sales growth, including zero-activity months
WITH monthly_sales AS (
    SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::DATE AS sales_month,
           COUNT(DISTINCT o.order_id) AS delivered_orders, SUM(oi.price) AS product_sales_value
    FROM public.olist_orders o
    JOIN public.olist_order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
), calendar AS (
    SELECT GENERATE_SERIES((SELECT MIN(sales_month) FROM monthly_sales),
                           (SELECT MAX(sales_month) FROM monthly_sales), INTERVAL '1 month')::DATE AS sales_month
), filled AS (
    SELECT c.sales_month, COALESCE(m.delivered_orders, 0) AS delivered_orders,
           COALESCE(m.product_sales_value, 0) AS product_sales_value
    FROM calendar c LEFT JOIN monthly_sales m USING (sales_month)
), lagged AS (
    SELECT *, LAG(delivered_orders) OVER (ORDER BY sales_month) AS previous_month_orders,
           LAG(product_sales_value) OVER (ORDER BY sales_month) AS previous_month_sales
    FROM filled
)
SELECT sales_month, delivered_orders, ROUND(product_sales_value, 2) AS product_sales_value,
       previous_month_orders,
       ROUND(100.0 * (delivered_orders - previous_month_orders) / NULLIF(previous_month_orders, 0), 2) AS order_growth_pct,
       ROUND(previous_month_sales, 2) AS previous_month_sales,
       ROUND(100.0 * (product_sales_value - previous_month_sales) / NULLIF(previous_month_sales, 0), 2) AS sales_growth_pct
FROM lagged ORDER BY sales_month;

-- 07. Payment method summary
SELECT payment_type, COUNT(*) AS payment_records,
       ROUND(SUM(payment_value), 2) AS total_payment_value,
       ROUND(AVG(payment_value), 2) AS average_payment
FROM public.olist_order_payments
GROUP BY payment_type ORDER BY total_payment_value DESC;

-- 08. Seller distribution by state (top 10)
SELECT seller_state, COUNT(*) AS number_of_sellers
FROM public.olist_sellers
GROUP BY seller_state ORDER BY number_of_sellers DESC LIMIT 10;

-- 09. Row-count validation for the nine imported tables
SELECT 'category_translations' AS table_name, COUNT(*) AS total_rows FROM public.product_category_name_translation
UNION ALL SELECT 'customers', COUNT(*) FROM public.olist_customers
UNION ALL SELECT 'geolocation', COUNT(*) FROM public.olist_geolocation
UNION ALL SELECT 'order_items', COUNT(*) FROM public.olist_order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM public.olist_order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM public.olist_order_reviews
UNION ALL SELECT 'orders', COUNT(*) FROM public.olist_orders
UNION ALL SELECT 'products', COUNT(*) FROM public.olist_products
UNION ALL SELECT 'sellers', COUNT(*) FROM public.olist_sellers
ORDER BY table_name;

-- 10. Top 15 product categories by delivered-order sales
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS product_category,
       COUNT(*) AS items_sold, COUNT(DISTINCT oi.order_id) AS number_of_orders,
       ROUND(SUM(oi.price), 2) AS product_sales_value, ROUND(AVG(oi.price), 2) AS average_item_price,
       ROUND(SUM(oi.freight_value), 2) AS total_freight_value
FROM public.olist_order_items oi
JOIN public.olist_orders o ON oi.order_id = o.order_id
JOIN public.olist_products p ON oi.product_id = p.product_id
LEFT JOIN public.product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY 1 ORDER BY product_sales_value DESC LIMIT 15;

-- 11. Top 20 individual products by sales value
SELECT oi.product_id, COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS product_category,
       COUNT(*) AS items_sold, COUNT(DISTINCT oi.order_id) AS number_of_orders,
       ROUND(SUM(oi.price), 2) AS product_sales_value, ROUND(AVG(oi.price), 2) AS average_item_price,
       ROUND(SUM(oi.freight_value), 2) AS total_freight_value
FROM public.olist_order_items oi
JOIN public.olist_orders o ON oi.order_id = o.order_id
JOIN public.olist_products p ON oi.product_id = p.product_id
LEFT JOIN public.product_category_name_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id, 2 ORDER BY product_sales_value DESC LIMIT 20;

-- 12. Monthly delivery performance
SELECT DATE_TRUNC('month', order_purchase_timestamp)::DATE AS purchase_month,
       COUNT(*) AS delivered_orders,
       ROUND(AVG(EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400.0)::NUMERIC, 2) AS avg_actual_delivery_days,
       ROUND(AVG(EXTRACT(EPOCH FROM (order_estimated_delivery_date - order_purchase_timestamp)) / 86400.0)::NUMERIC, 2) AS avg_estimated_delivery_days,
       COUNT(*) FILTER (WHERE order_delivered_customer_date <= order_estimated_delivery_date) AS on_time_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date > order_estimated_delivery_date) AS late_orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE order_delivered_customer_date <= order_estimated_delivery_date) / NULLIF(COUNT(*), 0), 2) AS on_time_delivery_pct
FROM public.olist_orders
WHERE order_status = 'delivered' AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL AND order_estimated_delivery_date IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- 13. Overall customer review-score distribution
SELECT review_score, COUNT(*) AS review_count,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS percentage_of_reviews
FROM public.olist_order_reviews
WHERE review_score BETWEEN 1 AND 5
GROUP BY review_score ORDER BY review_score DESC;

-- 14. Delivery performance versus customer review scores
WITH delivery_status AS (
    SELECT order_id,
           CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On time'
                ELSE 'Late' END AS delivery_performance
    FROM public.olist_orders
    WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)
SELECT d.delivery_performance, COUNT(*) AS review_count,
       ROUND(AVG(r.review_score), 2) AS average_review_score,
       COUNT(*) FILTER (WHERE r.review_score <= 2) AS low_score_reviews,
       ROUND(100.0 * COUNT(*) FILTER (WHERE r.review_score <= 2) / NULLIF(COUNT(*), 0), 2) AS low_score_percentage
FROM delivery_status d
JOIN public.olist_order_reviews r ON d.order_id = r.order_id
WHERE r.review_score BETWEEN 1 AND 5
GROUP BY d.delivery_performance ORDER BY d.delivery_performance;

-- 15. Top 20 sellers by delivered-order product sales value
SELECT s.seller_id, s.seller_state, COUNT(DISTINCT oi.order_id) AS delivered_orders,
       COUNT(*) AS items_sold, ROUND(SUM(oi.price), 2) AS product_sales_value,
       ROUND(AVG(oi.price), 2) AS average_item_price, ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
       RANK() OVER (ORDER BY SUM(oi.price) DESC) AS sales_rank
FROM public.olist_sellers s
JOIN public.olist_order_items oi ON s.seller_id = oi.seller_id
JOIN public.olist_orders o ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY s.seller_id, s.seller_state
ORDER BY product_sales_value DESC LIMIT 20;
