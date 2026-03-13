# 🛒 Northwind B2B Food Distributor - SQL Business Analysis

> **Domain:** B2B Specialty Food & Beverage Distribution  
> **Tool:** SQL Server (T-SQL)  
> **Dataset:** Northwind Traders (Microsoft sample database)  
> **Scope:** 830 orders · 91 customers · 77 products · Jul 1996 – May 1998

---

## 📌 Project Overview

This project transforms the classic Northwind dataset into a **real-world business analysis** for a fictional B2B specialty food distributor. Rather than treating it as a practice exercise, every query is tied to a specific business question a data or business analyst would actually be asked to answer.

The analysis covers five operational domains - revenue performance, employee productivity, customer segmentation, supply chain health, and shipping fulfilment - and surfaces **real, data-driven insights** discovered from the actual dataset.

---

## 🏢 Business Context

**Northwind Trading Co.** sources specialty food and beverage products from 29 suppliers across 16 countries and distributes them to 91 B2B customers (retailers, restaurants, food service businesses) across 21 countries.

**The business questions driving this analysis:**

- Which product categories and SKUs are growing - and which are stalling?
- Are sales reps using discounts strategically, or giving margin away for nothing?
- Who are our most valuable customers, and are we at risk of losing any?
- Which products are close to stockout, and which suppliers are causing risk?
- Is our shipping partner delivering on time, and does order size affect delays?

---

## 📁 Repository Structure

```
northwind-sql-analysis/
│
├── northwind_insights.sql       # Main analysis file - 14 queries across 5 modules
├── northwind_analysis.sql       # Practice query set (window functions, CTEs, pivots)
├── data/
│   ├── Category.csv
│   ├── Customers.csv
│   ├── Employees.csv
│   ├── EmployeeTerritories.csv
│   ├── Order_Details.csv
│   ├── Orders.csv
│   ├── Products.csv
│   ├── Region.csv
│   ├── Shippers.csv
│   ├── Suppliers.csv
│   └── Territories.csv
└── README.md
```

---

## 📊 Database Schema

The dataset contains 11 tables with the following key relationships:

```
Suppliers ──< Products >── Categories
                │
           Order Details
                │
             Orders ──── Customers
                │
             Employees ──< EmployeeTerritories >── Territories ── Region
                │
             Shippers
```

| Table | Rows | Description |
|---|---|---|
| Orders | 830 | Order headers with dates, customer, employee, shipper |
| Order Details | 2,155 | Line items with product, quantity, price, discount |
| Products | 77 | SKUs with pricing, stock levels, reorder thresholds |
| Customers | 91 | B2B customer accounts across 21 countries |
| Employees | 9 | Sales reps with hire dates and territory assignments |
| Suppliers | 29 | Vendor companies across 16 countries |
| Categories | 8 | Product category groupings |
| Territories | 53 | Sales territories mapped to regions |

---

## 🔍 Analysis Modules

### Module 1 - Revenue & Category Performance
**Questions answered:** Which categories are growing? Which SKUs carry the most risk? How are discounts affecting margin?

| Query | Technique |
|---|---|
| Category revenue with YoY growth | `CTE`, `LAG()`, `RANK() OVER()` |
| Top products with cumulative revenue share | `RANK()`, `SUM() OVER()`, running total |
| Discount depth analysis by bucket | `CASE-WHEN`, `SUM() OVER()`, conditional aggregation |
| Quarterly revenue trend with QoQ growth | `DATEPART()`, `LAG()`, `GROUP BY` |

**Key Insight:** A single product - *Côte de Blaye* - generates **$141,397 (11.2% of total revenue)**. The top 5 products together represent ~42% of all revenue. Beverages is the only category clearly accelerating into 1998; Dairy Products, the #2 category, is contracting.

---

### Module 2 - Employee Sales Performance
**Questions answered:** Who are the top performers? Is discount usage hurting or helping? Which employee covers the most territory with the least return?

| Query | Technique |
|---|---|
| Full performance scorecard | `RANK()`, `PERCENTILE_CONT()`, `CASE-WHEN` |
| Territory coverage vs. revenue output | `COUNT()`, `RANK()`, `FIRST_VALUE()` |
| Founding employee per sales region | `FIRST_VALUE() OVER (PARTITION BY ... ORDER BY HireDate)` |

**Key Insight:** Margaret Peacock leads with $232,891. Steven Buchanan is last at $68,792 - a **3.4× revenue gap**. Robert King covers the most territories (10) but ranks 6th and has the **highest average discount rate (7.36%)**. The top 3 revenue earners all have *below-average* discount rates - discount discipline and performance are positively correlated.

---

### Module 3 - Customer Segmentation
**Questions answered:** Where is revenue concentrated? Who are the highest-value customers? Which markets have the best customer quality?

| Query | Technique |
|---|---|
| Customer revenue ranking with cumulative share | `RANK()`, `NTILE()`, running `SUM() OVER()` |
| RFM segmentation (Recency, Frequency, Monetary) | `NTILE(5)`, multi-dimensional scoring, `CASE-WHEN` |
| Country-level revenue with quality ranking | `RANK()`, `SUM() OVER()`, derived metrics |

**Key Insight:** Only **1 out of 89 customers ever ordered just once** - exceptional retention. The top 3 customers (QUICK-Stop, Ernst Handel, Save-a-lot Markets) generate **$319,514 - 25.2% of all revenue**. Austria has the highest revenue per customer at **$42,668 average** despite having only 3 customers. The UK has 7 customers but the lowest revenue-per-customer of any top-10 country ($8,424).

---

### Module 4 - Supply Chain & Inventory Risk
**Questions answered:** Which products are at risk of stockout? Which suppliers are creating dependency or showing decline signals?

| Query | Technique |
|---|---|
| Product stockout risk with urgency classification | `CASE-WHEN` risk tiers, `CUME_DIST()`, `PERCENT_RANK()` |
| Supplier portfolio health | `RANK() OVER()`, discontinued rate, `SUM() OVER (PARTITION BY)` |

**Key Insight:** **18 active products are at or below their reorder level**. The most urgent case is *Nord-Ost Matjeshering*: 10 units remaining, 176 units demanded in recent months, and **zero units on order** - the only at-risk product with no reorder placed. 5 products are completely out of stock.

---

### Module 5 - Shipping & Fulfilment
**Questions answered:** Which shipper is slowest and most unreliable? Does order size drive late deliveries?

| Query | Technique |
|---|---|
| Shipper performance scorecard | `DATEDIFF()`, conditional `COUNT`, `RANK()` |
| Order size vs. delivery outcome | `CTE`, `NTILE(4)`, `CASE-WHEN`, `DATEDIFF()` |

**Key Insight:** **United Package handles the most orders (315) but is the worst performer**: 9.23 avg days to ship and 5.1% late rate. Federal Shipping is fastest (7.47 days, 3.6% late). The overall late rate is **4.6% (37 of 809 shipped orders)**. 21 orders were never shipped - these warrant investigation.

---

## 🧰 SQL Techniques Demonstrated

| Technique | Where Used |
|---|---|
| Window functions - `RANK()`, `DENSE_RANK()` | Employee ranking, product ranking, country ranking |
| `LAG()` / `LEAD()` | YoY and QoQ growth calculations |
| `FIRST_VALUE()` | First hire per region |
| `NTILE(n)` | Revenue quartiles, RFM scoring, order size tiers |
| `PERCENT_RANK()` / `CUME_DIST()` | Stock level percentile analysis |
| `PERCENTILE_CONT()` | Median calculations, performance tier thresholds |
| `SUM() OVER()` running totals | Cumulative revenue share (Pareto analysis) |
| CTEs | Multi-step calculations, RFM scoring, revenue pre-aggregation |
| Dynamic SQL + `PIVOT` | Monthly revenue by employee (variable column names) |
| `DATEDIFF()` + conditional aggregation | On-time delivery rate, days to ship |
| `CASE-WHEN` classification | Risk tiers, performance tiers, order size, discount buckets |
| `UNION ALL` | Executive KPI snapshot dashboard |

---

## 💡 Key Business Takeaways

1. **Revenue is dangerously concentrated** - one SKU drives 11.2% of revenue, and 3 customers drive 25% of revenue. Losing any of these would be material.

2. **Discount policy needs enforcement** - 6.5% of gross revenue ($88,666) is given away in discounts. The reps discounting the most are not the ones selling the most. Discounts are not driving volume.

3. **Supply chain has real gaps right now** - 18 products below reorder level, 5 out of stock, and one product with urgent demand but no reorder placed. This is an operational fire, not a forecast issue.

4. **Austria and Ireland are underserved** - both have very high revenue-per-customer metrics relative to customer count. These are expansion opportunities, not just maintenance accounts.

5. **United Package needs a performance review** - consistently slowest shipper by both average days and late rate, while handling the highest order volume.

---

## 🚀 How to Run

1. Restore the Northwind database to SQL Server, or import the CSVs in the `/data` folder into a SQL Server instance using the table structure from the schema above.
2. Open `northwind_insights.sql` in SSMS or Azure Data Studio.
3. Run each module independently - every query is self-contained with its CTE dependencies included.
4. The  `UNION ALL` executive snapshot at the top is a good starting point to validate the data loaded correctly.
