USE gdb023;
-- 1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT
	DISTINCT c.market
FROM fact_sales_monthly s
INNER JOIN dim_customer c
	ON s.customer_code = c.customer_code
WHERE c.customer LIKE 'Atliq Exclusive'
AND region = 'APAC';


-- 2. What is the percentage of unique product increase in 2021 vs. 2020? The final output contains these fields;
			-- unique_products_2020
			-- unique_products_2021
			-- percentage_chg
 
WITH
	a AS (
WITH
	x AS (
		SELECT
			COUNT(DISTINCT(p.product_code)) AS unique_product_2021
		FROM fact_sales_monthly s
		INNER JOIN dim_product p
			ON s.product_code = p.product_code
		WHERE s.fiscal_year = 2021)
SELECT
	x.unique_product_2021,
    (SELECT
			COUNT(DISTINCT(p.product_code)) AS unique_product_20
		FROM fact_sales_monthly s
		INNER JOIN dim_product p
			ON s.product_code = p.product_code
		WHERE s.fiscal_year = 2020) AS unique_product_2020
FROM x)
SELECT
	unique_product_2021,
    unique_product_2020,
    ROUND((unique_product_2021 - unique_product_2020) * 100 / unique_product_2020,2) AS percentage_chg
FROM a;

-- OR

WITH
	x AS (
		SELECT
			COUNT(DISTINCT CASE WHEN fiscal_year = 2021 THEN product_code END) AS unique_product_2021,
			COUNT(DISTINCT CASE WHEN fiscal_year = 2020 THEN product_code END) AS unique_product_2020
		FROM fact_sales_monthly)
SELECT
	*,
    ROUND((unique_product_2021 - unique_product_2020) *100 / unique_product_2020,2) AS percentage_chg
FROM x;


-- 3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. The final output contains 2 fields;
			-- segment
			-- product_count

SELECT
	segment,
    COUNT(DISTINCT product) AS product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;


-- 4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? The final output contains these fields;
			-- segment
			-- product_cnt_2020
			-- product_cnt_2021
			-- difference
            
WITH
	x AS (
		SELECT
			p.segment,
			COUNT(DISTINCT CASE WHEN s.fiscal_year = 2021 THEN s.product_code END) AS prodcut_count_2021,
			COUNT(DISTINCT CASE WHEN s.fiscal_year = 2020 THEN s.product_code END) AS prodcut_count_2020
		FROM fact_sales_monthly s
        INNER JOIN dim_product p
			ON p.product_code = s.product_code
		GROUP BY p.segment)
SELECT
	*,
    (prodcut_count_2021 - prodcut_count_2020) AS difference
FROM x
ORDER BY difference DESC;



-- 5. Get the products that have the highest and lowest manufacturing costs. The final output should contain these fields;
			-- product_code
			-- product
			-- manufacturing_cost

SELECT
	p.product_code,
    p.product,
    m.manufacturing_cost
FROM dim_product AS p
INNER JOIN fact_manufacturing_cost m
	ON p.product_code = m.product_code
WHERE m.manufacturing_cost IN (
	(SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost),
    (SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost));



-- 6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market. The final output contains these fields;
			-- customer_code
			-- customer
			-- average_discount_percentage

SELECT
	s.customer_code,
    c.customer,
    ROUND(AVG(pre.pre_invoice_discount_pct * 100),2) AS average_discount_pct
FROM fact_sales_monthly s
INNER JOIN dim_customer c
	ON c.customer_code = s.customer_code
INNER JOIN fact_pre_invoice_deductions pre
	ON s.customer_code = pre.customer_code
    AND s.fiscal_year = pre.fiscal_year
WHERE s.fiscal_year = 2021
AND c.market = 'India'
GROUP BY s.customer_code, c.customer
ORDER BY average_discount_pct DESC
LIMIT 5;



-- 7. Get the complete report of the Gross sales amount for the customer "Atliq Exclusive" for each month. This analysis helps to get an idea of low and high_performing months and take strategic decisions. The final report contains these columns;
			-- month
			-- year
			-- Gross Sales Amount
            
SELECT
    MONTH(s.date) AS month,
    s.fiscal_year,
    ROUND(SUM(g.gross_price * s.sold_quantity), 2) AS gross_sales_amount
FROM fact_sales_monthly s
INNER JOIN fact_gross_price g
    ON s.product_code = g.product_code
    AND s.fiscal_year = g.fiscal_year
INNER JOIN dim_customer c
    ON c.customer_code = s.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY MONTH(s.date), s.fiscal_year
ORDER BY s.fiscal_year, MONTH(s.date);



-- 8. In which quarter of 2020, got the maximum total_sold_quanity? The final output contains these fields sorted by the total_sold_quantity;
			-- quarter
			-- total_sold_quantity


SELECT
	CONCAT('Q', QUARTER(DATE_ADD(date, INTERVAL 4 MONTH))) AS qtr,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY qtr
ORDER BY total_sold_quantity DESC;



-- 9. Which channel halped to bring more gross sales in the fiscal year 2021 and the percentage of contribution? The final output contains these fields;
			-- channel
			-- gross_sales_mln
			-- percentage

SELECT
	c.channel,
	ROUND(SUM(g.gross_price * s.fiscal_year),2) AS gross_sales_mln
FROM fact_sales_monthly s
INNER JOIN dim_customer c
	ON s.customer_code = c.customer_code
INNER JOIN fact_gross_price g
	ON g.product_code = s.product_code
	AND g.fiscal_year = s.fiscal_year
WHERE s.fiscal_year = 2021
GROUP BY c.channel;

            
WITH
	x AS (
		SELECT
			c.channel,
			ROUND(SUM(g.gross_price * s.sold_quantity/1000000),2) AS gross_sales_mln
		FROM fact_sales_monthly s
		INNER JOIN dim_customer c
			ON s.customer_code = c.customer_code
		INNER JOIN fact_gross_price g
			ON g.product_code = s.product_code
			AND g.fiscal_year = s.fiscal_year
		WHERE s.fiscal_year = 2021
		GROUP BY c.channel)
SELECT
	*,
    ROUND(gross_sales_mln * 100 / SUM(gross_sales_mln) OVER (),2) AS pct
FROM x;



-- 10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? The final output contains these fields;
			-- division
			-- product_code
			-- product
			-- total_sold_quantity
			-- rank_order


WITH 
	x AS (
		SELECT
			p.division, p.product_code, p.product,
			SUM(sold_quantity) AS total_sold_quantity
		FROM fact_sales_monthly s
		INNER JOIN dim_product p
			ON p.product_code = s.product_code
		GROUP BY p.division, p.product_code, p.product
		ORDER BY total_sold_quantity DESC)
SELECT
	*,
    RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity) AS rnk_order
FROM x
LIMIT 3;

-- OR

WITH 
	x AS (
		SELECT
			p.division, p.product_code, p.product,
			SUM(sold_quantity) AS total_sold_quantity
		FROM fact_sales_monthly s
		INNER JOIN dim_product p
			ON p.product_code = s.product_code
		GROUP BY p.division, p.product_code, p.product
		ORDER BY total_sold_quantity DESC),
	y AS (
		SELECT
			*,
			RANK() OVER(PARTITION BY division ORDER BY total_sold_quantity) AS rnk_order
		FROM x)
SELECT
	*
FROM y
WHERE rnk_order < 4;