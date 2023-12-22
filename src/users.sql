-- Roles
CREATE ROLE Manager;
CREATE ROLE Cashier;
CREATE ROLE WarehouseWorker;

ALTER ROLE Cashier ADD MEMBER Manager;
ALTER ROLE WarehouseWorker ADD MEMBER Manager;
GO

-- Grants
GRANT SELECT ON Products TO public;

GRANT INSERT ON Shipment TO WarehouseWorker;
GRANT INSERT ON ShipmentEntries TO WarehouseWorker;
GRANT INSERT ON Transactions TO WarehouseWorker;

GRANT EXECUTE ON AddProduct TO Cashier;
GRANT EXECUTE ON FinalizeSale TO Cashier;
GRANT EXECUTE ON CanSell TO Cashier;
GRANT EXECUTE ON CancelSale TO Cashier;
GRANT INSERT ON Sales TO Cashier;
GRANT INSERT ON SaleEntries TO Cashier;
GRANT INSERT ON Transactions TO Cashier;

GO

-- Users
CREATE USER RockefellerDI WITH PASSWORD = 'RockefellerPassword1234';
ALTER ROLE Manager ADD MEMBER RockefellerDI;

ALTER ROLE Cashier ADD MEMBER IvanovaAA;

CREATE USER IvanovaAA WITH PASSWORD = 'IvanovaPassword1234';
ALTER ROLE Cashier ADD MEMBER IvanovaAA;

CREATE USER IvanovBA WITH PASSWORD = 'IvanovPassword1234';
ALTER ROLE WarehouseWorker ADD MEMBER IvanovBA;
GO

INSERT INTO Employees (FirstName, SecondName, Position, Salary)
VALUES 
    ('Danil', 'Rockefeller', 'Manager', 1000000.00),
    ('Anna', 'Ivanova', 'Cashier', 50000.00),
    ('Boris', 'Ivanov', 'WarehouseWorker', 60000.00);
GO
