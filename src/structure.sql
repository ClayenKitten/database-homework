USE Supermarket;
EXEC sp_fulltext_database 'enable';
GO

CREATE TABLE Categories
(
    CategoryId INT PRIMARY KEY IDENTITY,
    DisplayName NVARCHAR(255) NOT NULL,
    AgeRestricted BIT DEFAULT 0 NOT NULL,
    TimeRestricted BIT DEFAULT 0 NOT NULL,
    MinimalPrice SMALLMONEY,
);
GO

CREATE TABLE Products
(
    ProductId INT PRIMARY KEY IDENTITY NOT NULL,
    CategoryId INT FOREIGN KEY REFERENCES Categories(CategoryId),
    ProductName NVARCHAR(255) NOT NULL,
    Price SMALLMONEY NOT NULL,
    Stored DECIMAL NOT NULL,
    EAN13 CHAR(13),
);
CREATE UNIQUE INDEX ProductsIndex ON Products(ProductId);
CREATE FULLTEXT CATALOG ProductsCatalog;

CREATE FULLTEXT INDEX ON Products
(
    ProductName
    LANGUAGE 1049 -- Russian
    -- LANGUAGE 2057 -- English
)
KEY INDEX ProductsIndex ON ProductsCatalog
WITH CHANGE_TRACKING AUTO;
GO

CREATE FUNCTION FindProducts(@Search NVARCHAR(255))
RETURNS TABLE
AS
RETURN
    SELECT TOP 10 RANK, Products.*
    FROM 
        Products
    INNER JOIN
        FREETEXTTABLE(Products, ProductName, @Search) AS KEY_TBL
        ON ProductId = KEY_TBL.[KEY]
    ORDER BY KEY_TBL.RANK DESC;
GO

CREATE TABLE Employees
(
    EmployeeId INT PRIMARY KEY IDENTITY,
    FirstName NVARCHAR(64) NOT NULL,
    SecondName NVARCHAR(64) NOT NULL,
    Position NVARCHAR(64),
    Salary MONEY NOT NULL,
);
GO

CREATE TABLE Customers
(
    CustomerId INT PRIMARY KEY IDENTITY,
    FirstName NVARCHAR(64) NOT NULL,
    SecondName NVARCHAR(64) NOT NULL,
    Phone VARCHAR(32),
    Email NVARCHAR(32),
    RegisteredAt DATETIME2 NOT NULL,
    DateOfBirth DATE NOT NULL,
    Age AS DATEDIFF(YEAR, DateOfBirth, GETDATE()),

    IsMinor AS CASE WHEN DATEDIFF(YEAR, DateOfBirth, GETDATE()) < 18 THEN 1 ELSE 0 END,
    IsSenior BIT DEFAULT 0 NOT NULL,
);
GO

-- Discounts
CREATE TABLE Discounts
(
    DiscountId INT PRIMARY KEY IDENTITY,
    DiscountName NVARCHAR(255) NOT NULL,
    EndDate DATE,
    -- Conditions of the discount
    Everyone BIT DEFAULT 0 NOT NULL,
    CardHolders BIT DEFAULT 1 NOT NULL,
    Seniors BIT DEFAULT 0 NOT NULL,
    Minors BIT DEFAULT 0 NOT NULL,
    MinimalAmount DECIMAL DEFAULT 0 NOT NULL,
    -- Time range when the discount is active.
    StartTime TIME,
    EndTime TIME,
    CHECK
    (
        (StartTime IS NULL AND EndTime IS NULL) OR
        (StartTime IS NOT NULL AND EndTime IS NOT NULL)
    ),
);
GO

CREATE TABLE DiscountedProducts
(
    DiscountId INT FOREIGN KEY REFERENCES Discounts(DiscountId),
    ProductId INT FOREIGN KEY REFERENCES Products(ProductId),
    AbsoluteDiscount SMALLMONEY,
    PercentDiscount DECIMAL,
    CHECK
    (
        (AbsoluteDiscount IS NOT NULL AND PercentDiscount IS NULL) OR
        (AbsoluteDiscount IS NULL AND PercentDiscount IS NOT NULL)
    ),
);
GO
CREATE VIEW ActiveDiscounts
AS
    SELECT * FROM Discounts
WHERE
    EndDate >= GETDATE();
GO

-- Shipments
CREATE TABLE Organizations
(
    OrganizationId INT PRIMARY KEY IDENTITY,
    OrgName NVARCHAR(255),
    Details TEXT NOT NULL DEFAULT(''),
);
GO

CREATE TABLE Shipments
(
    ShipmentId INT PRIMARY KEY IDENTITY,
    TransactionId INT FOREIGN KEY REFERENCES Transactions(TransactionId),
    OrganizationId INT FOREIGN KEY REFERENCES Organizations(OrganizationId),
    DocumentId INT,
    ShippedAt DATETIME2 NOT NULL,
);
GO

CREATE TABLE ShipmentEntries
(
    ShipmentId INT FOREIGN KEY REFERENCES Shipments(ShipmentId) NOT NULL,
    ProductId INT FOREIGN KEY REFERENCES Products(ProductId) NOT NULL,
    Amount DECIMAL,
    PRIMARY KEY(ShipmentId, ProductId),
);
GO

-- Sales & transactions
CREATE TABLE Transactions
(
    TransactionId INT PRIMARY KEY IDENTITY,
    Total MONEY NOT NULL,
    ReceivedCash SMALLMONEY,
    Change SMALLMONEY,
    CardHash CHAR(128),
    CHECK
    (
        ((ReceivedCash IS NOT NULL AND Change IS NOT NULL) AND (CardHash IS NULL)) OR
        ((ReceivedCash IS NULL AND Change IS NULL) AND (CardHash IS NOT NULL))
    )
);
GO

CREATE TABLE Sales
(
    SaleId INT PRIMARY KEY IDENTITY,
    TransactionId INT FOREIGN KEY REFERENCES Transactions(TransactionId) NOT NULL,
    CustomerId INT FOREIGN KEY REFERENCES Customers(CustomerId),
    RegisterSessionId INT FOREIGN KEY REFERENCES RegisterSessions(RegisterSessionId),
    SoldAt DATETIME2 NOT NULL,
);
CREATE TABLE SaleEntries
(
    SaleId INT FOREIGN KEY REFERENCES Sales(SaleId),
    ProductId INT FOREIGN KEY REFERENCES Products(ProductId),
    Amount DECIMAL NOT NULL,
    Price SMALLMONEY NOT NULL,
    Discount DECIMAL NOT NULL DEFAULT 0,
    Total AS Amount * Price - Discount PERSISTED,
    Subtotal AS Amount * Price PERSISTED,
    PRIMARY KEY(SaleId, ProductId)
);
GO

CREATE VIEW SalesReport
WITH SCHEMABINDING
AS SELECT
    s.SaleId,
    s.TransactionId,
    s.CustomerId,
    s.SoldAt,
    SUM(e.Discount) OVER (PARTITION BY s.SaleId) AS Discount,
    SUM(e.Subtotal) OVER (PARTITION BY s.SaleId) AS Subtotal,
    SUM(e.Total) OVER (PARTITION BY s.SaleId) AS Total
FROM
    dbo.Sales s
LEFT JOIN
    dbo.SaleEntries e ON s.SaleId = e.SaleId;
GO

-- Registers
CREATE Table Registers
(
    RegisterId INT PRIMARY KEY IDENTITY,
    IsOpen BIT NOT NULL,
    CashierId INT FOREIGN KEY REFERENCES Employees(EmployeeId),
    CHECK
    (
        (IsOpen = 0 AND CashierId IS NULL) OR
        (IsOpen = 1 AND CashierId IS NOT NULL)
    )
);
CREATE TABLE RegisterSessions
(
    RegisterSessionId INT PRIMARY KEY IDENTITY,
    OpenedAt DATETIME2 NOT NULL,
    ClosedAt DATETIME2 DEFAULT NULL,
    RegisterId INT FOREIGN KEY REFERENCES Registers(RegisterId) NOT NULL,
    CashierId INT FOREIGN KEY REFERENCES Employees(EmployeeId) NOT NULL,
);
GO

CREATE VIEW CurrentRegisterSessions
AS
  SELECT * FROM RegisterSessions
WHERE
  ClosedAt IS NULL;
GO
