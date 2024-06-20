USE AdventureWorksDW2019


/*
Q1:
From FactInternetSales, DimProduct, query the list of products that satisfy:
- Orders shipped in Q1 2013
- Color is not Silver
- ProductSubCategoryKey is no 20
*/

SELECT Sales.ProductKey, EnglishProductName AS ProductName, Color AS ProductColor
, COUNT(DISTINCT SalesOrderNumber) AS No_Order
, COUNT(DISTINCT CustomerKey)      AS No_Customer
FROM FactInternetSales          AS Sales
LEFT JOIN DimProduct            AS Product     ON Product.ProductKey = Sales.ProductKey
LEFT JOIN DimProductSubcategory AS Subcategory ON Subcategory.ProductSubcategoryKey = Product.ProductSubcategoryKey
WHERE YEAR(ShipDate) = 2013 AND DATEPART(quarter, ShipDate) = 1
AND Color <> 'Silver' AND Product.ProductSubcategoryKey <> 20
GROUP BY Sales.ProductKey, EnglishProductName, Color
ORDER BY Sales.ProductKey, EnglishProductName, Color;





/*
Q2:
From FactInternetSales, FactResellerSales, DimProduct, calculate:
    - InternetTotalSales
    - ResellerTotalSales
    - NoOrder
    - NoCustomer
*/

SELECT 
	ISNULL(Internet.YearReport, Reseller.YearReport)     AS YearReport
	, ISNULL(Internet.MonthReport, Reseller.MonthReport) AS MonthReport
	, ISNULL(Internet.ProductSubcategoryName, Reseller.ProductSubcategoryName) AS ProductSubcategoryname
	, InternetTotalSales
	, InternetResellerSales
	, ISNULL(NoOrderInternet, 0) + ISNULL(NoOrderReseller, 0)       AS NoOrder
	, ISNULL(NoCustomerInternet, 0) + ISNULL(NoCustomerReseller, 0) AS NoCustomer
FROM
	(
	SELECT 
		YEAR(ShipDate) AS YearReport, FORMAT(ShipDate, 'yyyy-MM') AS MonthReport
		, EnglishProductSubcategoryName        AS ProductSubcategoryName
		, SUM(SalesAmount)                     AS InternetTotalSales
		, COUNT(DISTINCT SalesOrderLineNumber) AS NoOrderInternet
		, COUNT(DISTINCT CustomerKey)          AS NoCustomerInternet
	FROM FactInternetSales          AS InternetSales
	LEFT JOIN DimProduct            AS Product       ON Product.ProductKey = InternetSales.ProductKey
	LEFT JOIN DimProductSubcategory AS Subcategory   ON Subcategory.ProductSubcategoryKey = Product.ProductSubcategoryKey
	GROUP BY 
		YEAR(ShipDate),  FORMAT(ShipDate, 'yyyy-MM'), EnglishProductSubcategoryName
	) AS Internet
FULL OUTER JOIN
	(
	SELECT 
		YEAR(ShipDate) AS YearReport, FORMAT(ShipDate, 'yyyy-MM') AS MonthReport
		, EnglishProductSubcategoryName        AS ProductSubcategoryName
		, SUM(SalesAmount)                     AS InternetResellerSales
		, COUNT(DISTINCT SalesOrderLineNumber) AS NoOrderReseller
		, COUNT(DISTINCT ResellerKey)          AS NoCustomerReseller
	FROM FactResellerSales          AS ResellerSales
	LEFT JOIN DimProduct            AS Product       ON Product.ProductKey = ResellerSales.ProductKey
	LEFT JOIN DimProductSubcategory AS Subcategory   ON Subcategory.ProductSubcategoryKey = Product.ProductSubcategoryKey
	GROUP BY 
		YEAR(ShipDate),  FORMAT(ShipDate, 'yyyy-MM'), EnglishProductSubcategoryName
	) AS Reseller
ON Reseller.YearReport = Internet.YearReport 
AND Reseller.MonthReport = Internet.MonthReport
AND Reseller.ProductSubcategoryName = Internet.ProductSubcategoryName
ORDER BY YearReport, MonthReport, ProductSubcategoryname;



/*
Q3:
From FactInternetSales, FactResellerSales calculate:
    - IsWorkingDay
    - InternetSalesTotal
    - InternetNoOrder
    - ResellerSalesTotal
    - ResellerNoOrder
*/

SELECT 
	FORMAT(OD, 'dd-MMM-yyyy') AS OrderDate
	, IIF(
		DATEPART(dw, OD) IN (1, 7)
		OR (MONTH(OD) = 12 AND DAY(OD) >= 22)
		OR (MONTH(OD) = 1 AND DAY(OD) <= 5)
		, '1', '0'
	) AS IsWorkingDay
	,InternetSalesTotal
	,InternetNoOrder
	,ResellerSalesTotal
	,ResellerNoOrder
FROM
(
	SELECT
		ISNULL(Internet.OD, Reseller.OD) AS OD
		, ISNULL(InternetSalesTotal, 0)  AS InternetSalesTotal
		, ISNULL(InternetNoOrder, 0)     AS InternetNoOrder
		, ISNULL(ResellerSalesTotal, 0)  AS ResellerSalesTotal
		, ISNULL(ResellerNoOrder, 0)     AS ResellerNoOrder
	FROM
		(
		SELECT 
			OrderDate AS OD
			, SUM(SalesAmount)                 AS InternetSalesTotal
			, COUNT(DISTINCT SalesOrderNumber) AS InternetNoOrder
		FROM FactInternetSales
		GROUP BY OrderDate
		) AS Internet
	FULL OUTER JOIN
		(
		SELECT 
			OrderDate AS OD
			, SUM(SalesAmount)	               AS ResellerSalesTotal
			, COUNT(DISTINCT SalesOrderNumber) AS ResellerNoOrder
		FROM FactResellerSales
		GROUP BY OrderDate
		) AS Reseller
	ON Reseller.OD = Internet.OD
) AS SalesSummary
ORDER BY OD;



/*
Q4:
The management of the company wants to know the following information of each month:
    - No of orders
    - No of shipped orders
    - DiscountPercentage (TotalDiscountAmount / TotalSalesAmount)
    - ProfitMargin (TotalSalesAmount - TotalCostAmount)/TotalSalesAmount
    - SalesAmountRankingByYear
*/

SELECT *
FROM
(
	SELECT 
		ISNULL(NewOrder.Year, ShipedOrder.Year)     AS Year
		, ISNULL(NewOrder.Month, ShipedOrder.Month) AS Month
		, ISNULL(NewOrder.SalesChannel, ShipedOrder.SalesChannel) AS SalesChannel
		, #NewOrder, #ShipedOrder
		, DiscountPercentage, ProfitMargin, SalesAmountRankingByYear
	FROM
		(SELECT	
			YEAR(OrderDate) AS Year
			, FORMAT(OrderDate, 'yyyy-MM') AS Month
			, 'Internet' AS SalesChannel
			, COUNT(DISTINCT SalesOrderNumber)            AS #NewOrder
			, FORMAT(SUM(DiscountAmount)/SUM(SalesAmount), 'P') AS DiscountPercentage
			, FORMAT( (SUM(SalesAmount) - SUM(TotalProductCost))/SUM(SalesAmount) , 'P') AS ProfitMargin
			, RANK() OVER (PARTITION BY YEAR(OrderDate)
							ORDER BY SUM(SalesAmount) DESC) AS SalesAmountRankingByYear
		FROM FactInternetSales
		GROUP BY YEAR(OrderDate), FORMAT(OrderDate, 'yyyy-MM')
		) AS NewOrder
		FULL OUTER JOIN
				(SELECT 
					YEAR(ShipDate) AS Year, FORMAT(ShipDate, 'yyyy-MM') AS Month
					, 'Internet' AS SalesChannel
					, COUNT(DISTINCT SalesOrderNumber)      AS #ShipedOrder
				FROM FactInternetSales
				GROUP BY YEAR(ShipDate), FORMAT(ShipDate, 'yyyy-MM')
				) AS ShipedOrder
		ON ShipedOrder.Year = NewOrder.Year AND ShipedOrder.Month = NewOrder.Month
				UNION ALL
	SELECT
		ISNULL(NewOrder.Year, ShipedOrder.Year)     AS Year
		, ISNULL(NewOrder.Month, ShipedOrder.Month) AS Month
		, ISNULL(NewOrder.SalesChannel, ShipedOrder.SalesChannel) AS SalesChannel
		, #NewOrder, #ShipedOrder
		, DiscountPercentage, ProfitMargin, SalesAmountRankingByYear
	FROM
		(SELECT	
			YEAR(OrderDate) AS Year
			, FORMAT(OrderDate, 'yyyy-MM') AS Month
			, 'Reseller' AS SalesChannel
			, COUNT(DISTINCT SalesOrderNumber)            AS #NewOrder
			, FORMAT(SUM(DiscountAmount)/SUM(SalesAmount), 'P') AS DiscountPercentage
			, FORMAT( (SUM(SalesAmount) - SUM(TotalProductCost))/SUM(SalesAmount) , 'P') AS ProfitMargin
			, RANK() OVER (PARTITION BY YEAR(OrderDate)
							ORDER BY SUM(SalesAmount) DESC) AS SalesAmountRankingByYear
		FROM FactResellerSales
		GROUP BY YEAR(OrderDate), FORMAT(OrderDate, 'yyyy-MM')
		) AS NewOrder
		FULL OUTER JOIN
				(SELECT 
					YEAR(ShipDate) AS Year, FORMAT(ShipDate, 'yyyy-MM') AS Month
					, 'Reseller' AS SalesChannel
					, COUNT(DISTINCT SalesOrderNumber)      AS #ShipedOrder
				FROM FactResellerSales
				GROUP BY YEAR(ShipDate), FORMAT(ShipDate, 'yyyy-MM')
				) AS ShipedOrder
		ON ShipedOrder.Year = NewOrder.Year AND ShipedOrder.Month = NewOrder.Month
) AS Sales
ORDER BY Year, Month;

