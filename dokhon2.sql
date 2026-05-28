SELECT * FROM [dbo].[Branches]

SELECT * FROM [dbo].[Customers]

SELECT * FROM [dbo].[Employees]

SELECT * FROM [dbo].[Products]

SELECT * FROM [dbo].[Saless]




-- 1. Create the corrected analytical table matching your exact data types
CREATE TABLE dbo.Fact_Perfume_Sales (
    SaleID INT,
    SaleDate DATE,
    YearMonth VARCHAR(7),
    DayOfWeek VARCHAR(50),
    ProductName NVARCHAR(50),
    Brand NVARCHAR(50),
    Category NVARCHAR(50),
    CostPrice SMALLINT, -- Matched from Products schema
    UnitPrice SMALLINT, -- Matched from Saless schema
    Qty TINYINT,        -- Matched from Saless schema
    Discount TINYINT,   -- Matched from Saless schema
    TotalRevenue INT,   -- Calculated using integer arithmetic
    TotalCost INT,      -- Calculated using integer arithmetic
    NetProfit INT,      -- Calculated using integer arithmetic
    CustomerName NVARCHAR(50),
    CustomerGender NVARCHAR(50),
    CustomerAge TINYINT, -- Matched from Customers schema
    CustomerCity NVARCHAR(50),
    LoyaltyLevel NVARCHAR(50),
    EmployeeName NVARCHAR(50),
    EmployeeDepartment NVARCHAR(50),
    BranchCity NVARCHAR(50),
    Region NVARCHAR(50),
    MonthlyTarget INT,  -- Matched from Branches schema
    Rating FLOAT        -- Matched from Saless schema
);

-- 2. Clean and Insert data using exact matching columns
INSERT INTO dbo.Fact_Perfume_Sales
SELECT 
    s.SaleID,
    CAST(s.Date AS DATE) AS SaleDate,
    LEFT(CONVERT(VARCHAR, s.Date, 23), 7) AS YearMonth,
    DATENAME(dw, s.Date) AS DayOfWeek,
    TRIM(p.ProductName),
    TRIM(p.Brand),
    TRIM(p.Category),
    p.CostPrice,
    s.UnitPrice,
    s.Qty,
    s.Discount,
    -- Exact calculation based on your integer types
    (s.Qty * s.UnitPrice) - s.Discount AS TotalRevenue,
    (s.Qty * p.CostPrice) AS TotalCost,
    ((s.Qty * s.UnitPrice) - s.Discount) - (s.Qty * p.CostPrice) AS NetProfit,
    TRIM(c.CustomerName),
    TRIM(c.Gender),
    c.Age,
    TRIM(c.City) AS CustomerCity, -- Corrected column name from schema
    TRIM(c.LoyaltyLevel),
    TRIM(e.EmployeeName),
    TRIM(e.Department),
    TRIM(b.City) AS BranchCity,   -- Corrected column name from schema
    TRIM(b.Region),
    b.MonthlyTarget,
    s.Rating
FROM dbo.Saless s
LEFT JOIN dbo.Products p ON s.ProductID = p.ProductID
LEFT JOIN dbo.Customers c ON s.CustomerID = c.CustomerID
LEFT JOIN dbo.Employees e ON s.EmployeeID = e.EmployeeID
LEFT JOIN dbo.Branches b ON s.BranchID = b.BranchID
WHERE s.SaleID IS NOT NULL;


SELECT 
    BranchCity,
    Region,
    FORMAT(SUM(TotalRevenue), 'N0') AS Total_Revenue,
    FORMAT(SUM(NetProfit), 'N0') AS Total_Profit,
    COUNT(SaleID) AS Total_Transactions,
    ROUND((SUM(CAST(TotalRevenue AS DECIMAL(18,2))) / AVG(MonthlyTarget)) * 100, 2) AS Target_Achievement_Percentage
FROM dbo.Fact_Perfume_Sales
GROUP BY BranchCity, Region
ORDER BY SUM(NetProfit) DESC;


SELECT 
    Brand,
    Category,
    SUM(CAST(Qty AS INT)) AS Total_Units_Sold,
    FORMAT(SUM(TotalRevenue), 'N0') AS Revenue,
    FORMAT(SUM(NetProfit), 'N0') AS Pure_Profit,
    ROUND((SUM(CAST(NetProfit AS DECIMAL(18,2))) / NULLIF(SUM(TotalRevenue), 0)) * 100, 2) AS Profit_Margin_Percentage,
    ROUND(AVG(Rating), 2) AS Average_Customer_Rating
FROM dbo.Fact_Perfume_Sales
GROUP BY Brand, Category
ORDER BY SUM(NetProfit) DESC;



SELECT 
    LoyaltyLevel,
    CustomerGender,
    COUNT(SaleID) AS Number_of_Orders,
    ROUND(AVG(CAST(CustomerAge AS FLOAT)), 0) AS Avg_Customer_Age,
    ROUND(AVG(CAST(TotalRevenue AS FLOAT)), 2) AS Average_Order_Value,
    FORMAT(SUM(TotalRevenue), 'N0') AS Total_Spent
FROM dbo.Fact_Perfume_Sales
GROUP BY LoyaltyLevel, CustomerGender
ORDER BY LoyaltyLevel, SUM(TotalRevenue) DESC;



WITH Customer_Behavior AS (
    SELECT 
        CustomerName,
        CustomerCity,
        LoyaltyLevel,
        COUNT(SaleID) AS Total_Orders,
        SUM(TotalRevenue) AS Total_Spend,
        AVG(Rating) AS Avg_Rating
    FROM dbo.Fact_Perfume_Sales
    GROUP BY CustomerName, CustomerCity, LoyaltyLevel
)
SELECT 
    CustomerName,
    CustomerCity,
    Total_Orders,
    FORMAT(Total_Spend, 'N0') AS Total_Spend,
    CASE 
        WHEN Total_Spend >= 5000 AND Total_Orders >= 5 THEN 'VIP Customer'
        WHEN Total_Spend BETWEEN 2000 AND 4999 THEN 'High Value Customer'
        ELSE 'Standard Customer'
    END AS Customer_Segment,
    ROUND(Avg_Rating, 2) AS Customer_Avg_Rating
FROM Customer_Behavior
ORDER BY Total_Spend DESC;


WITH Ranked_Products AS (
    SELECT 
        BranchCity,
        Brand,
        Category,
        SUM(CAST(Qty AS INT)) AS Units_Sold,
        SUM(TotalRevenue) AS Brand_Revenue,
        DENSE_RANK() OVER (PARTITION BY BranchCity ORDER BY SUM(CAST(Qty AS INT)) DESC) AS Product_Rank
    FROM dbo.Fact_Perfume_Sales
    GROUP BY BranchCity, Brand, Category
)
SELECT 
    BranchCity,
    Brand AS Top_Brand,
    Category AS Top_Category,
    Units_Sold,
    FORMAT(Brand_Revenue, 'N0') AS Brand_Revenue
FROM Ranked_Products
WHERE Product_Rank = 1
ORDER BY Units_Sold DESC;

WITH Employee_Sales AS (
    SELECT 
        EmployeeName,
        EmployeeDepartment,
        BranchCity,
        COUNT(SaleID) AS Total_Orders,
        SUM(TotalRevenue) AS Individual_Revenue,
        SUM(NetProfit) AS Individual_Profit,
        AVG(TotalRevenue) OVER() AS Company_Avg_Sales_Per_Emp
    FROM dbo.Fact_Perfume_Sales
    GROUP BY EmployeeName, EmployeeDepartment, BranchCity
)
SELECT 
    EmployeeName,
    EmployeeDepartment,
    BranchCity,
    Total_Orders,
    FORMAT(Individual_Revenue, 'N0') AS Total_Sales,
    FORMAT(Individual_Profit, 'N0') AS Net_Profit,
    FORMAT(Individual_Revenue - Company_Avg_Sales_Per_Emp, 'N0') AS Variance_From_Company_Average
FROM Employee_Sales
ORDER BY Individual_Profit DESC;


SELECT 
    Brand,
    Category,
    ProductName,
    SUM(CAST(Qty AS INT)) AS Total_Units_Sold,
    COUNT(DISTINCT SaleID) AS Distinct_Orders_Count,
    ROUND(CAST(SUM(CAST(Qty AS INT)) AS DECIMAL(10,2)) / NULLIF(COUNT(DISTINCT SaleID), 0), 2) AS Purchase_Velocity_Per_Order,
    FORMAT(SUM(NetProfit), 'N0') AS Accumulated_Profit
FROM dbo.Fact_Perfume_Sales
GROUP BY Brand, Category, ProductName
ORDER BY Total_Units_Sold DESC;


SELECT 
    Region,
    FORMAT(SUM(CASE WHEN Category = 'Women Perfume' THEN TotalRevenue ELSE 0 END), 'N0') AS Women_Perfume_Revenue,
    FORMAT(SUM(CASE WHEN Category = 'Men Perfume' THEN TotalRevenue ELSE 0 END), 'N0') AS Men_Perfume_Revenue,
    FORMAT(SUM(CASE WHEN Category = 'Oriental' THEN TotalRevenue ELSE 0 END), 'N0') AS Oriental_Revenue,
    FORMAT(SUM(CASE WHEN Category = 'Unisex' THEN TotalRevenue ELSE 0 END), 'N0') AS Unisex_Revenue,
    FORMAT(SUM(TotalRevenue), 'N0') AS Total_Regional_Revenue
FROM dbo.Fact_Perfume_Sales
GROUP BY Region
ORDER BY SUM(TotalRevenue) DESC;



WITH Sales_Stats AS (
    SELECT 
        SaleID,
        SaleDate,
        BranchCity,
        TotalRevenue,
        AVG(TotalRevenue) OVER() AS Global_Avg_Sales,
        STDEV(TotalRevenue) OVER() AS Global_StdDev_Sales
    FROM dbo.Fact_Perfume_Sales
)
SELECT 
    SaleID,
    SaleDate,
    BranchCity,
    FORMAT(TotalRevenue, 'N0') AS Exceptional_Sale_Amount,
    FORMAT(Global_Avg_Sales, 'N0') AS General_Average
FROM Sales_Stats
WHERE TotalRevenue > (Global_Avg_Sales + (2 * Global_StdDev_Sales))
ORDER BY TotalRevenue DESC;












































































































