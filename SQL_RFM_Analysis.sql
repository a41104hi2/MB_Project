/*
Classify customers by three metrics
• Recency: Number of months from the date of last purchase.
• Frequency: Frequency of purchase by year.
• Monetary: Total sales.

Principles of customer scoring:
	- Active customers: Purchase within the last 1 year: 1 point
	− Top 20% customers with the highest AmountPerYear: 2 points.
	- Customers in the top 20% have the highest TotalProfit: 2 points.
	− Customers with NoPurchasePerYear > 1: 1 point.
The principle of taking the top customers: Sorting from the top down by observed value, taking the top 20%
highest value customers.

Customer classification:
	– Over 5 points: Diamond
	- 4 points: Gold
	- 3 points: Silver
	- Under 3 points: Normal
*/




USE AdventureWorksDW2019;


-- Calculate RFM
WITH 
RFM AS
(
	SELECT
		CustomerKey
		, CustomerName
		, DATEDIFF(month, LastPurchase, CurrentDate) AS Recency 
		--Number of months from first purchase date
		, NoOrder/IIF(YearsFromFirstPurchase=0, '1', YearsFromFirstPurchase) AS Frequency
		--Average number of purchases per year. (Total number of purchases/years from first purchase date)
		, TotalSalesAmount/IIF(YearsFromFirstPurchase=0, '1', YearsFromFirstPurchase) AS Monetary
		--Average annual purchase value. (Total purchase value/years from first purchase date)
		, TotalSalesAmount - TotalProductCost AS TotalProfit
	FROM
	(
		SELECT 
			Sales.CustomerKey
			, CONCAT_WS(' ', FirstName, MiddleName, LastName) AS CustomerName
			, MIN(OrderDate) AS FirstPurchase
			, DATEDIFF(year, MIN(OrderDate), (SELECT MAX(FullDateAlternateKey) FROM DimDate)) AS YearsFromFirstPurchase
			, MAX(OrderDate) AS LastPurchase
			, (SELECT MAX(FullDateAlternateKey) FROM DimDate) AS CurrentDate
			, COUNT(OrderDate)      AS NoOrder
			, SUM(SalesAmount)      AS TotalSalesAmount
			, SUM(TotalProductCost) AS TotalProductCost
		FROM FactInternetSales AS Sales    
		LEFT JOIN DimCustomer  AS Customer ON Customer.CustomerKey = Sales.CustomerKey
		GROUP BY 
			Sales.CustomerKey
			, CONCAT_WS(' ', FirstName, MiddleName, LastName)
	) AS SalesSummary
)

-- Customer Scoring and Classification
SELECT
	*
	, (CASE
		WHEN Score >= 5 THEN 'Diamond'
		WHEN Score = 4 THEN 'Gold'
		WHEN Score = 3 THEN 'Silver'
		WHEN Score < 3 THEN 'Normal'
	END) AS Customer_Segment
FROM
(
	SELECT *
		, (IIF(Recency<=12, 1, 0) 
		+ IIF(Frequency>12, 1, 0) 
		+ IIF(Monetary IN (SELECT TOP 20 PERCENT Monetary FROM RFM ORDER BY Monetary DESC), 2, 1) 
		+ IIF(TotalProfit IN (SELECT TOP 20 PERCENT TotalProfit FROM RFM ORDER BY TotalProfit DESC), 2, 1)
		) AS Score
	FROM RFM
) AS ABC
ORDER BY CustomerKey


