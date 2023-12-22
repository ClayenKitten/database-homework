USE Supermarket;
GO

CREATE FUNCTION ProductTotal(@ProductId INT, @CustomerId INT, @Amount DECIMAL)
RETURNS SMALLMONEY
AS
BEGIN
    DECLARE @Total SMALLMONEY;
    DECLARE @Subtotal SMALLMONEY;
    DECLARE @MinimalPrice SMALLMONEY;

    SELECT
        @Subtotal = Price * @Amount,
        @MinimalPrice = MinimalPrice * @Amount
    FROM
        Products
    LEFT JOIN
        Categories ON Products.CategoryId = Categories.CategoryId
    WHERE ProductId = @ProductId;

    SELECT
        @Total = ISNULL(MIN(
            CASE
                WHEN AbsoluteDiscount IS NOT NULL THEN @Subtotal - AbsoluteDiscount
                WHEN PercentDiscount IS NOT NULL THEN @Subtotal * (1 - PercentDiscount)
                ELSE @Subtotal
            END
        ), @Subtotal)
    FROM
        DiscountedProducts product
        LEFT JOIN ActiveDiscounts discount ON discount.DiscountId = product.DiscountId
        LEFT JOIN Customers ON CustomerId = @CustomerId
    WHERE (
        CONVERT(TIME(0), GETDATE()) BETWEEN discount.StartTime AND discount.EndTime AND
        (
            discount.Everyone = 1 OR
            @CustomerId IS NOT NULL AND
            (
                discount.CardHolders = 1 OR
                (Customers.IsMinor = 1 AND discount.Minors = 1) OR
                (Customers.IsSenior = 1 AND discount.Seniors = 1)
            )
        )
    );

    IF @Total < ISNULL(@MinimalPrice, 0) SET @Total = @MinimalPrice;
    IF @Total <= 0 SET @Total = 1; -- Store is not allowed give anything away for free

    RETURN @Total;
END
GO

-- Sales
CREATE TABLE #ongoingSaleEntries
(
    ProductId INT NOT NULL,
    Amount DECIMAL NOT NULL,
);
GO

CREATE PROCEDURE AddProduct(@ProductId INT NOT NULL, @Amount DECIMAL)
AS
BEGIN
    IF OBJECT_ID('#ongoingSaleEntries', 'U') IS NULL
    CREATE TABLE #ongoingSaleEntries
    (
        ProductId INT NOT NULL,
        Amount DECIMAL NOT NULL,
    );

    DECLARE @Price SMALLMONEY;
    SELECT @Price = Price FROM Products WHERE ProductId = @ProductId;

    MERGE #ongoingSaleEntries AS entries
    USING (SELECT @ProductId AS ProductId, @Amount AS Amount) AS new
    ON entries.ProductId = new.ProductId
    WHEN MATCHED THEN
        UPDATE SET entries.Amount += new.Amount
    WHEN NOT MATCHED THEN
        INSERT (ProductId, Amount) VALUES (new.ProductId, new.Amount);
END;
GO

CREATE FUNCTION CanSell(@CustomerId INT)
RETURNS BIT
AS
BEGIN
    IF OBJECT_ID('#ongoingSaleEntries', 'U') IS NULL RETURN 0;
    IF NOT EXISTS (SELECT 1 FROM #ongoingSaleEntries) RETURN 0;

    DECLARE @ProductId DECIMAL;
    DECLARE @Amount DECIMAL;

    DECLARE EntryCursor CURSOR FOR
    SELECT ProductId, Amount
    FROM #ongoingSaleEntries;

    OPEN EntryCursor
    FETCH NEXT FROM EntryCursor INTO @ProductId, @Amount

    WHILE @@FETCH_STATUS = 0
    BEGIN
        FETCH NEXT FROM EntryCursor INTO @ProductId, @Amount
        DECLARE @AgeRestricted BIT;
        DECLARE @TimeRestricted BIT;
        SELECT
            @AgeRestricted = AgeRestricted,
            @TimeRestricted = TimeRestricted
        FROM
            Products p
        JOIN
            Categories c ON p.CategoryId = c.CategoryId
        WHERE
            p.ProductId = @ProductId;
        IF
            @TimeRestricted = 1 AND
            DATEPART(HOUR, GETDATE()) NOT BETWEEN 8 AND 21
        RETURN 0;
        IF
            @AgeRestricted = 1 AND
            (SELECT IsMinor FROM Customers WHERE CustomerId = @CustomerId) = 1
        RETURN 0;
    END

    CLOSE EntryCursor
    DEALLOCATE EntryCursor

    RETURN 1;
END;
GO

CREATE PROCEDURE FinalizeSale(
    @CustomerId INT,
    @ReceivedCash SMALLMONEY,
    @Change SMALLMONEY,
    @CardHash CHAR(128)
)
AS
BEGIN
    IF dbo.CanSell(@CustomerId) = 0 THROW 50000, 'Sell forbidden', 1;
    BEGIN TRANSACTION

    IF (@ReceivedCash IS NULL AND @Change IS NULL AND @CardHash IS NOT NULL)
        INSERT INTO Transactions(CardHash, Total)
        VALUES(@CardHash, 0);
    ELSE IF (@ReceivedCash IS NOT NULL AND @Change IS NOT NULL AND @CardHash IS NULL)
        INSERT INTO Transactions(Change, ReceivedCash, Total)
        VALUES(@Change, @ReceivedCash, 0);
    ELSE
        THROW 50000, 'Invalid input', 1;
    DECLARE @TransactionId INT = SCOPE_IDENTITY();

    INSERT INTO Sales(CustomerId, TransactionId, SoldAt) VALUES (@CustomerId, @TransactionId, GETDATE());
    DECLARE @SaleId INT = SCOPE_IDENTITY();

    INSERT INTO SaleEntries(SaleId, ProductId, Amount, Price)
    SELECT
        @SaleId,
        entries.ProductId,
        entries.Amount,
        dbo.ProductTotal(entries.ProductId, @CustomerId, entries.Amount)
    FROM #ongoingSaleEntries entries
    JOIN Products ON Products.ProductId = entries.ProductId;

    UPDATE Transactions
    SET Total = Total
    WHERE TransactionId = @TransactionId;
    DROP TABLE #ongoingSaleEntries;

    COMMIT TRANSACTION
END;
GO

CREATE PROCEDURE CancelSale AS
DROP TABLE IF EXISTS #ongoingSaleEntries;
GO

CREATE TRIGGER RegisterStatus
ON Registers
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @IsOpenBefore BIT, @IsOpenAfter BIT, @RegisterId INT;

    SELECT @IsOpenBefore = IsOpen, @RegisterId = RegisterId
    FROM INSERTED;

    SELECT @IsOpenAfter = IsOpen
    FROM DELETED;

    IF (@IsOpenBefore = 0 AND @IsOpenAfter = 1)
    BEGIN
        INSERT INTO RegisterSessions (OpenedAt, RegisterId, CashierId)
        VALUES (GETDATE(), @RegisterId, (SELECT CashierId FROM INSERTED));
    END
    ELSE IF (@IsOpenBefore = 1 AND @IsOpenAfter = 0)
    BEGIN
        UPDATE RegisterSessions
        SET ClosedAt = GETDATE()
        WHERE RegisterId = @RegisterId AND ClosedAt IS NULL;
    END
END;
GO

CREATE TRIGGER StorageOnNewShipment ON Shipments
AFTER INSERT
AS BEGIN
    UPDATE Products
    SET Products.Stored += ShipmentEntries.Amount
    FROM (
        inserted JOIN ShipmentEntries
        ON inserted.ShipmentId = ShipmentEntries.ShipmentId
    )
    WHERE ShipmentEntries.ProductId = Products.ProductId;
END;
GO

CREATE TRIGGER StorageOnSale ON Sales
AFTER INSERT
AS BEGIN
    UPDATE Products
    SET Products.Stored += SaleEntries.Amount
    FROM (
        inserted JOIN SaleEntries
        ON inserted.SaleId = SaleEntries.SaleId
    )
    WHERE SaleEntries.ProductId = Products.ProductId;
END;
GO
