/*
Advanced_SQL.sql
Dataset: market_star_schema
MySQL version: 8.0+

This file demonstrates advanced SQL concepts:
- CTEs
- window functions
- ranking
- moving averages
- lead/lag
- stored procedures

Run this first:
USE market_star_schema;
*/

USE market_star_schema;

-- 1. Rank each customer's orders by sales
WITH customer_order_sales AS (
    SELECT
        c.Cust_id,
        c.Customer_Name,
        m.Ord_id,
        ROUND(SUM(m.Sales), 2) AS order_sales
    FROM market_fact_full AS m
    INNER JOIN cust_dimen AS c
        ON m.Cust_id = c.Cust_id
    GROUP BY c.Cust_id, c.Customer_Name, m.Ord_id
)
SELECT
    Cust_id,
    Customer_Name,
    Ord_id,
    order_sales,
    RANK() OVER (
        PARTITION BY Cust_id
        ORDER BY order_sales DESC
    ) AS order_sales_rank
FROM customer_order_sales
ORDER BY Cust_id, order_sales_rank;

-- 2. Top 3 orders per customer
WITH customer_order_sales AS (
    SELECT
        c.Cust_id,
        c.Customer_Name,
        m.Ord_id,
        ROUND(SUM(m.Sales), 2) AS order_sales
    FROM market_fact_full AS m
    INNER JOIN cust_dimen AS c
        ON m.Cust_id = c.Cust_id
    GROUP BY c.Cust_id, c.Customer_Name, m.Ord_id
),
ranked_orders AS (
    SELECT
        Cust_id,
        Customer_Name,
        Ord_id,
        order_sales,
        ROW_NUMBER() OVER (
            PARTITION BY Cust_id
            ORDER BY order_sales DESC, Ord_id
        ) AS row_num
    FROM customer_order_sales
)
SELECT
    Cust_id,
    Customer_Name,
    Ord_id,
    order_sales,
    row_num
FROM ranked_orders
WHERE row_num <= 3
ORDER BY Cust_id, row_num;

-- 3. Daily sales running total and 7-day moving average
WITH daily_sales AS (
    SELECT
        o.Order_Date,
        ROUND(SUM(m.Sales), 2) AS daily_sales,
        ROUND(SUM(m.Profit), 2) AS daily_profit
    FROM market_fact_full AS m
    INNER JOIN orders_dimen AS o
        ON m.Ord_id = o.Ord_id
    GROUP BY o.Order_Date
)
SELECT
    Order_Date,
    daily_sales,
    daily_profit,
    ROUND(
        SUM(daily_sales) OVER (
            ORDER BY Order_Date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ),
        2
    ) AS running_sales_total,
    ROUND(
        AVG(daily_sales) OVER (
            ORDER BY Order_Date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS moving_7_day_avg_sales
FROM daily_sales
ORDER BY Order_Date;

-- 4. Lead/Lag: days until the next order by customer
WITH customer_orders AS (
    SELECT
        c.Cust_id,
        c.Customer_Name,
        m.Ord_id,
        o.Order_Date
    FROM market_fact_full AS m
    INNER JOIN cust_dimen AS c
        ON m.Cust_id = c.Cust_id
    INNER JOIN orders_dimen AS o
        ON m.Ord_id = o.Ord_id
    GROUP BY c.Cust_id, c.Customer_Name, m.Ord_id, o.Order_Date
),
order_sequence AS (
    SELECT
        Cust_id,
        Customer_Name,
        Ord_id,
        Order_Date,
        LEAD(Order_Date) OVER (
            PARTITION BY Cust_id
            ORDER BY Order_Date, Ord_id
        ) AS next_order_date
    FROM customer_orders
)
SELECT
    Cust_id,
    Customer_Name,
    Ord_id,
    Order_Date,
    next_order_date,
    DATEDIFF(next_order_date, Order_Date) AS days_to_next_order
FROM order_sequence
WHERE next_order_date IS NOT NULL
ORDER BY Cust_id, Order_Date;

-- 5. Profit classification with CASE
SELECT
    Market_fact_id,
    Ord_id,
    ROUND(Sales, 2) AS sales,
    ROUND(Profit, 2) AS profit,
    CASE
        WHEN Profit < -500 THEN 'Huge Loss'
        WHEN Profit BETWEEN -500 AND 0 THEN 'Bearable Loss'
        WHEN Profit BETWEEN 0 AND 500 THEN 'Decent Profit'
        ELSE 'Great Profit'
    END AS profit_type
FROM market_fact_full
ORDER BY Profit ASC;

-- 6. Customer quartiles using NTILE
WITH customer_sales AS (
    SELECT
        c.Cust_id,
        c.Customer_Name,
        ROUND(SUM(m.Sales), 2) AS total_sales
    FROM market_fact_full AS m
    INNER JOIN cust_dimen AS c
        ON m.Cust_id = c.Cust_id
    GROUP BY c.Cust_id, c.Customer_Name
)
SELECT
    Cust_id,
    Customer_Name,
    total_sales,
    NTILE(4) OVER (ORDER BY total_sales DESC) AS sales_quartile
FROM customer_sales
ORDER BY total_sales DESC;

-- 7. Optional stored procedure: customers above a sales threshold
DROP PROCEDURE IF EXISTS get_customers_above_sales;

DELIMITER $$

CREATE PROCEDURE get_customers_above_sales(IN min_sales DECIMAL(12,2))
BEGIN
    SELECT
        c.Cust_id,
        c.Customer_Name,
        c.Customer_Segment,
        ROUND(SUM(m.Sales), 2) AS total_sales,
        ROUND(SUM(m.Profit), 2) AS total_profit
    FROM market_fact_full AS m
    INNER JOIN cust_dimen AS c
        ON m.Cust_id = c.Cust_id
    GROUP BY c.Cust_id, c.Customer_Name, c.Customer_Segment
    HAVING total_sales >= min_sales
    ORDER BY total_sales DESC;
END $$

DELIMITER ;

CALL get_customers_above_sales(10000);
