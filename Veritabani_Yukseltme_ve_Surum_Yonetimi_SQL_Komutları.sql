CREATE DATABASE BookStore; 
GO

USE BookStore;
GO

-- Yazarlar tablosu
CREATE TABLE Authors (
    AuthorID INT PRIMARY KEY IDENTITY(1,1), 
    FirstName NVARCHAR(50), 
    LastName NVARCHAR(50),  
    BirthDate DATE          
);

USE BookStore;
GO
-- Kitaplar tablosu
CREATE TABLE Books (
    BookID INT PRIMARY KEY IDENTITY(1,1),  
    Title NVARCHAR(100),                   
    Genre NVARCHAR(50),                    
    Price DECIMAL(10,2),                   
    AuthorID INT FOREIGN KEY REFERENCES Authors(AuthorID) 
);

USE BookStore;
GO
-- Müþteriler tablosu
CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY IDENTITY(1,1), 
    FullName NVARCHAR(100),                  
    Email NVARCHAR(100),                     
    RegisteredDate DATE                      
);

USE BookStore;
GO
-- Sipariþler tablosu
CREATE TABLE Orders (
    OrderID INT PRIMARY KEY IDENTITY(1,1),        
    CustomerID INT FOREIGN KEY REFERENCES Customers(CustomerID), 
    OrderDate DATETIME,                           
    TotalAmount DECIMAL(10,2)                     
);

USE BookStore;
GO
-- Sipariþ detaylarý tablosu
CREATE TABLE OrderDetails (
    OrderDetailID INT PRIMARY KEY IDENTITY(1,1),   
    OrderID INT FOREIGN KEY REFERENCES Orders(OrderID), 
    BookID INT FOREIGN KEY REFERENCES Books(BookID),    
    Quantity INT,                                     
    UnitPrice DECIMAL(10,2)                           
);

CREATE LOGIN Readlogin WITH PASSWORD = 'StrongPassword123!'; 

CREATE USER Readbookuser FOR LOGIN Readbooklogin; 

EXEC sp_addrolemember 'db_datareader', 'readbookuser'; 

INSERT INTO Authors (FirstName, LastName, BirthDate)
VALUES 
('George', 'Orwell', '1903-06-25'),
('J.K.', 'Rowling', '1965-07-31'),
('Jane', 'Austen', '1775-12-16');

INSERT INTO Books (Title, Genre, Price, AuthorID)
VALUES
('1984', 'Dystopian', 45.50, 1),
('Harry Potter and the Sorcerer''s Stone', 'Fantasy', 60.00, 2),
('Pride and Prejudice', 'Classic', 39.90, 3);

INSERT INTO Customers (FullName, Email, RegisteredDate)
VALUES
('Ayþe Yýlmaz', 'ayse@example.com', '2023-02-10'),
('Mehmet Demir', 'mehmet@example.com', '2024-05-15');

INSERT INTO Orders (CustomerID, OrderDate, TotalAmount)
VALUES
(1, '2024-04-01', 85.40),
(2, '2024-04-10', 60.00);

INSERT INTO OrderDetails (OrderID, BookID, Quantity, UnitPrice)
VALUES
(1, 1, 1, 45.50),
(1, 3, 1, 39.90),
(2, 2, 1, 60.00);

SELECT *            -- 2024 yýlý içindeki sipariþleri getirir
FROM Orders
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01';

-- Müþteri, kitap ve sipariþ bilgilerini birleþtiren detaylý sorgu
SELECT 
    c.FullName,         
    b.Title,             
    o.OrderDate,         
    od.Quantity,       
    od.UnitPrice         
FROM OrderDetails od
JOIN Orders o ON od.OrderID = o.OrderID
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN Books b ON od.BookID = b.BookID;

-- En çok CPU kullanan ilk 5 sorguyu listeler
SELECT TOP 5
    qs.total_worker_time / qs.execution_count AS Avg_CPU_Time, 
    qs.execution_count,                                         
    SUBSTRING(qt.text, qs.statement_start_offset / 2 + 1,
        (CASE WHEN qs.statement_end_offset = -1 
              THEN LEN(qt.text) * 2 
              ELSE qs.statement_end_offset END - qs.statement_start_offset) / 2
    ) AS QueryText                                              -- Sorgu metni
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY Avg_CPU_Time DESC;

-- Ýndeks kullaným durumunu analiz eder
SELECT 
    OBJECT_NAME(i.object_id) AS TableName, 
    i.name AS IndexName,                   
    i.index_id,                            
    dm.user_seeks,                         
    dm.user_scans,                         
    dm.user_lookups,                       
    dm.user_updates                       
FROM sys.indexes i
INNER JOIN sys.dm_db_index_usage_stats dm 
    ON i.object_id = dm.object_id AND i.index_id = dm.index_id
WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1; -- Sadece kullanýcý tablolarý

-- Þema deðiþikliklerini kaydedecek tablo oluþturuluyor
CREATE TABLE SchemaChangeLog (
    LogID INT PRIMARY KEY IDENTITY(1,1), 
    EventData XML,                       -- Deðiþiklik olay verisi
    ChangeDate DATETIME DEFAULT GETDATE() 
);
GO

-- DDL trigger: Veritabaný düzeyinde yapýlan tüm þema deðiþikliklerini loglar
CREATE TRIGGER trg_SchemaChange
ON DATABASE
FOR DDL_DATABASE_LEVEL_EVENTS
AS
BEGIN
    INSERT INTO SchemaChangeLog (EventData)
    VALUES (EVENTDATA()); -- Olay verisini tabloya ekler
END;

-- Books tablosuna yeni bir sütun ekleniyor
ALTER TABLE Books ADD Publisher NVARCHAR(100); 

-- Þema deðiþiklik kayýtlarýný listeleme
SELECT * FROM dbo.SchemaChangeLog; -- Ham kayýtlarý getirir

-- Aktif veritabaný adý
SELECT DB_NAME() AS CurrentDatabase;

-- Þema deðiþiklik loglarýný detaylý gösterir
SELECT 
    LogID, 
    ChangeDate, 
    EventData.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)') AS EventType, 
    EventData.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(100)') AS ObjectName, 
    EventData.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)') AS ExecutedCommand 
FROM dbo.SchemaChangeLog
ORDER BY ChangeDate DESC; -- En yeni deðiþiklik en üstte
