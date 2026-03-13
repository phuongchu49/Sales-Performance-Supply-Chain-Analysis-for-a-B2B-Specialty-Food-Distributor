-- ============================================================
--   NORTHWIND DATA — SQL BUSINESS/DATA ANALYSIS
--   Data range: Jul 1996 – May 1998  |  830 Orders  |  91 Customers
--   Total net revenue: $1,265,793  |  2,155 order lines
--
--   This file contains a KPI snapshot and 5 analytical modules, each 
--   starting with the business question, followed by the query and
--   the actual insight discovered from the data.
-- ============================================================


-- ============================================================
--  EXECUTIVE KPI SNAPSHOT
--  Run this  to validate data and get KPI measurements.
-- ============================================================

SELECT 'Net Revenue (after discounts)'  AS KPI, '$' + FORMAT(ROUND(SUM(UnitPrice * Quantity * (1 - Discount)), 0), 'N0') AS Value FROM [Order Details]
UNION ALL
SELECT 'Gross Revenue (before discounts)', '$' + FORMAT(ROUND(SUM(UnitPrice * Quantity), 0), 'N0') FROM [Order Details]
UNION ALL
SELECT 'Revenue Lost to Discounts', '$' + FORMAT(ROUND(SUM(UnitPrice * Quantity) - SUM(UnitPrice * Quantity * (1 - Discount)), 0), 'N0') FROM [Order Details]
UNION ALL
SELECT 'Discount Cost %', FORMAT(ROUND((SUM(UnitPrice * Quantity) - SUM(UnitPrice * Quantity * (1 - Discount))) / SUM(UnitPrice * Quantity) * 100, 1), 'N1') + '%' FROM [Order Details]
UNION ALL
SELECT 'Total Orders', FORMAT(COUNT(DISTINCT OrderID), 'N0') FROM Orders
UNION ALL
SELECT 'Total Order Lines', FORMAT(COUNT(*), 'N0') FROM [Order Details]
UNION ALL
SELECT 'Active Customers', FORMAT(COUNT(DISTINCT CustomerID), 'N0') FROM Orders
UNION ALL
SELECT 'Active Products', FORMAT(COUNT(*), 'N0') FROM Products WHERE Discontinued = 0
UNION ALL
SELECT 'Discontinued Products', FORMAT(COUNT(*), 'N0') FROM Products WHERE Discontinued = 1
UNION ALL
SELECT 'Suppliers', FORMAT(COUNT(*), 'N0') FROM Suppliers
UNION ALL
SELECT 'Order Lines with Discounts', FORMAT(COUNT(*), 'N0') + ' (' + FORMAT(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM [Order Details]), 'N1') + '%)' FROM [Order Details] WHERE Discount > 0
UNION ALL
SELECT 'Unshipped Orders', FORMAT(COUNT(*), 'N0') FROM Orders WHERE ShippedDate IS NULL
UNION ALL
SELECT 'Late Orders (of shipped)', FORMAT(COUNT(*), 'N0') + ' (' + FORMAT(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM Orders WHERE ShippedDate IS NOT NULL), 'N1') + '%)' FROM Orders WHERE ShippedDate > RequiredDate
UNION ALL
SELECT 'Products Below Reorder Level (active)', FORMAT(COUNT(*), 'N0') FROM Products WHERE Discontinued = 0 AND UnitsInStock <= ReorderLevel
UNION ALL
SELECT 'Products Out of Stock (active)', FORMAT(COUNT(*), 'N0') FROM Products WHERE Discontinued = 0 AND UnitsInStock = 0;

-- ============================================================
--  MODULE 1: REVENUE & CATEGORY PERFORMANCE
-- ============================================================

-- ------------------------------------------------------------
-- Q1. Which categories generate the most revenue, and are
--     they growing or stalling year over year?
--
-- INSIGHT: Beverages is the clear #1 category ($267,868),
-- followed by Dairy Products ($234,507). ALL 8 categories
-- grew from 1996 to 1997. However, going into 1998,
-- Condiments, Confections, Grains/Cereals, and Produce are
-- on pace to DECLINE vs 1997 — only Beverages is clearly
-- accelerating. Dairy, the #2 category, is also contracting
-- in 1998. This suggests a portfolio concentration risk.
-- ------------------------------------------------------------
WITH CategoryRevenue AS (
    SELECT
        c.CategoryName,
        YEAR(o.OrderDate) AS OrderYear,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Revenue
    FROM Categories c
    JOIN Products p         ON c.CategoryID = p.CategoryID
    JOIN [Order Details] od ON p.ProductID  = od.ProductID
    JOIN Orders o           ON od.OrderID   = o.OrderID
    GROUP BY c.CategoryName, YEAR(o.OrderDate)
)
SELECT
    CategoryName,
    OrderYear,
    Revenue,
    LAG(Revenue) OVER (PARTITION BY CategoryName ORDER BY OrderYear) AS PrevYearRevenue,
    ROUND(
        (Revenue - LAG(Revenue) OVER (PARTITION BY CategoryName ORDER BY OrderYear))
        / NULLIF(LAG(Revenue) OVER (PARTITION BY CategoryName ORDER BY OrderYear), 0) * 100
    , 1) AS YoY_Growth_Pct,
    RANK() OVER (PARTITION BY OrderYear ORDER BY Revenue DESC)  AS RankWithinYear
FROM CategoryRevenue
ORDER BY CategoryName, OrderYear;


-- ------------------------------------------------------------
-- Q2. Is there a single product creating over-reliance risk?
--
-- INSIGHT: YES — "Côte de Blaye" (Beverages) generates
-- $141,397 alone — that is 11.2% of ALL company revenue
-- from a single SKU. The #2 product "Thüringer Rostbratwurst"
-- generates $80,369. The top 5 products together account for
-- ~42% of total revenue. This is extreme concentration.
-- If Côte de Blaye faced a supply disruption or was
-- discontinued, the revenue impact would be severe.
-- ------------------------------------------------------------
WITH ProductRevenue AS (
    SELECT
        c.CategoryName,
        p.ProductName,
        p.UnitPrice,
        p.Discontinued,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Revenue,
        SUM(od.Quantity) AS TotalUnitsSold
    FROM Products p
    JOIN [Order Details] od ON p.ProductID  = od.ProductID
    JOIN Categories c       ON p.CategoryID = c.CategoryID
    GROUP BY c.CategoryName, p.ProductName, p.UnitPrice, p.Discontinued
),
TotalRevenue AS (
    SELECT SUM(UnitPrice * Quantity * (1 - Discount)) AS GrandTotal
    FROM [Order Details]
)
SELECT
    pr.CategoryName,
    pr.ProductName,
    pr.UnitPrice,
    pr.Revenue,
    pr.TotalUnitsSold,
    ROUND(pr.Revenue / tr.GrandTotal * 100, 2) AS PctOfTotalRevenue,
    RANK() OVER (ORDER BY pr.Revenue DESC) AS GlobalRank,
    RANK() OVER (PARTITION BY pr.CategoryName ORDER BY pr.Revenue DESC) AS RankInCategory,
    pr.Discontinued,
    -- Running cumulative share — shows the 80/20 effect clearly
    ROUND(
        SUM(pr.Revenue) OVER (ORDER BY pr.Revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / tr.GrandTotal * 100
    , 1) AS CumulativeRevenuePct
FROM ProductRevenue pr
CROSS JOIN TotalRevenue tr
ORDER BY GlobalRank;


-- ------------------------------------------------------------
-- Q3. How much revenue is lost to discounts, and which
--     discount depth is most commonly applied?
--
-- INSIGHT: Discounts cost $88,666 (6.5% of gross revenue
-- of $1,354,459). 38.9% of all order lines carry a discount.
-- The max discount is 25%. Despite the cost, the 0% discount
-- group generates the most revenue ($750,699) with the
-- LOWEST avg quantity per line (21.7 units), while
-- discounted lines average 27 units — suggesting discounts
-- are driving volume but at a margin cost.
-- No order line exceeds 25% discount (likely a policy cap).
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN od.Discount = 0  THEN '0% (No Discount)'
        WHEN od.Discount <= 0.05 THEN '1-5%'
        WHEN od.Discount <= 0.10 THEN '6-10%'
        WHEN od.Discount <= 0.15 THEN '11-15%'
        WHEN od.Discount <= 0.20 THEN '16-20%'
        ELSE '21-25%'
    END AS DiscountBucket,
    COUNT(*) AS OrderLines,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS NetRevenue,
    ROUND(SUM(od.UnitPrice * od.Quantity), 2) AS GrossRevenue,
    ROUND(SUM(od.UnitPrice * od.Quantity) - SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS RevenueForgone,
    ROUND(AVG(CAST(od.Quantity AS FLOAT)), 1) AS AvgQuantity,
    ROUND(AVG(od.Discount) * 100, 1)  AS AvgDiscountPct,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS PctOfAllLines
FROM [Order Details] od
GROUP BY
    CASE
        WHEN od.Discount = 0     THEN '0% (No Discount)'
        WHEN od.Discount <= 0.05 THEN '1-5%'
        WHEN od.Discount <= 0.10 THEN '6-10%'
        WHEN od.Discount <= 0.15 THEN '11-15%'
        WHEN od.Discount <= 0.20 THEN '16-20%'
        ELSE '21-25%'
    END
ORDER BY MIN(od.Discount);


-- ------------------------------------------------------------
-- Q4. What is the quarterly revenue trend, and when do
--     we see the strongest and weakest periods?
--
-- INSIGHT: Q4 is the strongest quarter EVERY year:
--   1996 Q4: $128,355  vs  Q3: $79,729
--   1997 Q4: $181,681  vs  Q3: $153,938
-- 1998 Q1 was the single biggest quarter on record ($298,492),
-- nearly double 1997 Q1 ($138,289) — though this likely 
-- includes some seasonality pull-forward before data ends.
-- Jan–Apr 1998 averaged $105,718/month vs $50,166 in 1997.
-- The business has more than doubled its monthly run rate.
-- ------------------------------------------------------------
SELECT
    YEAR(o.OrderDate) AS OrderYear,
    DATEPART(QUARTER, o.OrderDate) AS Quarter,
    CONCAT('Q', DATEPART(QUARTER, o.OrderDate), ' ', YEAR(o.OrderDate)) AS YearQuarter,
    COUNT(DISTINCT o.OrderID)  AS OrderCount,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Revenue,
    ROUND(AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS AvgLineRevenue,
    -- QoQ growth
    ROUND(
        (SUM(od.UnitPrice * od.Quantity * (1 - od.Discount))
         - LAG(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)))
             OVER (ORDER BY YEAR(o.OrderDate), DATEPART(QUARTER, o.OrderDate)))
        / NULLIF(LAG(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)))
             OVER (ORDER BY YEAR(o.OrderDate), DATEPART(QUARTER, o.OrderDate)), 0) * 100
    , 1) AS QoQ_Growth_Pct
FROM Orders o
JOIN [Order Details] od ON o.OrderID = od.OrderID
GROUP BY YEAR(o.OrderDate), DATEPART(QUARTER, o.OrderDate)
ORDER BY OrderYear, Quarter;


-- ============================================================
--  MODULE 2: EMPLOYEE SALES PERFORMANCE
-- ============================================================

-- ------------------------------------------------------------
-- Q5. Which employees are top performers vs. underperformers,
--     and is there a correlation between discount usage
--     and sales performance?
--
-- INSIGHT: Margaret Peacock leads with $232,891 (156 orders).
-- Steven Buchanan is last at $68,792 (42 orders) — a 3.4x gap.
-- CRITICAL ANOMALY: Robert King ranks 6th in revenue but has
-- the HIGHEST average discount rate (7.36%), suggesting he is
-- offering unnecessary discounts without driving proportional
-- volume. Buchanan and Dodsworth (bottom 2 in revenue) also 
-- have above-average discount rates — discounting their way 
-- to smaller deals, not larger ones.
-- In contrast, the top 3 earners (Peacock, Leverling, Davolio)
-- all have BELOW-average discount rates (<5.6% vs 5.8% avg).
-- Discount discipline correlates positively with revenue rank.
-- ------------------------------------------------------------
WITH EmployeeStats AS (
    SELECT
        e.EmployeeID,
        e.FirstName + ' ' + e.LastName AS EmployeeName,
        e.Title,
        DATEDIFF(YEAR, e.HireDate, GETDATE())AS YearsEmployed,
        COUNT(DISTINCT o.OrderID)  AS TotalOrders,
        SUM(od.Quantity) AS TotalUnitsSold,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS TotalRevenue,
        ROUND(AVG(od.Discount) * 100, 2)  AS AvgDiscountPct,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount))
              / NULLIF(COUNT(DISTINCT o.OrderID), 0), 2) AS RevenuePerOrder
    FROM Employees e
    JOIN Orders o           ON e.EmployeeID = o.EmployeeID
    JOIN [Order Details] od ON o.OrderID    = od.OrderID
    GROUP BY e.EmployeeID, e.FirstName, e.LastName, e.Title, e.HireDate
)
SELECT
    EmployeeName,
    Title,
    TotalOrders,
    TotalUnitsSold,
    TotalRevenue,
    AvgDiscountPct,
    RevenuePerOrder,
    RANK() OVER (ORDER BY TotalRevenue DESC) AS RevenueRank,
    RANK() OVER (ORDER BY AvgDiscountPct DESC)  AS DiscountRank,   -- higher = gives more discounts
    RANK() OVER (ORDER BY RevenuePerOrder DESC) AS EfficiencyRank,
    CASE
        WHEN TotalRevenue = MAX(TotalRevenue) OVER () THEN 'Top Performer'
        WHEN TotalRevenue >= PERCENTILE_CONT(0.75)
             WITHIN GROUP (ORDER BY TotalRevenue) OVER () THEN 'High Performer'
        WHEN TotalRevenue <= PERCENTILE_CONT(0.25)
             WITHIN GROUP (ORDER BY TotalRevenue) OVER () THEN 'Needs Coaching'
        ELSE 'Average'
    END AS PerformanceTier,
    -- Flag: giving high discounts AND low revenue = red flag
    CASE
        WHEN AvgDiscountPct > 6.0
         AND TotalRevenue < AVG(TotalRevenue) OVER ()  THEN 'REVIEW: High Discount + Low Revenue'
        WHEN AvgDiscountPct > 6.0  THEN 'Monitor: High Discount Usage'
        ELSE 'OK'
    END AS DiscountFlag
FROM EmployeeStats
ORDER BY RevenueRank;


-- ------------------------------------------------------------
-- Q6. Which employee covers the most territory but is not
--     converting it into proportional revenue?
--
-- INSIGHT: Robert King covers 10 territories (all Western),
-- the most of any single employee. Yet he ranks 6th in revenue.
-- Andrew Fuller covers 7 Eastern territories and ranks 4th.
-- Nancy Davolio covers only 2 Eastern territories but ranks
-- 3rd — extremely high revenue per territory ($96,054).
-- This suggests territory size is not the driver of performance:
-- conversion quality and customer relationships matter more.
-- ------------------------------------------------------------
SELECT
    e.EmployeeID,
    e.FirstName + ' ' + e.LastName  AS EmployeeName,
    e.Title,
    COUNT(et.TerritoryID)  AS TerritoryCount,
    r.RegionDescription   AS PrimaryRegion,
    RANK() OVER (ORDER BY COUNT(et.TerritoryID) DESC)  AS TerritoryRank,
    FIRST_VALUE(e.HireDate) OVER (
        PARTITION BY r.RegionID ORDER BY e.HireDate
    )  AS EarliestHireInRegion
FROM Employees e
JOIN EmployeeTerritories et ON e.EmployeeID   = et.EmployeeID
JOIN Territories t          ON et.TerritoryID = t.TerritoryID
JOIN Region r               ON t.RegionID     = r.RegionID
GROUP BY e.EmployeeID, e.FirstName, e.LastName, e.Title, r.RegionID, r.RegionDescription, e.HireDate
ORDER BY TerritoryCount DESC;


-- ------------------------------------------------------------
-- Q7. Who was the first employee hired in each region,
--     and how does tenure correlate with revenue today?
--
-- INSIGHT: Each region was founded by a different early hire.
-- The Eastern region's founding reps (hired 1992) include
-- Andrew Fuller (VP) and Nancy Davolio — both still strong
-- performers, suggesting early-hire relationship capital
-- translates into long-term revenue.
-- ------------------------------------------------------------
SELECT DISTINCT
    r.RegionDescription,
    FIRST_VALUE(e.FirstName + ' ' + e.LastName)
        OVER (PARTITION BY r.RegionID ORDER BY e.HireDate) AS FoundingEmployee,
    FIRST_VALUE(e.Title)
        OVER (PARTITION BY r.RegionID ORDER BY e.HireDate) AS Title,
    FIRST_VALUE(CONVERT(DATE, e.HireDate))
        OVER (PARTITION BY r.RegionID ORDER BY e.HireDate) AS HireDate
FROM Employees e
JOIN EmployeeTerritories et ON e.EmployeeID   = et.EmployeeID
JOIN Territories t ON et.TerritoryID = t.TerritoryID
JOIN Region r ON t.RegionID     = r.RegionID
ORDER BY r.RegionDescription;


-- ============================================================
--  MODULE 3: CUSTOMER SEGMENTATION
-- ============================================================

-- ------------------------------------------------------------
-- Q8. Which customers drive the most revenue, and how
--     concentrated is our customer base?
--
-- INSIGHT: The top 3 customers (QUICK-Stop, Ernst Handel,
-- Save-a-lot Markets) together generate $319,514 — that is
-- 25.2% of total company revenue. The top 10 customers
-- account for roughly 50% of revenue. Only 1 customer out
-- of 89 who ordered placed just a single order — indicating
-- extremely strong retention. The median reorder gap is 35
-- days, meaning loyal customers reorder every ~5 weeks.
-- QUICK-Stop alone represents 8.7% of total revenue from
-- 28 orders — the highest-frequency, highest-value customer.
-- ------------------------------------------------------------
WITH CustomerRevenue AS (
    SELECT
        cs.CustomerID,
        cs.CompanyName,
        cs.Country,
        cs.Region,
        COUNT(DISTINCT o.OrderID) AS TotalOrders,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Revenue,
        MIN(CONVERT(DATE, o.OrderDate)) AS FirstOrder,
        MAX(CONVERT(DATE, o.OrderDate)) AS LastOrder,
        DATEDIFF(DAY, MIN(o.OrderDate), MAX(o.OrderDate)) AS CustomerLifespanDays
    FROM Customers cs
    JOIN Orders o ON cs.CustomerID = o.CustomerID
    JOIN [Order Details] od ON o.OrderID     = od.OrderID
    GROUP BY cs.CustomerID, cs.CompanyName, cs.Country, cs.Region
),
TotalRev AS (
    SELECT SUM(UnitPrice * Quantity * (1 - Discount)) AS GrandTotal
    FROM [Order Details]
)
SELECT
    cr.CustomerID,
    cr.CompanyName,
    cr.Country,
    cr.TotalOrders,
    cr.Revenue,
    cr.FirstOrder,
    cr.LastOrder,
    cr.CustomerLifespanDays,
    ROUND(cr.Revenue / NULLIF(cr.TotalOrders, 0), 2) AS RevenuePerOrder,
    ROUND(cr.Revenue / tr.GrandTotal * 100, 2) AS PctOfTotalRevenue,
    RANK() OVER (ORDER BY cr.Revenue DESC) AS RevenueRank,
    -- Cumulative % — shows how quickly revenue concentrates in top customers
    ROUND(
        SUM(cr.Revenue) OVER (ORDER BY cr.Revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / tr.GrandTotal * 100
    , 1) AS CumulativePct,
    NTILE(5) OVER (ORDER BY cr.Revenue DESC) AS RevenueQuintile  -- 1 = top 20%
FROM CustomerRevenue cr
CROSS JOIN TotalRev tr
ORDER BY RevenueRank;


-- ------------------------------------------------------------
-- Q9. Apply RFM scoring to segment all customers into
--     actionable tiers.
--
-- INSIGHT: Using NTILE(5) to score Recency, Frequency, and
-- Monetary value (1=best, 5=worst for R; 5=best for F&M):
-- ~20 customers qualify as Champions (RFM Total 3–5).
-- The "At Risk" segment (ordered frequently before but
-- recently quiet) includes several Germany/Austria accounts —
-- high-value markets worth a targeted win-back campaign.
-- Austria punches above its weight: 3 customers but
-- $128,004 in revenue — the highest revenue per customer
-- of any country ($42,668 avg vs $13,879 global avg).
-- ------------------------------------------------------------
WITH CustomerBase AS (
    SELECT
        cs.CustomerID,
        cs.CompanyName,
        cs.Country,
        COUNT(DISTINCT o.OrderID) AS Frequency,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Monetary,
        MAX(o.OrderDate)  AS LastOrder,
        DATEDIFF(DAY, MAX(o.OrderDate), (SELECT MAX(OrderDate) FROM Orders)) AS Recency  -- days since last order
    FROM Customers cs
    JOIN Orders o           ON cs.CustomerID = o.CustomerID
    JOIN [Order Details] od ON o.OrderID     = od.OrderID
    GROUP BY cs.CustomerID, cs.CompanyName, cs.Country
),
RFMScores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY Recency ASC)    AS R_Score,  -- less days = more recent = score 1 (best)
        NTILE(5) OVER (ORDER BY Frequency DESC) AS F_Score,  -- more orders = score 1 (best)
        NTILE(5) OVER (ORDER BY Monetary DESC)  AS M_Score   -- more revenue = score 1 (best)
    FROM CustomerBase
)
SELECT
    CustomerID,
    CompanyName,
    Country,
    Recency AS DaysSinceLastOrder,
    Frequency,
    Monetary,
    R_Score, F_Score, M_Score,
    R_Score + F_Score + M_Score AS RFM_Total,
    CASE
        WHEN R_Score + F_Score + M_Score <= 5  THEN 'Champion'
        WHEN R_Score + F_Score + M_Score <= 8  THEN 'Loyal'
        WHEN R_Score <= 2 AND F_Score >= 4  THEN 'At Risk'
        WHEN R_Score + F_Score + M_Score <= 11 THEN 'Potential'
        ELSE 'Needs Attention'
    END AS CustomerSegment
FROM RFMScores
ORDER BY RFM_Total ASC;


-- ------------------------------------------------------------
-- Q10. Which countries generate the most revenue, and
--      which are the highest QUALITY markets (revenue per
--      customer)?
--
-- INSIGHT: USA #1 ($245,585) and Germany #2 ($230,285) together
-- = 37.5% of all revenue. BUT Austria is the highest-quality
-- market: 3 customers averaging $42,668 each.
-- Brazil ranks 4th in total revenue ($106,926) with only
-- 9 customers — strong per-customer value ($11,881).
-- The UK has 7 customers but only $58,971 — the lowest
-- revenue-per-customer among top-10 countries ($8,424).
-- This signals an expansion opportunity in high-quality
-- markets (Austria, Ireland) and a review needed for UK.
-- ------------------------------------------------------------
WITH CountryMetrics AS (
    SELECT
        cs.Country,
        COUNT(DISTINCT cs.CustomerID) AS Customers,
        COUNT(DISTINCT o.OrderID) AS Orders,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS Revenue
    FROM Customers cs
    JOIN Orders o           ON cs.CustomerID = o.CustomerID
    JOIN [Order Details] od ON o.OrderID     = od.OrderID
    GROUP BY cs.Country
)
SELECT
    Country,
    Customers,
    Orders,
    Revenue,
    ROUND(Revenue / Customers, 2)  AS RevenuePerCustomer,
    ROUND(Revenue / Orders, 2)   AS RevenuePerOrder,
    RANK() OVER (ORDER BY Revenue DESC)  AS RevenueRank,
    RANK() OVER (ORDER BY Revenue / Customers DESC) AS QualityRank,
    ROUND(Revenue / SUM(Revenue) OVER () * 100, 1) AS PctOfTotal,
    ROUND(
        SUM(Revenue) OVER (ORDER BY Revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / SUM(Revenue) OVER () * 100, 1) AS CumulativePct
FROM CountryMetrics
ORDER BY RevenueRank;


-- ============================================================
--  MODULE 4: SUPPLY CHAIN & INVENTORY RISK
-- ============================================================

-- ------------------------------------------------------------
-- Q11. Which products are most at risk of stockout, and
--      how serious is the demand pressure on them?
--
-- INSIGHT: 5 products are completely OUT OF STOCK.
-- 18 active (non-discontinued) products are at or below
-- their reorder level. Most alarming:
-- • "Chang" — 17 units left, 334 units demanded in recent
--   months, reorder level 25. Only 40 on order.
-- • "Sir Rodney's Scones" — 3 units left, 311 recent units
--   demanded. Critical.
-- • "Gorgonzola Telino" — 0 in stock, 70 on order,
--   reorder level 20. Already sold out.
-- • "Nord-Ost Matjeshering" — 10 units left, 176 recent
--   demand, and ZERO on order. Most urgent gap.
-- ------------------------------------------------------------
SELECT
    s.CompanyName  AS Supplier,
    s.Country   AS SupplierCountry,
    p.ProductName,
    c.CategoryName,
    p.UnitPrice,
    p.UnitsInStock,
    p.UnitsOnOrder,
    p.ReorderLevel,
    p.UnitsInStock - p.ReorderLevel   AS StockSurplusOrDeficit,
    CASE
        WHEN p.UnitsInStock = 0  THEN 'OUT OF STOCK'
        WHEN p.UnitsInStock < p.ReorderLevel AND p.UnitsOnOrder = 0   THEN 'CRITICAL — No Reorder Placed'
        WHEN p.UnitsInStock < p.ReorderLevel   THEN 'BELOW REORDER — Order Pending'
        WHEN p.UnitsInStock < p.ReorderLevel * 1.5   THEN 'LOW — Monitor Closely'
        ELSE  'OK'
    END AS StockStatus,
    CUME_DIST() OVER (ORDER BY p.UnitsInStock) AS StockCumDist,  -- <0.30 = bottom 30% of stock levels
    PERCENT_RANK() OVER (ORDER BY p.UnitsInStock) AS StockPercentile
FROM Products p
JOIN Suppliers s  ON p.SupplierID = s.SupplierID
JOIN Categories c ON p.CategoryID = c.CategoryID
WHERE p.Discontinued = 0
ORDER BY p.UnitsInStock ASC, p.ReorderLevel DESC;


-- ------------------------------------------------------------
-- Q12. Which suppliers carry the most inventory weight,
--      and which suppliers have a high discontinued rate
--      (a potential relationship quality signal)?
--
-- INSIGHT: Plutzer Lebensmittelgroßmärkte AG (Germany) and
-- Pavlova, Ltd. (Australia) supply the most SKUs (5 each).
-- Two suppliers have discontinued ALL of their products —
-- a red flag for relationship health or category exit.
-- The 29 suppliers across 16 countries create geographic
-- diversification, but 4 suppliers provide only 1 active
-- product each — low strategic value relationships.
-- ------------------------------------------------------------
SELECT
    s.CompanyName,
    s.Country,
    s.ContactName,
    COUNT(p.ProductID) AS TotalProducts,
    SUM(CASE WHEN p.Discontinued = 0 THEN 1 ELSE 0 END) AS ActiveProducts,
    SUM(CASE WHEN p.Discontinued = 1 THEN 1 ELSE 0 END) AS DiscontinuedProducts,
    ROUND(AVG(p.UnitPrice), 2)  AS AvgUnitPrice,
    SUM(p.UnitsInStock)  AS TotalUnitsInStock,
    SUM(p.UnitsOnOrder)  AS TotalUnitsOnOrder,
    RANK() OVER (ORDER BY SUM(p.UnitsInStock) DESC)  AS StockRank,
    RANK() OVER (ORDER BY COUNT(p.ProductID) DESC)  AS PortfolioSizeRank,
    -- Discontinued ratio: high = declining supplier relationship
    ROUND(
        SUM(CASE WHEN p.Discontinued = 1 THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(p.ProductID), 0) * 100
    , 0)   AS DiscontinuedRatePct,
    SUM(p.UnitsInStock) OVER (PARTITION BY s.Country) AS TotalStockByCountry
FROM Suppliers s
JOIN Products p ON s.SupplierID = p.SupplierID
GROUP BY s.SupplierID, s.CompanyName, s.Country, s.ContactName
ORDER BY TotalProducts DESC, ActiveProducts DESC;


-- ============================================================
--  MODULE 5: SHIPPING & ORDER FULFILMENT
-- ============================================================

-- ------------------------------------------------------------
-- Q13. Which shipper is underperforming on delivery speed
--      and on-time rate?
--
-- INSIGHT: United Package handles the most orders (315) but
-- has the worst performance: 9.23 avg days to ship and
-- a 5.1% late rate (16 late orders). Federal Shipping is
-- the best performer: 7.47 avg days, only 3.6% late.
-- Speedy Express — despite its name — averages 8.57 days,
-- slightly faster than United Package but still behind Federal.
-- The overall late rate is 4.6% (37/809 shipped orders).
-- 21 orders were never shipped — these should be investigated
-- for cancellations or fulfilment failures.
-- ------------------------------------------------------------
SELECT
    sh.CompanyName  AS Shipper,
    COUNT(o.OrderID) AS TotalOrders,
    SUM(CASE WHEN o.ShippedDate IS NOT NULL     THEN 1 ELSE 0 END) AS ShippedOrders,
    SUM(CASE WHEN o.ShippedDate IS NULL         THEN 1 ELSE 0 END) AS UnshippedOrders,
    SUM(CASE WHEN o.ShippedDate <= o.RequiredDate THEN 1 ELSE 0 END) AS OnTimeOrders,
    SUM(CASE WHEN o.ShippedDate > o.RequiredDate  THEN 1 ELSE 0 END) AS LateOrders,
    ROUND(
        SUM(CASE WHEN o.ShippedDate <= o.RequiredDate THEN 1.0 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN o.ShippedDate IS NOT NULL THEN 1 ELSE 0 END), 0) * 100, 1) AS OnTimePct,
    ROUND(AVG(DATEDIFF(DAY, o.OrderDate, o.ShippedDate)), 2) AS AvgDaysToShip,
    ROUND(MIN(DATEDIFF(DAY, o.OrderDate, o.ShippedDate)), 0) AS MinDaysToShip,
    ROUND(MAX(DATEDIFF(DAY, o.OrderDate, o.ShippedDate)), 0) AS MaxDaysToShip,
    ROUND(AVG(o.Freight), 2) AS AvgFreightCharge,
    RANK() OVER (ORDER BY AVG(DATEDIFF(DAY, o.OrderDate, o.ShippedDate))) AS SpeedRank  -- 1 = fastest
FROM Orders o
JOIN Shippers sh ON o.ShipVia = sh.ShipperID
GROUP BY sh.ShipperID, sh.CompanyName
ORDER BY SpeedRank;


-- ------------------------------------------------------------
-- Q14. Are larger orders more likely to be delivered late?
--      Does freight cost scale appropriately with order size?
--
-- INSIGHT: Average order value is $1,525 (mean) but the
-- median is only $943 — right-skewed by a handful of very
-- large orders (max: $16,387). Only 3 orders have freight
-- costs exceeding 20% of order value — the freight structure
-- is generally fair. Classifying orders into Small/Medium/
-- Large reveals that Large orders have a slightly higher late
-- rate, likely due to United Package handling more bulk orders.
-- ------------------------------------------------------------
WITH OrderTotals AS (
    SELECT
        od.OrderID,
        SUM(od.Quantity)  AS TotalQuantity,
        ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS OrderRevenue,
        COUNT(DISTINCT od.ProductID) AS UniqueProducts
    FROM [Order Details] od
    GROUP BY od.OrderID
)
SELECT
    o.OrderID,
    cs.CompanyName,
    cs.Country,
    sh.CompanyName AS Shipper,
    ot.TotalQuantity,
    ot.OrderRevenue,
    ot.UniqueProducts,
    o.Freight,
    ROUND(o.Freight / NULLIF(ot.OrderRevenue, 0) * 100, 1) AS FreightPct,
    CASE
        WHEN ot.TotalQuantity <= 20 THEN 'Small  (≤20 units)'
        WHEN ot.TotalQuantity <= 50 THEN 'Medium (21-50 units)'
        ELSE 'Large  (>50 units)'
    END AS OrderSizeCategory,
    NTILE(4) OVER (ORDER BY ot.OrderRevenue) AS RevenueQuartile,
    DATEDIFF(DAY, o.OrderDate, o.ShippedDate) AS DaysToShip,
    CASE
        WHEN o.ShippedDate IS NULL THEN 'Not Yet Shipped'
        WHEN o.ShippedDate <= o.RequiredDate THEN 'On Time'
        ELSE 'Late'
    END AS DeliveryStatus
FROM Orders o
JOIN Customers cs    ON o.CustomerID  = cs.CustomerID
JOIN Shippers sh     ON o.ShipVia     = sh.ShipperID
JOIN OrderTotals ot  ON o.OrderID     = ot.OrderID
ORDER BY ot.OrderRevenue DESC;

