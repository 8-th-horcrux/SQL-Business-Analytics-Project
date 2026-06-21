/*
Customer_Analytics.sql
Dataset: market_star_schema
MySQL version: 8.0+

Run this first:
USE market_star_schema;
*/

USE market_star_schema;

-- 1. Customer segment performance
SELECT
    c.Customer_Segment,
    COUNT(DISTINCT c.Cust_id) AS customer_count,
    COUNT(DISTINCT m.Ord_id) AS order_count,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(SUM(m.Profit) / NULLIF(SUM(m.Sales), 0) * 100, 2) AS profit_margin_pct,
    ROUND(SUM(m.Sales) / NULLIF(COUNT(DISTINCT m.Ord_id), 0), 2) AS avg_order_value
FROM market_fact_full AS m
INNER JOIN cust_dimen AS c
    ON m.Cust_id = c.Cust_id
GROUP BY c.Customer_Segment
ORDER BY total_sales DESC;

-- 2. Top 20 customers by sales
SELECT
    c.Cust_id,
    c.Customer_Name,
    c.City,
    c.State,
    c.Customer_Segment,
    COUNT(DISTINCT m.Ord_id) AS order_count,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(SUM(m.Profit) / NULLIF(SUM(m.Sales), 0) * 100, 2) AS profit_margin_pct
FROM market_fact_full AS m
INNER JOIN cust_dimen AS c
    ON m.Cust_id = c.Cust_id
GROUP BY
    c.Cust_id,
    c.Customer_Name,
    c.City,
    c.State,
    c.Customer_Segment
ORDER BY total_sales DESC
LIMIT 20;

-- 3. Customer value tiering: Gold, Silver, Bronze
WITH customer_summary AS (
    SELECT
        c.Cust_id,
        c.Customer_Name,
        c.Customer_Segment,
        ROUND(SUM(m.Sales), 2) AS total_sales,
        ROUND(SUM(m.Profit), 2) AS total_profit,
        COUNT(DISTINCT m.Ord_id) AS order_count,
        PERCENT_RANK() OVER (ORDER BY SUM(m.Sales) DESC) AS sales_percent_rank
    FROM market_fact_full AS m
    INNER JOIN cust_dimen AS c
        ON m.Cust_id = c.Cust_id
    GROUP BY c.Cust_id, c.Customer_Name, c.Customer_Segment
)
SELECT
    Cust_id,
    Customer_Name,
    Customer_Segment,
    total_sales,
    total_profit,
    order_count,
    ROUND(sales_percent_rank, 4) AS sales_percent_rank,
    CASE
        WHEN sales_percent_rank < 0.10 THEN 'Gold'
        WHEN sales_percent_rank < 0.50 THEN 'Silver'
        ELSE 'Bronze'
    END AS customer_tier
FROM customer_summary
ORDER BY total_sales DESC;

-- 4. Customer rank by number of orders
SELECT
    c.Cust_id,
    c.Customer_Name,
    c.Customer_Segment,
    COUNT(DISTINCT m.Ord_id) AS order_count,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    RANK() OVER (ORDER BY COUNT(DISTINCT m.Ord_id) DESC) AS order_rank,
    DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT m.Ord_id) DESC) AS dense_order_rank
FROM market_fact_full AS m
INNER JOIN cust_dimen AS c
    ON m.Cust_id = c.Cust_id
GROUP BY c.Cust_id, c.Customer_Name, c.Customer_Segment
ORDER BY order_count DESC, total_sales DESC
LIMIT 25;

-- 5. Days between customer purchases
WITH customer_orders AS (
    SELECT
        c.Cust_id,
        c.Customer_Name,
        m.Ord_id,
        o.Order_Date,
        ROUND(SUM(m.Sales), 2) AS order_sales
    FROM market_fact_full AS m
    INNER JOIN cust_dimen AS c
        ON m.Cust_id = c.Cust_id
    INNER JOIN orders_dimen AS o
        ON m.Ord_id = o.Ord_id
    GROUP BY c.Cust_id, c.Customer_Name, m.Ord_id, o.Order_Date
),
customer_order_gaps AS (
    SELECT
        Cust_id,
        Customer_Name,
        Ord_id,
        Order_Date,
        order_sales,
        LAG(Order_Date) OVER (
            PARTITION BY Cust_id
            ORDER BY Order_Date, Ord_id
        ) AS previous_order_date
    FROM customer_orders
)
SELECT
    Cust_id,
    Customer_Name,
    Ord_id,
    Order_Date,
    previous_order_date,
    DATEDIFF(Order_Date, previous_order_date) AS days_since_previous_order,
    order_sales
FROM customer_order_gaps
WHERE previous_order_date IS NOT NULL
ORDER BY days_since_previous_order DESC, order_sales DESC;

-- 6. State and segment matrix
SELECT
    c.State,
    c.Customer_Segment,
    COUNT(DISTINCT c.Cust_id) AS customer_count,
    COUNT(DISTINCT m.Ord_id) AS order_count,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit
FROM market_fact_full AS m
INNER JOIN cust_dimen AS c
    ON m.Cust_id = c.Cust_id
GROUP BY c.State, c.Customer_Segment
ORDER BY c.State, total_sales DESC;
