Create Database monday_coffee;
use monday_coffee;
-- Monday Coffee SCHEMAS

DROP TABLE IF EXISTS sales;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS city;

-- Import Rules
-- 1st import to city
-- 2nd import to products
-- 3rd import to customers
-- 4th import to sales


CREATE TABLE city
(
	city_id	INT PRIMARY KEY,
	city_name VARCHAR(15),	
	population	BIGINT,
	estimated_rent	FLOAT,
	city_rank INT
);

CREATE TABLE customers
(
	customer_id INT PRIMARY KEY,	
	customer_name VARCHAR(25),	
	city_id INT,
	CONSTRAINT fk_city FOREIGN KEY (city_id) REFERENCES city(city_id)
);


CREATE TABLE products
(
	product_id	INT PRIMARY KEY,
	product_name VARCHAR(35),	
	Price float
);


CREATE TABLE sales
(
	sale_id	INT PRIMARY KEY,
	sale_date	date,
	product_id	INT,
	customer_id	INT,
	total FLOAT,
	rating INT,
	CONSTRAINT fk_products FOREIGN KEY (product_id) REFERENCES products(product_id),
	CONSTRAINT fk_customers FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
);

-- END of SCHEMAS


-- BUSINESS PROBLEMS 
-- Monday Coffee -- Data Analysis 

SELECT * FROM city;
SELECT * FROM products;
SELECT count(*) FROM customers;
SELECT count(*)  FROM sales;

-- Reports & Data Analysis


-- Q.1 Coffee Consumers Count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?

select
city_name,
round((population*0.25)/1000000,2) as coffee_consumers_in_millions
from city
order by coffee_consumers_in_millions DESC;

-- -- Q.2
-- Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

select sum(total) as total_revenue
from sales
where quarter(sale_date)=4
and
YEAR (sale_date)=2023;

-- Q.3
-- Sales Count for Each Product
-- How many units of each coffee product have been sold?

select p.product_name, count(s.sale_id) as total_orders from  products as p 
left join
sales as s
on s.product_id =p.product_id 
group by p.product_name 
order by total_orders DESC;


-- Q.4
-- Average Sales Amount per City
-- What is the average sales amount per customer in each city?
-- now first things we need 
-- city abd total sale
-- no cx in each these city

select ci.city_name,
sum(s.total)as total_revenue,
count(distinct s.customer_id)as total_cx,
round(sum(s.total)/count(distinct s.customer_id,2)) as avg_sale_per_customer
from sales as s
join customers as c 
on s.customer_id = c.customer_id
join city as ci 
on ci.city_id=c.city_id
group by ci.city_name
order by total_revenue DESC;


-- -- Q.5
-- City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current cx, estimated coffee consumers (25%)
with city_table as 
(select city_name,
round((population*0.25)/1000000,2) as coffee_consumers
from city),
customer_table as 

(select ci.city_name,
count(distinct s.customer_id)as unique_cx
from sales as s
join customers as c 
on s.customer_id = c.customer_id
join city as ci 
on ci.city_id=c.city_id
group by ci.city_name)

select ct.city_name,
ct.coffee_consumers,
unique_cx
from city_table as ct 
join customer_table as cust
ON ct.city_name = cust.city_name;

-- -- Q6
-- Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?

SELECT *
FROM
(
    SELECT
        ci.city_name,
        p.product_name,
        COUNT(s.sale_id) AS total_orders,
        DENSE_RANK() OVER (
            PARTITION BY ci.city_name
            ORDER BY COUNT(s.sale_id) DESC
        ) AS product_rank
    FROM sales s
    JOIN products p
        ON s.product_id = p.product_id
    JOIN customers c
        ON s.customer_id = c.customer_id
    JOIN city ci
        ON c.city_id = ci.city_id
    GROUP BY ci.city_name, p.product_name
) AS t
WHERE product_rank <= 3
ORDER BY city_name, product_rank;

-- Q.7
-- Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?

SELECT
    ci.city_name,
    COUNT(DISTINCT c.customer_id) AS unique_customers
FROM city ci
JOIN customers c
    ON ci.city_id = c.city_id
JOIN sales s
    ON c.customer_id = s.customer_id
GROUP BY ci.city_name
ORDER BY unique_customers DESC;


-- -- Q.8
-- Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer
-- Conclusions

WITH city_table AS
(
    SELECT
        ci.city_name,
        SUM(s.total) AS total_revenue,
        COUNT(DISTINCT s.customer_id) AS total_cx,
        ROUND(
            SUM(s.total) / COUNT(DISTINCT s.customer_id),
            2
        ) AS avg_sale_pr_cx

    FROM sales s
    JOIN customers c
        ON s.customer_id = c.customer_id
    JOIN city ci
        ON ci.city_id = c.city_id
    GROUP BY ci.city_name
),

city_rent AS
(
    SELECT
        city_name,
        estimated_rent
    FROM city
)

SELECT
    cr.city_name,
    cr.estimated_rent,
    ct.total_cx,
    ct.avg_sale_pr_cx,
    ROUND(cr.estimated_rent / ct.total_cx, 2) AS avg_rent_per_cx
FROM city_rent cr
JOIN city_table ct
    ON cr.city_name = ct.city_name
ORDER BY ct.avg_sale_pr_cx DESC;


-- Q.9
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city

WITH monthly_sales AS
(
    SELECT
        ci.city_name,
        MONTH(s.sale_date) AS month,
        YEAR(s.sale_date) AS year,
        SUM(s.total) AS total_sale
    FROM sales s
    JOIN customers c
        ON c.customer_id = s.customer_id
    JOIN city ci
        ON ci.city_id = c.city_id
    GROUP BY ci.city_name, YEAR(s.sale_date), MONTH(s.sale_date)
),

growth_ratio AS
(
    SELECT
        city_name,
        month,
        year,
        total_sale AS cr_month_sale,
        LAG(total_sale) OVER
        (
            PARTITION BY city_name
            ORDER BY year, month
        ) AS last_month_sale
    FROM monthly_sales
)

SELECT
    city_name,
    month,
    year,
    cr_month_sale,
    last_month_sale,
    ROUND(
        ((cr_month_sale - last_month_sale) / last_month_sale) * 100,
        2
    ) AS growth_ratio
FROM growth_ratio
WHERE last_month_sale IS NOT NULL;

-- Q.10
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer

WITH city_table AS
(
    SELECT
        ci.city_name,
        SUM(s.total) AS total_revenue,
        COUNT(DISTINCT s.customer_id) AS total_cx,
        ROUND(
            SUM(s.total) / COUNT(DISTINCT s.customer_id),
            2
        ) AS avg_sale_pr_cx

    FROM sales s
    JOIN customers c
        ON s.customer_id = c.customer_id
    JOIN city ci
        ON ci.city_id = c.city_id
    GROUP BY ci.city_name
),

city_rent AS
(
    SELECT
        city_name,
        estimated_rent,
        ROUND((population * 0.25) / 1000000, 3)
            AS estimated_coffee_consumer_in_millions
    FROM city
)

SELECT
    cr.city_name,
    ct.total_revenue,
    cr.estimated_rent AS total_rent,
    ct.total_cx,
    cr.estimated_coffee_consumer_in_millions,
    ct.avg_sale_pr_cx,
    ROUND(
        cr.estimated_rent / ct.total_cx,
        2
    ) AS avg_rent_per_cx
FROM city_rent cr
JOIN city_table ct
    ON cr.city_name = ct.city_name
ORDER BY ct.total_revenue DESC
LIMIT 3;



/*
-- Recomendation
City 1: Pune
	1.Average rent per customer is very low.
	2.Highest total revenue.
	3.Average sales per customer is also high.

City 2: Delhi
	1.Highest estimated coffee consumers at 7.7 million.
	2.Highest total number of customers, which is 68.
	3.Average rent per customer is 330 (still under 500).

City 3: Jaipur
	1.Highest number of customers, which is 69.
	2.Average rent per customer is very low at 156.
	3.Average sales per customer is better at 11.6k.


