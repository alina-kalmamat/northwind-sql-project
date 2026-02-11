/* ================================================================
NORTHWIND SALES & OPERATIONS ANALYSIS
================================================================
Author: Alina Kalmamatova
Tools: PostgreSQL, CTEs, Window Functions, CASE WHEN
Database: Northwind (Retail & Supply Chain)
*/

-- 1. General Overview: Total revenue and total number of orders
-- Goal: Get a high-level understanding of the business scale.
SELECT 
    ROUND(SUM(unit_price * quantity * (1 - discount))::numeric, 2) AS Total_Revenue,
    COUNT(DISTINCT order_id) AS Total_Orders
FROM order_details od ;

-- 2. Category Performance: Revenue by product category
-- Goal: Identify which categories are the main drivers of income.
SELECT 
    c.category_name,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::numeric, 2) AS Category_Revenue
FROM Categories c
JOIN Products p ON c.category_id = p.category_id
JOIN Order_Details od ON p.product_id = od.product_id
GROUP BY c.category_name
ORDER BY category_revenue DESC;

-- 3. Sales Dynamics: Monthly revenue and Month-over-Month (MoM) growth rate
-- Goal: Use CTEs and LAG() to track growth trends and seasonality.
WITH Monthly_Sales AS (
    SELECT 
        EXTRACT(month FROM order_date) AS Sales_Month,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS Revenue
    FROM Orders o
    JOIN order_details od ON o.order_id = od.order_id
    GROUP BY 1
)
SELECT 
    Sales_Month,
    ROUND(Revenue::numeric, 2) AS Current_Month_Revenue,
    ROUND(LAG(Revenue) OVER (ORDER BY Sales_Month)::numeric, 2) AS Previous_Month_Revenue,
    ROUND(((Revenue - LAG(Revenue) OVER (ORDER BY Sales_Month))::numeric / LAG(Revenue) OVER 
    (ORDER BY Sales_Month))::numeric 
    * 100, 2) || '%' AS Growth_Rate
FROM Monthly_Sales;

-- 4. Employee Ranking: Top performing employees by sales volume in each city
-- Goal: Apply RANK() or DENSE_RANK() with PARTITION BY to compare staff performance.
WITH Employee_Sales AS (
    SELECT 
        e.first_name || ' ' || e.last_name AS Employee_Name,
        o.ship_city,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS Total_Sales
    FROM Employees e
    JOIN Orders o ON e.employee_id = o.employee_id
    JOIN order_details od ON o.order_id = od.order_id
    WHERE o.ship_city IS NOT NULL
    GROUP BY 1, 2
)
SELECT 
    Employee_Name,
    Ship_City,
    ROUND(Total_Sales::numeric, 2) AS Sales,
    RANK() OVER (PARTITION BY Ship_City ORDER BY Total_Sales DESC) AS City_Rank
FROM Employee_Sales;

-- 5. Product Popularity: Top 5 most frequently ordered products per country
-- Goal: Use ROW_NUMBER() to identify regional product preferences.
WITH Product_Count AS (
    SELECT 
        o.ship_country,
        p.product_name,
        COUNT(od.order_id) AS Order_Count
    FROM Orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN Products p ON od.product_id = p.product_id
    GROUP BY 1, 2
)
SELECT * FROM (
    SELECT 
        ship_country,
        product_name,
        order_count,
        ROW_NUMBER() OVER (PARTITION BY ship_country ORDER BY Order_Count DESC) AS Rank
    FROM Product_Count
) WHERE Rank <= 5;

-- 6. Operational Efficiency: Logistics performance and shipment delay analysis
-- Goal: Classify delivery speed and compare individual shipping time with the country's average.
WITH Shipping_Base AS (
    SELECT 
        order_id,
        ship_country,
        order_date,
        shipped_date,
        (shipped_date - order_date) AS days_to_ship
    FROM orders
    WHERE shipped_date IS NOT NULL
)
SELECT 
    order_id,
    ship_country,
    days_to_ship,
    CASE 
        WHEN days_to_ship <= 3 THEN 'Fast'
        WHEN days_to_ship BETWEEN 4 AND 7 THEN 'Normal'
        ELSE 'Delayed'
    END AS shipping_status,
    ROUND(AVG(days_to_ship) OVER(PARTITION BY ship_country)::numeric, 2) AS country_avg_days,
    days_to_ship - ROUND(AVG(days_to_ship) OVER(PARTITION BY ship_country)::numeric, 2) AS diff_from_avg
FROM Shipping_Base
ORDER BY days_to_ship DESC;

-- 7. Customer Segmentation: Dividing customers into 4 groups based on total spending
-- Goal: Use NTILE(4) for basic RFM-style segmentation (Value-based grouping).
WITH Customer_Spending AS (
    SELECT 
        customer_id,
        SUM(unit_price * quantity * (1 - discount)) AS Total_Spent
    FROM order_details od
    JOIN Orders o ON od.order_id = o.order_id
    GROUP BY customer_id
)
SELECT 
    customer_id,
    ROUND(Total_Spent::numeric, 2) AS Total_Spent,
    NTILE(4) OVER (ORDER BY Total_Spent DESC) AS Customer_Segment 
FROM Customer_Spending;

-- 8. Supply Chain Analysis: Stock levels and Suppliers
-- Goal: Identify products with low stock and their respective suppliers.
SELECT 
    s.company_name AS supplier_name,
    p.product_name,
    p.units_in_stock
FROM products p
JOIN suppliers s ON p.supplier_id = s.supplier_id
WHERE p.units_in_stock < 10
ORDER BY p.units_in_stock ASC;

-- 9. Regional Coverage: Revenue distribution by Global Regions
-- Goal: Connect multiple tables to see sales performance on a higher geographic level.
SELECT 
    r.region_description,
    ROUND(SUM(od.unit_price * od.quantity * (1 - od.discount))::numeric, 2) AS regional_revenue
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
JOIN employees e ON o.employee_id = e.employee_id
JOIN employee_territories et ON e.employee_id = et.employee_id
JOIN territories t ON et.territory_id = t.territory_id
JOIN region r ON t.region_id = r.region_id
GROUP BY r.region_description
ORDER BY regional_revenue DESC;

-- 10. Product Variety: Number of unique products supplied by each company
-- Goal: Analyze supplier dependencies.
SELECT 
    s.company_name,
    COUNT(p.product_id) AS unique_products_count
FROM suppliers s
LEFT JOIN products p ON s.supplier_id = p.supplier_id
GROUP BY s.company_name
ORDER BY unique_products_count DESC;
