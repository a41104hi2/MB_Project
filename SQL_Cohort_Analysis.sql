/*
Cohort Analysis is an analytical technique in focused marketing
on analyzing the behavior of a group of users/customers who share a common characteristic
over a certain period of time, thereby uncovering insights about the experience
customer experiences to improve those experiences.
*/


USE AdventureWorksDW2019;


WITH ABC AS
(
	SELECT
	CustomerKey
	, MIN(YEAR(OrderDate)) OVER(PARTITION BY CustomerKey) AS FirstYearPurchase
	, YEAR(OrderDate) AS YearPurchase
	, YEAR(OrderDate) - MIN(YEAR(OrderDate)) OVER(PARTITION BY CustomerKey) AS NoYears
	FROM FactInternetSales
	GROUP BY CustomerKey, YEAR(OrderDate)
)

SELECT
	Cohort
	, FirstPurchaseYear2010
	, FORMAT(FirstPurchaseYear2010/FirstPurchaseYear2010, 'P') AS Percentage2010
	, FORMAT(Y2011/FirstPurchaseYear2010, 'p') AS Percentage2011
	, FORMAT(Y2012/FirstPurchaseYear2010, 'P') AS Percentage2012
	, FORMAT(Y2013/FirstPurchaseYear2010, 'P') AS Percentage2013
	, FORMAT(Y2014/FirstPurchaseYear2010, 'P') AS Percentage2014
FROM
(
	SELECT
	FirstYearPurchase AS Cohort
	, CAST( SUM(IIF(NoYears=0, 1, 0)) AS float) AS FirstPurchaseYear2010
	, CAST( SUM(IIF(NoYears=1, 1, 0)) AS float) AS Y2011
	, CAST( SUM(IIF(NoYears=2, 1, 0)) AS float) AS Y2012
	, CAST( SUM(IIF(NoYears=3, 1, 0)) AS float) AS Y2013
	, CAST( SUM(IIF(NoYears=4, 1, 0)) AS float) AS Y2014
	FROM ABC
	GROUP BY FirstYearPurchase
) AS CohortAnalysis
ORDER BY Cohort