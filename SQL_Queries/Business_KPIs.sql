/*
Business_KPIs.sql
Dataset: market_star_schema
MySQL version: 8.0+

Run this first:
USE market_star_schema;
*/

USE market_star_schema;

-- 1. Overall business KPI summary
SELECT
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS profit_margin_pct,
    COUNT(DISTINCT Ord_id) AS total_orders,
    COUNT(DISTINCT Cust_id) AS total_customers,
    SUM(Order_Quantity) AS total_units_sold,
    ROUND(SUM(Sales) / NULLIF(COUNT(DISTINCT Ord_id), 0), 2) AS average_order_value
FROM market_fact_full;

-- 2. Yearly sales, profit, and year-over-year growth
WITH yearly_sales AS (
    SELECT
        YEAR(o.Order_Date) AS order_year,
        ROUND(SUM(m.Sales), 2) AS total_sales,
        ROUND(SUM(m.Profit), 2) AS total_profit
    FROM market_fact_full AS m
    INNER JOIN orders_dimen AS o
        ON m.Ord_id = o.Ord_id
    GROUP BY YEAR(o.Order_Date)
)
SELECT
    order_year,
    total_sales,
    total_profit,
    ROUND(total_sales - LAG(total_sales) OVER (ORDER BY order_year), 2) AS yoy_sales_change,
    ROUND(
        (total_sales - LAG(total_sales) OVER (ORDER BY order_year))
        / NULLIF(LAG(total_sales) OVER (ORDER BY order_year), 0) * 100,
        2
    ) AS yoy_sales_growth_pct
FROM yearly_sales
ORDER BY order_year;

-- 3. Monthly sales trend for charting
SELECT
    DATE_FORMAT(o.Order_Date, '%Y-%m') AS order_month,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    COUNT(DISTINCT m.Ord_id) AS order_count
FROM market_fact_full AS m
INNER JOIN orders_dimen AS o
    ON m.Ord_id = o.Ord_id
GROUP BY DATE_FORMAT(o.Order_Date, '%Y-%m')
ORDER BY order_month;

-- 4. Sales and profit by order priority
SELECT
    o.Order_Priority,
    COUNT(DISTINCT m.Ord_id) AS order_count,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(SUM(m.Profit) / NULLIF(SUM(m.Sales), 0) * 100, 2) AS profit_margin_pct
FROM market_fact_full AS m
INNER JOIN orders_dimen AS o
    ON m.Ord_id = o.Ord_id
GROUP BY o.Order_Priority
ORDER BY total_sales DESC;

-- 5. Top 10 states by sales
SELECT
    c.State,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(SUM(m.Profit) / NULLIF(SUM(m.Sales), 0) * 100, 2) AS profit_margin_pct,
    COUNT(DISTINCT m.Cust_id) AS customer_count
FROM market_fact_full AS m
INNER JOIN cust_dimen AS c
    ON m.Cust_id = c.Cust_id
GROUP BY c.State
ORDER BY total_sales DESC
LIMIT 10;

-- 6. Shipping mode performance
SELECT
    s.Ship_Mode,
    COUNT(DISTINCT m.Ship_id) AS shipment_count,
    ROUND(SUM(m.Shipping_Cost), 2) AS total_shipping_cost,
    ROUND(AVG(m.Shipping_Cost), 2) AS avg_shipping_cost,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit
FROM market_fact_full AS m
INNER JOIN shipping_dimen AS s
    ON m.Ship_id = s.Ship_id
GROUP BY s.Ship_Mode
ORDER BY total_shipping_cost DESC;

-- 7. Loss-making orders to investigate
SELECT
    m.Ord_id,
    o.Order_Date,
    c.Customer_Name,
    c.Customer_Segment,
    p.Product_Category,
    p.Product_Sub_Category,
    ROUND(m.Sales, 2) AS sales,
    m.Discount,
    m.Order_Quantity,
    ROUND(m.Profit, 2) AS profit,
    ROUND(m.Shipping_Cost, 2) AS shipping_cost
FROM market_fact_full AS m
INNER JOIN orders_dimen AS o
    ON m.Ord_id = o.Ord_id
INNER JOIN cust_dimen AS c
    ON m.Cust_id = c.Cust_id
INNER JOIN prod_dimen AS p
    ON m.Prod_id = p.Prod_id
WHERE m.Profit < 0
ORDER BY m.Profit ASC
LIMIT 25;
