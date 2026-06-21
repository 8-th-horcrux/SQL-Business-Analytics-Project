/*
Product_Analytics.sql
Dataset: market_star_schema
MySQL version: 8.0+

Run this first:
USE market_star_schema;
*/

USE market_star_schema;

-- 1. Product category performance
SELECT
    p.Product_Category,
    COUNT(DISTINCT p.Prod_id) AS product_count,
    COUNT(DISTINCT m.Ord_id) AS order_count,
    SUM(m.Order_Quantity) AS units_sold,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(SUM(m.Profit) / NULLIF(SUM(m.Sales), 0) * 100, 2) AS profit_margin_pct
FROM market_fact_full AS m
INNER JOIN prod_dimen AS p
    ON m.Prod_id = p.Prod_id
GROUP BY p.Product_Category
ORDER BY total_sales DESC;

-- 2. Product sub-category performance
SELECT
    p.Product_Category,
    p.Product_Sub_Category,
    COUNT(DISTINCT p.Prod_id) AS product_count,
    SUM(m.Order_Quantity) AS units_sold,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(SUM(m.Profit) / NULLIF(SUM(m.Sales), 0) * 100, 2) AS profit_margin_pct,
    RANK() OVER (ORDER BY SUM(m.Sales) DESC) AS sales_rank
FROM market_fact_full AS m
INNER JOIN prod_dimen AS p
    ON m.Prod_id = p.Prod_id
GROUP BY p.Product_Category, p.Product_Sub_Category
ORDER BY total_sales DESC;

-- 3. Products/sub-categories causing the highest losses
SELECT
    p.Product_Category,
    p.Product_Sub_Category,
    COUNT(*) AS line_items,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(AVG(m.Discount), 2) AS avg_discount,
    ROUND(AVG(m.Shipping_Cost), 2) AS avg_shipping_cost
FROM market_fact_full AS m
INNER JOIN prod_dimen AS p
    ON m.Prod_id = p.Prod_id
GROUP BY p.Product_Category, p.Product_Sub_Category
HAVING total_profit < 0
ORDER BY total_profit ASC;

-- 4. Discount band analysis
WITH discount_bands AS (
    SELECT
        p.Product_Category,
        CASE
            WHEN m.Discount = 0 THEN '0%'
            WHEN m.Discount > 0 AND m.Discount <= 0.03 THEN '1%-3%'
            WHEN m.Discount > 0.03 AND m.Discount <= 0.07 THEN '4%-7%'
            ELSE '8%+'
        END AS discount_band,
        m.Sales,
        m.Profit,
        m.Order_Quantity
    FROM market_fact_full AS m
    INNER JOIN prod_dimen AS p
        ON m.Prod_id = p.Prod_id
)
SELECT
    Product_Category,
    discount_band,
    COUNT(*) AS line_items,
    SUM(Order_Quantity) AS units_sold,
    ROUND(SUM(Sales), 2) AS total_sales,
    ROUND(SUM(Profit), 2) AS total_profit,
    ROUND(SUM(Profit) / NULLIF(SUM(Sales), 0) * 100, 2) AS profit_margin_pct
FROM discount_bands
GROUP BY Product_Category, discount_band
ORDER BY Product_Category, discount_band;

-- 5. Base margin vs actual profit
SELECT
    p.Product_Category,
    p.Product_Sub_Category,
    ROUND(AVG(m.Product_Base_Margin), 2) AS avg_base_margin,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    ROUND(SUM(m.Profit) / NULLIF(SUM(m.Sales), 0) * 100, 2) AS actual_profit_margin_pct
FROM market_fact_full AS m
INNER JOIN prod_dimen AS p
    ON m.Prod_id = p.Prod_id
GROUP BY p.Product_Category, p.Product_Sub_Category
ORDER BY actual_profit_margin_pct ASC;

-- 6. Top 10 product ids by profit
SELECT
    m.Prod_id,
    p.Product_Category,
    p.Product_Sub_Category,
    SUM(m.Order_Quantity) AS units_sold,
    ROUND(SUM(m.Sales), 2) AS total_sales,
    ROUND(SUM(m.Profit), 2) AS total_profit,
    RANK() OVER (ORDER BY SUM(m.Profit) DESC) AS profit_rank
FROM market_fact_full AS m
INNER JOIN prod_dimen AS p
    ON m.Prod_id = p.Prod_id
GROUP BY m.Prod_id, p.Product_Category, p.Product_Sub_Category
ORDER BY total_profit DESC
LIMIT 10;
