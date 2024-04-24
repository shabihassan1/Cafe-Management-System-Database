/* Users */

CREATE TABLE Users (
  userId int PRIMARY KEY IDENTITY,  
  name varchar(100) NOT NULL,
  email varchar(100) NOT NULL,
  password varchar(20) NOT NULL
);


/* User Profile */

CREATE TABLE UserProfile (
   profileId int PRIMARY KEY IDENTITY,
   userId int FOREIGN KEY REFERENCES Users(userId),  
   preferences varchar(255),
   dietaryRestrictions varchar(255),
   loyaltyPoints int
);


/* Menu Items */

CREATE TABLE MenuItem (
  itemId int PRIMARY KEY IDENTITY,
  name varchar(50) NOT NULL,
  description varchar(255), 
  price decimal(10,2) NOT NULL,
  category varchar(50) NOT NULL,
  nutritionalInfo varchar(255),
  arModelId int  
);

/* Orders */

CREATE TABLE Orders (
  orderId int PRIMARY KEY IDENTITY,
  userId int FOREIGN KEY REFERENCES Users(userId),  
  totalPrice decimal(10,2) NOT NULL, 
  orderStatus varchar(50) NOT NULL,
  orderDateTime datetime NOT NULL,
  paymentMethodId int   
);


/* Order Items */

CREATE TABLE OrderItem (
  orderItemId int PRIMARY KEY IDENTITY,
  orderId int FOREIGN KEY REFERENCES Orders(orderId),
  itemId int FOREIGN KEY REFERENCES MenuItem(itemId),
  quantity int NOT NULL,
  customizations varchar(255)
); 
/* Payment Methods */

CREATE TABLE PaymentMethods (
  paymentMethodId int PRIMARY KEY IDENTITY,
  userId int FOREIGN KEY REFERENCES Users(userId),
  paymentType varchar(50) NOT NULL,
  provider varchar(50) NOT NULL, 
  accountDetails varchar(255) 
);


/* Inventory Items */

CREATE TABLE InventoryItems (
  inventoryId int PRIMARY KEY IDENTITY,
  itemName varchar(100) NOT NULL,
  quantity int NOT NULL,
  reorderLevel int NOT NULL,
  supplierId int
);

/* Suppliers */

CREATE TABLE Suppliers (
  supplierId int PRIMARY KEY IDENTITY,
  name varchar(100) NOT NULL,
  contact varchar(255) NOT NULL,
  reliabilityScore int,
  isPreferredSupplier bit
);

/* Reservations */

CREATE TABLE Reservations (
  reservationId int PRIMARY KEY IDENTITY, 
  userId int FOREIGN KEY REFERENCES Users(userId),
  numGuests int NOT NULL,
  reservationDate date NOT NULL, 
  reservationTime time NOT NULL,
  specialArrangements varchar(255)
);

/* Feedback */

CREATE TABLE Feedback (
  feedbackId int PRIMARY KEY IDENTITY,
  userId int FOREIGN KEY REFERENCES Users(userId),
  orderId int FOREIGN KEY REFERENCES Orders(orderId), 
  rating int NOT NULL,
  comments varchar(255),
  feedbackDate date  
);

/* Queue Management */

CREATE TABLE Queues (
  queueId int PRIMARY KEY IDENTITY, 
  userId int FOREIGN KEY REFERENCES Users(userId),
  position int NOT NULL, 
  estimatedWaitTime int
);

/* AI Recommendations */

CREATE TABLE AIRecommendations (
  recommendationId int PRIMARY KEY IDENTITY,
  userId int FOREIGN KEY REFERENCES Users(userId),
  itemId int FOREIGN KEY REFERENCES MenuItem(itemId),
  confidenceScore decimal(4,2) NOT NULL,
  recommendedOn DateTime NOT NULL
);

/* AR Experiences */

CREATE TABLE ARExperiences (
  arExperienceId int PRIMARY KEY IDENTITY,
  itemId int FOREIGN KEY REFERENCES MenuItem(itemId),
  modelStoragePath varchar(255) NOT NULL,
  interactivityLevel varchar(50) NOT NULL
);

/* Events */

CREATE TABLE Events (
  eventId int PRIMARY KEY IDENTITY,
  eventName varchar(100) NOT NULL, 
  eventDescription varchar(255),
  eventDate DateTime NOT NULL,   
  eventTime Time NOT NULL,
  organizerUserId int FOREIGN KEY REFERENCES Users(userId) 
);

/* Event Registrations */

CREATE TABLE EventRegistrations (
  registrationId int PRIMARY KEY IDENTITY,
  eventId int FOREIGN KEY REFERENCES Events(eventId),
  userId int FOREIGN KEY REFERENCES Users(userId),
  registeredOn DateTime NOT NULL,
  specialRequests varchar(255)
);

CREATE TABLE AuditTrail
(
    AuditID int PRIMARY KEY IDENTITY,
    TableName varchar(255) NOT NULL,
    OperationType varchar(50) NOT NULL,
    PK varchar(1000) NOT NULL,
    ColumnName varchar(255),
    OldValue varchar(1000),
    NewValue varchar(1000),
    UpdateDate datetime NOT NULL,
    UserName varchar(255) NOT NULL
);


--Automatically update the loyaltyPoints in the UserProfile table whenever a new order is placed.

CREATE TRIGGER trg_after_insert_orders
ON Orders
AFTER INSERT
AS
BEGIN
    DECLARE @userId int, @totalPrice decimal(10,2);
    SELECT @userId = userId, @totalPrice = totalPrice FROM inserted;
    UPDATE UserProfile
    SET loyaltyPoints = loyaltyPoints + @totalPrice / 10
    WHERE userId = @userId;
END;

--This trigger will automatically send an alert when the quantity of an InventoryItem falls below the reorderLevel.
CREATE TRIGGER trg_after_update_inventoryitems
ON InventoryItems
AFTER UPDATE
AS
BEGIN
    DECLARE @inventoryId int, @itemName varchar(100), @quantity int, @reorderLevel int;
    SELECT @inventoryId = inventoryId, @itemName = itemName, @quantity = quantity, @reorderLevel = reorderLevel FROM inserted;
    IF @quantity < @reorderLevel
    BEGIN
        PRINT 'Low stock alert for item ' + @itemName + ' (ID: ' + CAST(@inventoryId AS varchar(10)) + ')';
    END;
END;


CREATE TRIGGER tr_Users_Audit
ON Users
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = USER_NAME();

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'Users',
        @OperationType,
        COALESCE(CAST(d.userId AS varchar(1000)), CAST(i.userId AS varchar(1000))),
        'name',
        d.name,
        i.name,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.userId = d.userId
    WHERE i.name <> d.name OR (i.name IS NULL AND d.name IS NOT NULL) OR (i.name IS NOT NULL AND d.name IS NULL);
END;

CREATE TRIGGER tr_UserProfile_Audit
ON UserProfile
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

   -- Get the name of the user who is performing the operation
    SET @UserName = USER_NAME();

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'UserProfile',
        @OperationType,
        COALESCE(CAST(d.profileId AS varchar(1000)), CAST(i.profileId AS varchar(1000))),
        'preferences',
        d.preferences,
        i.preferences,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.profileId = d.profileId
    WHERE i.preferences <> d.preferences OR (i.preferences IS NULL AND d.preferences IS NOT NULL) OR (i.preferences IS NOT NULL AND d.preferences IS NULL);
END;

CREATE TRIGGER tr_Suppliers_Audit
ON Suppliers
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
 -- Get the name of the user who is performing the operation
    SET @UserName = USER_NAME();

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'Suppliers',
        @OperationType,
        COALESCE(CAST(d.supplierId AS varchar(1000)), CAST(i.supplierId AS varchar(1000))),
        'name',
        d.name,
        i.name,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.supplierId = d.supplierId
    WHERE i.name <> d.name OR (i.name IS NULL AND d.name IS NOT NULL) OR (i.name IS NOT NULL AND d.name IS NULL);
END;


CREATE TRIGGER tr_Reservations_Audit
ON Reservations
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'Reservations',
        @OperationType,
        COALESCE(CAST(d.reservationId AS varchar(1000)), CAST(i.reservationId AS varchar(1000))),
        'numGuests',
        CAST(d.numGuests AS varchar(1000)),
        CAST(i.numGuests AS varchar(1000)),
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.reservationId = d.reservationId
    WHERE i.numGuests <> d.numGuests OR (i.numGuests IS NULL AND d.numGuests IS NOT NULL) OR (i.numGuests IS NOT NULL AND d.numGuests IS NULL);
END;


CREATE TRIGGER tr_Queues_Audit
ON Queues
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'Queues',
        @OperationType,
        COALESCE(CAST(d.queueId AS varchar(1000)), CAST(i.queueId AS varchar(1000))),
        'position',
        CAST(d.position AS varchar(1000)),
        CAST(i.position AS varchar(1000)),
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.queueId = d.queueId
    WHERE i.position <> d.position OR (i.position IS NULL AND d.position IS NOT NULL) OR (i.position IS NOT NULL AND d.position IS NULL);
END;

CREATE TRIGGER tr_PaymentMethods_Audit
ON PaymentMethods
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'PaymentMethods',
        @OperationType,
        COALESCE(CAST(d.paymentMethodId AS varchar(1000)), CAST(i.paymentMethodId AS varchar(1000))),
        'paymentType',
        d.paymentType,
        i.paymentType,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.paymentMethodId = d.paymentMethodId
    WHERE i.paymentType <> d.paymentType OR (i.paymentType IS NULL AND d.paymentType IS NOT NULL) OR (i.paymentType IS NOT NULL AND d.paymentType IS NULL);
END;


CREATE TRIGGER tr_Orders_Audit
ON Orders
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'Orders',
        @OperationType,
        COALESCE(CAST(d.orderId AS varchar(1000)), CAST(i.orderId AS varchar(1000))),
        'totalPrice',
        CAST(d.totalPrice AS varchar(1000)),
        CAST(i.totalPrice AS varchar(1000)),
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.orderId = d.orderId
    WHERE i.totalPrice <> d.totalPrice OR (i.totalPrice IS NULL AND d.totalPrice IS NOT NULL) OR (i.totalPrice IS NOT NULL AND d.totalPrice IS NULL);
END;


CREATE TRIGGER tr_OrderItem_Audit
ON OrderItem
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'OrderItem',
        @OperationType,
        COALESCE(CAST(d.orderItemId AS varchar(1000)), CAST(i.orderItemId AS varchar(1000))),
        'quantity',
        CAST(d.quantity AS varchar(1000)),
        CAST(i.quantity AS varchar(1000)),
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.orderItemId = d.orderItemId
    WHERE i.quantity <> d.quantity OR (i.quantity IS NULL AND d.quantity IS NOT NULL) OR (i.quantity IS NOT NULL AND d.quantity IS NULL);
END;




CREATE TRIGGER tr_MenuItem_Audit
ON MenuItem
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'MenuItem',
        @OperationType,
        COALESCE(CAST(d.itemId AS varchar(1000)), CAST(i.itemId AS varchar(1000))),
        'name',
        d.name,
        i.name,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.itemId = d.itemId
    WHERE i.name <> d.name OR (i.name IS NULL AND d.name IS NOT NULL) OR (i.name IS NOT NULL AND d.name IS NULL);
END;

CREATE TRIGGER tr_InventoryItems_Audit
ON InventoryItems
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'InventoryItems',
        @OperationType,
        COALESCE(CAST(d.inventoryId AS varchar(1000)), CAST(i.inventoryId AS varchar(1000))),
        'itemName',
        d.itemName,
        i.itemName,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.inventoryId = d.inventoryId
    WHERE i.itemName <> d.itemName OR (i.itemName IS NULL AND d.itemName IS NOT NULL) OR (i.itemName IS NOT NULL AND d.itemName IS NULL);
END;

CREATE TRIGGER tr_Feedback_Audit
ON Feedback
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'Feedback',
        @OperationType,
        COALESCE(CAST(d.feedbackId AS varchar(1000)), CAST(i.feedbackId AS varchar(1000))),
        'rating',
        CAST(d.rating AS varchar(1000)),
        CAST(i.rating AS varchar(1000)),
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.feedbackId = d.feedbackId
    WHERE i.rating <> d.rating OR (i.rating IS NULL AND d.rating IS NOT NULL) OR (i.rating IS NOT NULL AND d.rating IS NULL);
END;

CREATE TRIGGER tr_Events_Audit
ON Events
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'Events',
        @OperationType,
        COALESCE(CAST(d.eventId AS varchar(1000)), CAST(i.eventId AS varchar(1000))),
        'eventName',
        d.eventName,
        i.eventName,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.eventId = d.eventId
    WHERE i.eventName <> d.eventName OR (i.eventName IS NULL AND d.eventName IS NOT NULL) OR (i.eventName IS NOT NULL AND d.eventName IS NULL);
END;

CREATE TRIGGER tr_EventRegistrations_Audit
ON EventRegistrations
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'EventRegistrations',
        @OperationType,
        COALESCE(CAST(d.registrationId AS varchar(1000)), CAST(i.registrationId AS varchar(1000))),
        'specialRequests',
        d.specialRequests,
        i.specialRequests,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.registrationId = d.registrationId
    WHERE i.specialRequests <> d.specialRequests OR (i.specialRequests IS NULL AND d.specialRequests IS NOT NULL) OR (i.specialRequests IS NOT NULL AND d.specialRequests IS NULL);
END;


CREATE TRIGGER tr_ARExperiences_Audit
ON ARExperiences
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'ARExperiences',
        @OperationType,
        COALESCE(CAST(d.arExperienceId AS varchar(1000)), CAST(i.arExperienceId AS varchar(1000))),
        'interactivityLevel',
        d.interactivityLevel,
        i.interactivityLevel,
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.arExperienceId = d.arExperienceId
    WHERE i.interactivityLevel <> d.interactivityLevel OR (i.interactivityLevel IS NULL AND d.interactivityLevel IS NOT NULL) OR (i.interactivityLevel IS NOT NULL AND d.interactivityLevel IS NULL);
END;

CREATE TRIGGER tr_AIRecommendations_Audit
ON AIRecommendations
FOR INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @OperationType varchar(50);
    DECLARE @UserName varchar(255);

    IF EXISTS (SELECT * FROM inserted)
        IF EXISTS (SELECT * FROM deleted)
            SET @OperationType = 'UPDATE';
        ELSE
            SET @OperationType = 'INSERT';
    ELSE
        SET @OperationType = 'DELETE';

    -- Get the name of the user who is performing the operation
    SET @UserName = SYSTEM_USER;

    -- Insert a record into the AuditTrail table
    INSERT INTO AuditTrail
    (
        TableName,
        OperationType,
        PK,
        ColumnName,
        OldValue,
        NewValue,
        UpdateDate,
        UserName
    )
    SELECT
        'AIRecommendations',
        @OperationType,
        COALESCE(CAST(d.recommendationId AS varchar(1000)), CAST(i.recommendationId AS varchar(1000))),
        'confidenceScore',
        CAST(d.confidenceScore AS varchar(1000)),
        CAST(i.confidenceScore AS varchar(1000)),
        GETDATE(),
        @UserName
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.recommendationId = d.recommendationId
    WHERE i.confidenceScore <> d.confidenceScore OR (i.confidenceScore IS NULL AND d.confidenceScore IS NOT NULL) OR (i.confidenceScore IS NOT NULL AND d.confidenceScore IS NULL);
END;



-- This view shows all orders placed by each user, including the total price and order status.
CREATE VIEW UserOrders AS
SELECT Users.name, Orders.orderId, Orders.totalPrice, Orders.orderStatus
FROM Users
JOIN Orders ON Users.userId = Orders.userId;
GO

-- This view shows the current quantity of each inventory item and whether it's below the reorder level.
CREATE VIEW InventoryStatus AS
SELECT InventoryItems.itemName, InventoryItems.quantity,
CASE WHEN InventoryItems.quantity < InventoryItems.reorderLevel THEN 'Low Stock' ELSE 'Stock OK' END AS stockStatus
FROM InventoryItems;
GO

-- This view shows the dietary restrictions of each user.
CREATE VIEW UserDietaryRestrictions AS
SELECT Users.name, UserProfile.dietaryRestrictions
FROM Users
JOIN UserProfile ON Users.userId = UserProfile.userId;
GO

-- This view shows all users registered for each event.
CREATE VIEW EventRegs AS
SELECT Events.eventName, Users.name
FROM EventRegistrations
JOIN Events ON EventRegistrations.eventId = Events.eventId
JOIN Users ON EventRegistrations.userId = Users.userId;
GO

-- This view shows all AI recommendations for each user.
CREATE VIEW AIRecs AS
SELECT Users.name, MenuItem.name AS recommendedItem, AIRecommendations.confidenceScore
FROM AIRecommendations
JOIN Users ON AIRecommendations.userId = Users.userId
JOIN MenuItem ON AIRecommendations.itemId = MenuItem.itemId;
GO


/* Users */


INSERT INTO Users (name, email, password) VALUES  
('John', 'john@cafe.com', 'abcd1234'),
('Sarah', 'sarah@cafe.com', '1234abcd'),
('Mark', 'mark@cafe.com', 'asdf3456'),  
('Mary', 'mary@cafe.com', '876yuiop'),
('Steve', 'steve@cafe.com', '1234trewq');

/* User Profiles */

INSERT INTO UserProfile (userId, preferences, loyaltyPoints) VALUES
(1, 'No spicy food', 10),  
(2, 'Vegan', 5),
(3, 'Lactose-free', 7),
(4, 'Gluten-free', 9),
(5, 'Vegetarian', 4);

/* Menu Items */  

INSERT INTO MenuItem (name, description, price, category) VALUES
('Cappuccino', 'Frothy coffee with milk', 4.50, 'Beverages'),  
('Blueberry Muffin', 'Freshly baked with fruit', 2.50 , 'Pastries'),
('Veggie Sandwich','Layers of grilled veggies', 5.50,'Main'),
('Chocolate Cake','Rich and fudgy', 4.00, 'Dessert'), 
('Iced Tea','Refreshing chilled black tea', 3.00, 'Beverages');

/* Orders */
  
INSERT INTO Orders (userId, totalPrice, orderStatus, orderDateTime) VALUES  
(1, 15.50, 'COMPLETE', '2023-03-01 09:30:00'), 
(3, 10.50, 'COMPLETED', '2023-03-02 11:00:00'),
(2, 6.50, 'PAID', '2023-03-05 16:45:00'),
(4, 12.00, 'CONFIRMED', '2023-03-08 14:30:00'),  
(5, 3.00, 'ORDERED', '2023-03-09 21:10:00');

/* Payment Methods */

INSERT INTO PaymentMethods (userId, paymentType, provider) VALUES
(1, 'Credit Card', 'VISA'),
(2, 'Campus Card', 'University Points'),  
(3, 'Mobile Pay', 'Google Pay'),
(4, 'Debit card', 'MasterCard'), 
(5, 'Credit Card', 'American Express');

/* Order Items */

INSERT INTO OrderItem (orderId, itemId, quantity, customizations) VALUES
(1, 1, 2, 'Almond milk'), 
(2, 4, 1, NULL),
(3, 3, 1, 'Extra veggies'),  
(4, 2, 2, NULL),
(5, 5, 1, NULL);


/* Inventory Items */

INSERT INTO InventoryItems (itemName, quantity, reorderLevel, supplierId) VALUES  
('Milk', 10, 5, 1),  
('Blueberries', 3, 2, 2), 
('Bread', 5, 4, 3),
('Cheese', 2, 3, 4),
('Chocolate', 7, 6, 5);

/* Suppliers */

INSERT INTO Suppliers (name, contact, reliabilityScore, isPreferredSupplier) VALUES
('Local Dairy', '5738294732', 4, 1), 
('Fruit Farm', '9485738202', 3, 0),
('Bakery', '2857748392', 5, 1),  
('Cheese Co', '8392028340', 2, 0), 
('Choco Delight', '9182746382', 4, 0); 


/* Reservations */

INSERT INTO Reservations (userId, numGuests, reservationDate, reservationTime, specialArrangements) VALUES 
(1, 2, '2023-04-02', '11:30', 'Outdoor seating'),
(4, 4, '2023-04-11', '15:45', NULL),
(5, 1, '2023-05-01', '13:15', 'Wheelchair Accessible');

/* Feedback */ 

INSERT INTO Feedback (userId, orderId, rating, comments) VALUES
(2, 2, 4, 'Food was nice'),  
(3, 3, 5, 'Excellent sandwiches'),
(4, 4, 3, 'Cake was not very sweet');

INSERT INTO Queues (userId, position, estimatedWaitTime) VALUES
(1, 2, 10),
(3, 1, 5),
(5, 3, 15);

/* AI Recommendations */

INSERT INTO AIRecommendations (userId, itemId, confidenceScore, recommendedOn) VALUES
(1, 2, 0.85, '2023-03-01 10:30:00'),
(2, 4, 0.92, '2023-03-02 12:00:00'),
(3, 1, 0.78, '2023-03-05 17:00:00');

/* AR Experiences */

INSERT INTO ARExperiences (itemId, modelStoragePath, interactivityLevel) VALUES
(1, '/models/cappuccino_model', 'High'),
(4, '/models/chocolate_cake_model', 'Medium'),
(5, '/models/iced_tea_model', 'Low');

/* Events */

INSERT INTO Events (eventName, eventDescription, eventDate, eventTime, organizerUserId) VALUES
('Coffee Tasting', 'Explore the world of coffee', '2023-04-15', '14:00:00', 1),
('Baking Workshop', 'Learn to bake delicious pastries', '2023-05-10', '16:30:00', 3);

/* Event Registrations */

INSERT INTO EventRegistrations (eventId, userId, registeredOn, specialRequests) VALUES
(1, 2, '2023-04-05 09:30:00', 'Bring a friend'),
(2, 4, '2023-05-02 11:15:00', 'Allergies');

/* Users Table */
SELECT * FROM Users;

/* UserProfile Table */
SELECT * FROM UserProfile;

/* MenuItem Table */
SELECT * FROM MenuItem;

/* Orders Table */
SELECT * FROM Orders;

/* OrderItem Table */
SELECT * FROM OrderItem;

/* PaymentMethods Table */
SELECT * FROM PaymentMethods;

/* InventoryItems Table */
SELECT * FROM InventoryItems;

/* Suppliers Table */
SELECT * FROM Suppliers;

/* Reservations Table */
SELECT * FROM Reservations;

/* Feedback Table */
SELECT * FROM Feedback;

/* Queue Management Table */
SELECT * FROM Queues;

/* AI Recommendations Table */
SELECT * FROM AIRecommendations;

/* AR Experiences Table */
SELECT * FROM ARExperiences;

/* Events Table */
SELECT * FROM Events;

/* Event Registrations Table */
SELECT * FROM EventRegistrations;

-- Nested Subqueries

-- 1. Find Menu Items with Price Higher Than Average Price of Their Category
SELECT name, price, category 
FROM MenuItem 
WHERE price > (SELECT AVG(price) FROM MenuItem );

-- 2. Find Users Who Have Placed Orders Above Their Average Order Value
SELECT u.name, o.totalPrice 
FROM Users u 
JOIN Orders o ON u.userId = o.userId 
WHERE o.totalPrice > (SELECT AVG(totalPrice) FROM Orders WHERE userId = u.userId);

-- 3. List Users Who Have More Loyalty Points Than the Average
SELECT name 
FROM Users 
WHERE userId IN (SELECT userId FROM UserProfile WHERE loyaltyPoints > (SELECT AVG(loyaltyPoints) FROM UserProfile));

-- 4. Find Suppliers Who Have Provided More Inventory Items Than Average
SELECT name, contact 
FROM Suppliers 
WHERE supplierId IN (SELECT supplierId FROM InventoryItems GROUP BY supplierId HAVING COUNT(*) > (SELECT AVG(itemCount) FROM (SELECT COUNT(*) AS itemCount FROM InventoryItems GROUP BY supplierId) AS SubQuery));

-- Aggregate and Group By with Having

-- 1. Find Categories with More Than 5 Menu Items
SELECT category, COUNT(*) AS itemCount 
FROM MenuItem 
GROUP BY category 
HAVING COUNT(*) > 5;

-- 2. List Suppliers with Reliability Score Above Average
SELECT name 
FROM Suppliers 
GROUP BY name, reliabilityScore 
HAVING reliabilityScore > AVG(reliabilityScore);

-- 3. Users with More than Average Number of Orders
SELECT u.name 
FROM Users u 
JOIN Orders o ON u.userId = o.userId 
GROUP BY u.name 
HAVING COUNT(o.orderId) > (SELECT AVG(orderCount) FROM (SELECT COUNT(*) AS orderCount FROM Orders GROUP BY userId) AS SubQuery);

-- 4. Menu Items Ordered More Than Average in Orders
SELECT mi.name 
FROM MenuItem mi 
JOIN OrderItem oi ON mi.itemId = oi.itemId 
GROUP BY mi.name 
HAVING COUNT(oi.orderItemId) > (SELECT AVG(itemCount) FROM (SELECT COUNT(*) AS itemCount FROM OrderItem GROUP BY itemId) AS SubQuery);

-- Two Table Join

-- 1. Join Users and Orders to Show User Names with Their Order Total Price
SELECT u.name, o.totalPrice 
FROM Users u 
JOIN Orders o ON u.userId = o.userId;

-- 2. Join MenuItem and OrderItem to Show Item Names and Quantities Ordered
SELECT mi.name, oi.quantity 
FROM MenuItem mi 
JOIN OrderItem oi ON mi.itemId = oi.itemId;

-- 3. Join Users and UserProfile to Show User Names with Their Preferences
SELECT u.name, up.preferences 
FROM Users u 
JOIN UserProfile up ON u.userId = up.userId;

-- 4. Join Orders and PaymentMethods to Display Order Total and Payment Type
SELECT o.totalPrice, pm.paymentType 
FROM Orders o 
JOIN PaymentMethods pm ON o.paymentMethodId = pm.paymentMethodId;

-- Three Table Join

-- 1. Join Users, Orders, and OrderItem to Show User Names with Item Names and Quantities
SELECT u.name, mi.name AS itemName, oi.quantity 
FROM Users u 
JOIN Orders o ON u.userId = o.userId 
JOIN OrderItem oi ON o.orderId = oi.orderId
JOIN MenuItem mi ON oi.itemId = mi.itemId;

-- 2. Join Users, Feedback, and Orders to Show User Names, Order IDs, and Feedback Ratings
SELECT u.name, f.orderId, f.rating 
FROM Users u 
JOIN Feedback f ON u.userId = f.userId 
JOIN Orders o ON f.orderId = o.orderId;

-- 3. Join MenuItem, OrderItem, and Orders to Show Item Names, Quantities, and Order Status
SELECT mi.name, oi.quantity, o.orderStatus 
FROM MenuItem mi 
JOIN OrderItem oi ON mi.itemId = oi.itemId 
JOIN Orders o ON oi.orderId = o.orderId;

-- Four Table Joins

-- 1. Join Users, Orders, OrderItem, and MenuItem to Show User Names, Order IDs, Item Names, and Quantities
SELECT u.name, o.orderId, mi.name AS itemName, oi.quantity 
FROM Users u 
JOIN Orders o ON u.userId = o.userId 
JOIN OrderItem oi ON o.orderId = oi.orderId
JOIN MenuItem mi ON oi.itemId = mi.itemId;

-- 2. Join Users, UserProfile, Orders, and PaymentMethods to Show User Names, Preferences, Order IDs, and Payment Types
SELECT u.name, up.preferences, o.orderId, pm.paymentType 
FROM Users u 
JOIN UserProfile up ON u.userId = up.userId 
JOIN Orders o ON u.userId = o.userId 
JOIN PaymentMethods pm ON o.paymentMethodId = pm.paymentMethodId;


SELECT * FROM UserOrders;
GO

SELECT * FROM InventoryStatus;
GO

SELECT * FROM UserDietaryRestrictions;
GO

SELECT * FROM EventRegs;
GO

SELECT * FROM AIRecs;
GO
select * from AuditTrail
