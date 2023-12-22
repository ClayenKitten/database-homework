USE Supermarket;
GO

-- Categories
INSERT INTO Categories(DisplayName)
VALUES
    ('Groceries'),
    ('Dairy'),
    ('Produce'),
    ('Frozen Foods'),
    ('Beverages'),
    ('Personal Care'),
    ('Household');
INSERT INTO Categories(DisplayName, AgeRestricted, TimeRestricted, MinimalPrice)
VALUES
    ('Tobacco', 1, 0, 200),
    ('Alcohol', 1, 1, 450);

-- Products
INSERT INTO Products(CategoryId, ProductName, Price, Stored, EAN13)
VALUES
    -- Groceries
    (1, 'Rice', 299, 100, '1234567890123'),
    (1, 'Pasta', 150, 75, '2345678901234'),
    -- Dairy
    (2, 'Milk', 1.99, 50, '3456789012345'),
    (2, 'Cheese', 3.50, 30, '4567890123456'),
    -- Produce
    (3, 'Apples', 1.25, 80, '5678901234567'),
    (3, 'Lettuce', 1.75, 40, '6789012345678'),
    -- Frozen Foods
    (4, 'Pizza', 4.99, 20, '7890123456789'),
    (4, 'Ice Cream', 3.50, 25, '8901234567890'),
    -- Beverages
    (5, 'Soda', 1.00, 60, '9012345678901'),
    (5, 'Coffee', 2.50, 40, '0123456789012'),
    -- Personal Care
    (6, 'Shampoo', 3.99, 15, '3456789012345'),
    (6, 'Toothpaste', 1.75, 30, '4567890123456'),
    -- Household
    (7, 'Dish Soap', 1.50, 45, '5678901234567'),
    (7, 'Trash Bags', 2.25, 35, '6789012345678');

-- Discounts
INSERT INTO Discounts AS 
