CREATE TABLE public.olist_customers (
    customer_id VARCHAR(40) PRIMARY KEY,
    customer_unique_id VARCHAR(40),
    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state CHAR(2)
);

SELECT COUNT(*) AS total_customers
FROM public.olist_customers;

SELECT *
FROM public.olist_customers
LIMIT 10;


SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(*) FILTER (
        WHERE customer_city IS NULL
    ) AS missing_cities,
    COUNT(*) FILTER (
        WHERE customer_state IS NULL
    ) AS missing_states
FROM public.olist_customers;


CREATE TABLE public.olist_geolocation (
    geolocation_zip_code_prefix INTEGER,
    geolocation_lat DOUBLE PRECISION,
    geolocation_lng DOUBLE PRECISION,
    geolocation_city VARCHAR(100),
    geolocation_state CHAR(2)
);



CREATE TABLE IF NOT EXISTS public.olist_order_items (
    order_id VARCHAR(40),
    order_item_id INTEGER,
    product_id VARCHAR(40),
    seller_id VARCHAR(40),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12,2),
    freight_value NUMERIC(12,2),
    PRIMARY KEY (order_id, order_item_id)
);


SELECT
    ROUND(SUM(price), 2) AS total_product_revenue,
    ROUND(SUM(freight_value), 2) AS total_freight_charges,
    ROUND(AVG(price), 2) AS average_item_price,
    COUNT(*) AS total_items
FROM public.olist_order_items;


CREATE TABLE IF NOT EXISTS public.olist_order_payments (
    order_id VARCHAR(40),
    payment_sequential INTEGER,
    payment_type VARCHAR(30),
    payment_installments INTEGER,
    payment_value NUMERIC(12,2),
    PRIMARY KEY (order_id, payment_sequential)
);


SELECT
    payment_type,
    COUNT(*) AS payment_records,
    ROUND(SUM(payment_value), 2) AS total_payment_value,
    ROUND(AVG(payment_value), 2) AS average_payment
FROM public.olist_order_payments
GROUP BY payment_type
ORDER BY total_payment_value DESC;


CREATE TABLE IF NOT EXISTS public.olist_products (
    product_id VARCHAR(40) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER
);


CREATE TABLE IF NOT EXISTS public.olist_sellers (
    seller_id VARCHAR(40) PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state CHAR(2)
);


SELECT
    seller_state,
    COUNT(*) AS number_of_sellers
FROM public.olist_sellers
GROUP BY seller_state
ORDER BY number_of_sellers DESC
LIMIT 10;


CREATE TABLE IF NOT EXISTS public.olist_order_reviews (
    review_id VARCHAR(40),
    order_id VARCHAR(40),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);


CREATE TABLE IF NOT EXISTS public.product_category_name_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);



SELECT 'customers' AS table_name, COUNT(*) AS total_rows
FROM public.olist_customers

UNION ALL

SELECT 'geolocation', COUNT(*)
FROM public.olist_geolocation

UNION ALL

SELECT 'orders', COUNT(*)
FROM public.olist_orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM public.olist_order_items

UNION ALL

SELECT 'order_payments', COUNT(*)
FROM public.olist_order_payments

UNION ALL

SELECT 'products', COUNT(*)
FROM public.olist_products

UNION ALL

SELECT 'sellers', COUNT(*)
FROM public.olist_sellers

UNION ALL

SELECT 'order_reviews', COUNT(*)
FROM public.olist_order_reviews

UNION ALL

SELECT 'category_translations', COUNT(*)
FROM public.product_category_name_translation

ORDER BY table_name;




SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS sales_month,

    COUNT(DISTINCT o.order_id) AS delivered_orders,

    SUM(oi.price) AS product_sales_value,

    SUM(oi.freight_value) AS freight_value,

    SUM(oi.price + oi.freight_value) AS total_order_item_value

FROM public.olist_orders AS o

INNER JOIN public.olist_order_items AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY DATE_TRUNC(
    'month',
    o.order_purchase_timestamp
)

ORDER BY sales_month;




WITH monthly_sales AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS sales_month,

        COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.price) AS product_sales_value,
        SUM(oi.freight_value) AS freight_value

    FROM public.olist_orders AS o

    INNER JOIN public.olist_order_items AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE
),

calendar AS (
    SELECT GENERATE_SERIES(
        (SELECT MIN(sales_month) FROM monthly_sales),
        (SELECT MAX(sales_month) FROM monthly_sales),
        INTERVAL '1 month'
    )::DATE AS sales_month
),

filled_months AS (
    SELECT
        c.sales_month,
        COALESCE(m.delivered_orders, 0) AS delivered_orders,
        COALESCE(m.product_sales_value, 0)
            AS product_sales_value,
        COALESCE(m.freight_value, 0) AS freight_value

    FROM calendar AS c

    LEFT JOIN monthly_sales AS m
        ON c.sales_month = m.sales_month
),

growth_analysis AS (
    SELECT
        sales_month,
        delivered_orders,
        product_sales_value,
        freight_value,

        LAG(delivered_orders) OVER (
            ORDER BY sales_month
        ) AS previous_month_orders,

        LAG(product_sales_value) OVER (
            ORDER BY sales_month
        ) AS previous_month_sales

    FROM filled_months
)

SELECT
    sales_month,
    delivered_orders,

    ROUND(product_sales_value, 2) AS product_sales_value,

    previous_month_orders,

    ROUND(
        100.0 * (delivered_orders - previous_month_orders)
        / NULLIF(previous_month_orders, 0),
        2
    ) AS order_growth_pct,

    ROUND(previous_month_sales, 2) AS previous_month_sales,

    ROUND(
        100.0 * (product_sales_value - previous_month_sales)
        / NULLIF(previous_month_sales, 0),
        2
    ) AS sales_growth_pct

FROM growth_analysis

ORDER BY sales_month;



SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS sales_month,

    COUNT(DISTINCT o.order_id) AS delivered_orders,

    ROUND(SUM(oi.price), 2) AS product_sales_value,

    ROUND(
        SUM(oi.price) /
        NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS average_order_value,

    ROUND(
        SUM(oi.freight_value) /
        NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS average_freight_per_order

FROM public.olist_orders AS o

INNER JOIN public.olist_order_items AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY DATE_TRUNC(
    'month',
    o.order_purchase_timestamp
)::DATE

ORDER BY sales_month;


SELECT
    EXTRACT(
        ISODOW FROM o.order_purchase_timestamp
    ) AS day_number,

    TO_CHAR(
        o.order_purchase_timestamp,
        'FMDay'
    ) AS day_of_week,

    COUNT(DISTINCT o.order_id) AS delivered_orders,

    ROUND(SUM(oi.price), 2) AS product_sales_value,

    ROUND(
        SUM(oi.price) /
        NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS average_order_value

FROM public.olist_orders AS o

INNER JOIN public.olist_order_items AS oi
    ON o.order_id = oi.order_id

WHERE o.order_status = 'delivered'

GROUP BY
    EXTRACT(ISODOW FROM o.order_purchase_timestamp),
    TO_CHAR(o.order_purchase_timestamp, 'FMDay')

ORDER BY day_number;




WITH monthly_sales AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS sales_month,

        COUNT(DISTINCT o.order_id) AS delivered_orders,

        SUM(oi.price) AS product_sales_value

    FROM public.olist_orders AS o

    INNER JOIN public.olist_order_items AS oi
        ON o.order_id = oi.order_id

    WHERE o.order_status = 'delivered'

    GROUP BY DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE
)

SELECT
    sales_month,
    delivered_orders,
    ROUND(product_sales_value, 2) AS product_sales_value,

    RANK() OVER (
        ORDER BY product_sales_value DESC
    ) AS sales_rank,

    RANK() OVER (
        ORDER BY delivered_orders DESC
    ) AS order_volume_rank

FROM monthly_sales

ORDER BY sales_rank, sales_month;



WITH monthly_orders AS (
    SELECT
        DATE_TRUNC(
            'month',
            order_purchase_timestamp
        )::DATE AS sales_month,

        COUNT(*) FILTER (
            WHERE order_status = 'delivered'
        ) AS delivered_orders,

        COUNT(*) AS all_orders

    FROM public.olist_orders

    GROUP BY DATE_TRUNC(
        'month',
        order_purchase_timestamp
    )::DATE
)

SELECT
    sales_month,
    all_orders,
    delivered_orders,

    CASE
        WHEN delivered_orders = 0
            THEN 'No delivered orders'
        WHEN delivered_orders < 100
            THEN 'Very low delivered-order volume'
        ELSE 'Activity recorded'
    END AS coverage_status

FROM monthly_orders

ORDER BY sales_month;
