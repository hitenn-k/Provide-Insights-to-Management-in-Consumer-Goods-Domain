-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT
	market
FROM dim_customer
WHERE customer LIKE '%Atliq Exclusive%' AND region = 'APAC';


-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields,
		-- unique_products_2020
		-- unique_products_2021
		-- percentage_chg

WITH x AS (
SELECT
    COUNT(DISTINCT CASE WHEN s.fiscal_year = 2021 THEN p.product END) AS unique_product_21,
    COUNT(DISTINCT CASE WHEN s.fiscal_year = 2020 THEN p.product END) AS unique_product_20
FROM fact_sales_monthly s
INNER JOIN dim_product p
    ON s.product_code = p.product_code)
SELECT
	*,
    (unique_product_21 - unique_product_20)/unique_product_20*100 AS pct_chg
FROM x;


-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.
-- 		The final output contains 2 fields.
		-- segment,
		-- product_count

SELECT
	segment,
    COUNT(DISTINCT product) product_cnt
FROM dim_product
GROUP BY segment;


-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020?
-- 		The final output contains these fields,
		-- segment,
		-- product_cnt_2020,
		-- product_cnt_2021,
		-- difference

WITH x AS (
SELECT
	segment,
    COUNT(DISTINCT CASE WHEN s.fiscal_year = 2021 THEN product END) product_cnt_2021,
    COUNT(DISTINCT CASE WHEN s.fiscal_year = 2020 THEN product END) product_cnt_2020
FROM fact_sales_monthly s
INNER JOIN dim_product p
	ON s.product_code = p.product_code
GROUP BY segment)
SELECT
	*,
    (product_cnt_2021 - product_cnt_2020) AS difference
FROM x
ORDER BY difference DESC;


-- 5. Get the products that have the highest and lowest manufacturing costs.
-- 		The final output should contain these fields,
			-- product_code,
			-- product,
			-- manufacturing_cost

WITH x AS (
    SELECT DISTINCT
        s.product_code,
        p.product,
        mc.manufacturing_cost
    FROM fact_sales_monthly s
    INNER JOIN dim_product p
        ON s.product_code = p.product_code
    INNER JOIN fact_manufacturing_cost mc
        ON s.product_code = mc.product_code
        AND s.fiscal_year = mc.cost_year
    WHERE mc.manufacturing_cost IN (
        (SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost),
        (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost)
    )
)
SELECT *
FROM x;


-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market.
-- 		The final output contains these fields,
			-- customer_code,
			-- customer,
			-- average_discount_percentage

SELECT
	s.customer_code,
    c.customer,
    AVG(pre.pre_invoice_discount_pct) AS avg_discount_pct
FROM fact_sales_monthly s
INNER JOIN dim_customer c
	ON s.customer_code = c.customer_code
INNER JOIN fact_pre_invoice_deductions pre
	ON s.customer_code = pre.customer_code
    AND s.fiscal_year = pre.fiscal_year
WHERE s.fiscal_year = 2021
AND c.market = 'India'
GROUP BY s.customer_code, c.customer
ORDER BY avg_discount_pct DESC
LIMIT 5;


-- 7. Get the complete report of the Gross sales amount for the customer "Atliq Exclusive" for each month. This analysis helps to get an idea of low and high_performing months and take strategic decisions.
-- 		The final report contains these columns;
				-- Month,
				-- Year,
				-- Gross Sales Amount

SELECT
    DATE_FORMAT(s.date, '%M %Y') AS month_year,
    s.fiscal_year,
    ROUND(SUM(s.sold_quantity * g.gross_price),2) AS gross_sales_amount
FROM fact_sales_monthly s
INNER JOIN dim_customer c
	ON s.customer_code = c.customer_code
INNER JOIN fact_gross_price g
	ON s.product_code = g.product_code
    AND s.fiscal_year = g.fiscal_year
WHERE c.customer = 'Atliq Exclusive'
GROUP BY s.date, s.fiscal_year
ORDER BY s.date;


-- 8. In which quarter of 2020, got the maximum total_sold_quanity?
-- 		The final output contains these fields sorted by the total_sold_quantity,
-- 			quarter,
-- 			total_sold_quantity

SELECT
    CASE
        WHEN MONTH(date) IN (1,2,3) THEN 'Q1'
        WHEN MONTH(date) IN (4,5,6) THEN 'Q2'
        WHEN MONTH(date) IN (7,8,9) THEN 'Q3'
        ELSE 'Q4'
    END AS fiscal_qtr,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY fiscal_qtr
ORDER BY total_sold_quantity DESC;


-- 9. Which channel halped to bring more gross sales in the fiscal year 2021 and the percentage of contrivution?
-- 		The final output contains these fields,
			-- channel,
			-- gross_sales_mln,
			-- percentage

WITH x AS (
SELECT
	c.channel,
    ROUND(SUM((s.sold_quantity * g.gross_price)/1000000),2) AS gross_sales_mln
FROM fact_sales_monthly s
INNER JOIN dim_customer c
	ON s.customer_code = c.customer_code
INNER JOIN fact_gross_price g
	ON s.product_code = g.product_code
    AND s.fiscal_year = g.fiscal_year
WHERE s.fiscal_year = 2021
GROUP BY c.channel)
SELECT
	*,
    gross_sales_mln*100/SUM(gross_sales_mln) OVER() AS pct
FROM x
GROUP BY x.channel;


-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
-- 		The final output contains these fields,
			-- division,
			-- product_code,
			-- product,
			-- total_sold_quantity,
			-- rank_order

WITH x AS (
    SELECT
        p.division,
        s.product_code,
        p.product,
        SUM(sold_quantity) AS total_sold_quantity
    FROM fact_sales_monthly s
    INNER JOIN dim_customer c
        ON s.customer_code = c.customer_code
    INNER JOIN fact_gross_price g
        ON s.product_code = g.product_code
        AND s.fiscal_year = g.fiscal_year
    INNER JOIN dim_product p
        ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, s.product_code, p.product),
	ranked AS (
    SELECT
        x.*,
        RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity DESC) AS rank_order
    FROM x)
SELECT
	*
FROM ranked
WHERE rank_order <= 3
ORDER BY division, rank_order;