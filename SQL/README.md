# SQL Analysis

This folder contains the SQL Server scripts used to prepare, validate, and analyze the Olist e-commerce dataset.

## Files

### `01_database_setup.sql`

Creates the project database tables with appropriate data types, primary keys, and table grains.

### `02_data_cleaning_and_validation.sql`

Documents the import and cleaning process and performs checks for:

- Table row counts
- Primary-key duplicates
- Missing dates
- Order statuses
- Referential integrity
- Product-category translations
- Review duplicates
- Delivery-date anomalies

### `03_business_analysis.sql`

Contains analytical queries used to validate and support the Power BI report, including:

- Delivered sales and order KPIs
- Monthly performance trends
- Customer repeat-purchase analysis
- Cohort retention
- RFM scoring and segmentation
- Product-category performance
- Seller sales concentration
- Delivery performance and review ratings

## Analytical Conventions

- Commercial, customer, product, cohort, and RFM metrics use delivered orders only.
- Delivered sales represents merchandise value from item prices and excludes freight.
- Customer analysis uses `customer_unique_id`.
- Review records are deduplicated to retain the latest review per order.
- RFM analysis uses 30 August 2018 as the reference date.