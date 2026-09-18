/*
Project: Olist Brazilian E-commerce Analysis
File: 01_database_setup.sql
Purpose: Create the project database and destination tables
Author: Sonali
*/


IF DB_ID(N'OlistDB') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE OlistDB');
END;
GO

USE OlistDB;
GO

CREATE TABLE orders
(
    order_id NVARCHAR(50) NOT NULL,
    customer_id NVARCHAR(50) NOT NULL,
    order_status NVARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME2 NOT NULL,
    order_approved_at DATETIME2 NULL,
    order_delivered_carrier_date DATETIME2 NULL,
    order_delivered_customer_date DATETIME2 NULL,
    order_estimated_delivery_date DATETIME2 NOT NULL,
    CONSTRAINT PK_orders PRIMARY KEY (order_id)
);

CREATE TABLE order_items (
    order_id NVARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id NVARCHAR(50),
    seller_id NVARCHAR(50),
    shipping_limit_date DATETIME2,
    price DECIMAL(12,2),
    freight_value DECIMAL(12,2),
    CONSTRAINT PK_order_items 
        PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE customers (
    customer_id NVARCHAR(50),
    customer_unique_id NVARCHAR(50),
    customer_zip_code_prefix NVARCHAR(10),
    customer_city NVARCHAR(100),
    customer_state NVARCHAR(5),
	 CONSTRAINT PK_customers PRIMARY KEY (customer_id)
);

CREATE TABLE products (
    product_id NVARCHAR(50),
    product_category_name NVARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
	CONSTRAINT PK_products PRIMARY KEY (product_id)
);

CREATE TABLE order_reviews (
    review_id NVARCHAR(50),
    order_id NVARCHAR(50),
    review_score INT,
    review_comment_title NVARCHAR(500),
    review_comment_message NVARCHAR(MAX),
    review_creation_date DATETIME2,
    review_answer_timestamp DATETIME2
);


CREATE TABLE payments (
    order_id NVARCHAR(50),
    payment_sequential INT,
    payment_type NVARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(12,2),
	 CONSTRAINT PK_payments
        PRIMARY KEY (order_id, payment_sequential)
);


CREATE TABLE sellers (
    seller_id NVARCHAR(50),
    seller_zip_code_prefix NVARCHAR(10),
    seller_city NVARCHAR(100),
    seller_state NVARCHAR(5),
	CONSTRAINT PK_sellers PRIMARY KEY (seller_id)
);


CREATE TABLE category_translation (
    product_category_name NVARCHAR(100),
    product_category_name_english NVARCHAR(100),
	CONSTRAINT PK_category_translation
    PRIMARY KEY (product_category_name)
);