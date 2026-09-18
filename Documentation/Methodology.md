# Olist E-commerce Analytics — Methodology

## 1. Analytical Scope

This project analyzes the Brazilian Olist marketplace across five business areas:

1. Executive sales and order performance
2. Customer retention and cohort behaviour
3. RFM customer segmentation
4. Product, category, and seller performance
5. Delivery performance and customer experience

Delivered orders are used for most realized commercial and customer metrics. All order statuses are retained where required for fulfilment and delivery-outcome analysis.

## 2. Source Tables

The analysis uses the following Olist tables:

| Table                | Primary analytical purpose                       |
| -------------------- | ------------------------------------------------ |
| Customers            | Customer identity and location                   |
| Orders               | Order status and purchase/delivery dates         |
| Order Items          | Product prices, freight, sellers, and items sold |
| Order Payments       | Payment records                                  |
| Order Reviews        | Review scores and review dates                   |
| Products             | Product and category details                     |
| Sellers              | Seller identity and location                     |
| Category Translation | Portuguese-to-English category translation       |

A dedicated Calendar table and several analytical tables were created during modelling.

## 3. Data Preparation

Data was prepared using SQL Server and Power Query.

The main preparation steps included:

* Standardizing column names and data types.
* Converting timestamp fields to appropriate date or datetime types.
* Translating product categories from Portuguese to English.
* Replacing underscores in category names with spaces.
* Applying consistent capitalization to business-facing category labels.
* Deduplicated review records to retain one review per order. Reviews were sorted by `review_creation_date`, `review_answer_timestamp`, and `review_id` in descending order; the sorted table was buffered before duplicates were removed using `order_id`, ensuring that the latest review was retained consistently.
* Creating a distinct customer dimension using `customer_unique_id`.
* Creating a dedicated Calendar table.
* Creating delivery-status and delay-duration classifications.
* Creating first- and last-delivered-order dates for customer analysis.
* Creating customer-level RFM attributes and scores.

## 4. Data-Grain Validation

The expected grain of each table was confirmed before modelling:

| Table          | Validated grain                                                                                |
| -------------- | ---------------------------------------------------------------------------------------------- |
| Orders         | One row per `order_id`                                                                         |
| Customers      | One row per order-level `customer_id`; `customer_unique_id` identifies customers across orders |
| Order Items    | One row per `order_id` and `order_item_id`                                                     |
| Order Payments | One row per payment record                                                                     |
| Order Reviews  | One retained review per `order_id` after deduplication                                         |
| Products       | One row per `product_id`                                                                       |
| Sellers        | One row per `seller_id`                                                                        |

Distinct order counts were used after connecting Orders with item-level and payment-level tables to avoid duplicated order totals.

## 5. Data-Quality Validation

The following checks were performed:

* Confirmed **99,441 distinct orders** in the Orders table.
* Compared delivered-order counts with counts for all other order statuses.
* Confirmed that multiple items can belong to one order, explaining why items sold exceed delivered orders.
* Checked missing and invalid order, delivery, product, payment, and review fields.
* Limited delivery-delay calculations to delivered orders with valid delivery dates.
* Retained only the latest review where multiple review records existed for an order.
* Reconciled overall delivered sales with product- and category-level totals.
* Reconciled cohort populations with customers’ first delivered-order dates.
* Compared the RFM customer population with the delivered-customer population.
* Identified **six cancelled orders containing delivery dates** and confirmed this anomaly independently through SQL and DAX.
* Cross-validated major order, sales, customer, delivery, and review metrics between SQL and Power BI.

## 6. Data Model

The Power BI model uses dimension-style tables to filter transactional tables through one-to-many relationships.

### Main Relationships

| From          | To             | Relationship                   | Purpose                                      |
| ------------- | -------------- | ------------------------------ | -------------------------------------------- |
| Dim Customers | Orders         | One-to-many                    | Customer, cohort, and RFM analysis           |
| Calendar      | Orders         | One-to-many                    | Time-based analysis                          |
| Orders        | Order Items    | One-to-many                    | Sales, products, items, freight, and sellers |
| Orders        | Order Payments | One-to-many                    | Payment analysis                             |
| Orders        | Order Reviews  | One-to-one after deduplication | Review analysis                              |
| Products      | Order Items    | One-to-many                    | Product and category analysis                |
| Sellers       | Order Items    | One-to-many                    | Seller analysis                              |

The primary active Calendar relationship uses the order-purchase date. Alternative order dates can be accessed through dedicated measures and secondary date relationships where required.

### Supporting Tables

* **Calendar:** Date attributes and chronological sorting
* **Dim Customers:** One row per unique customer
* **RFM Customers:** Customer-level RFM values, scores, and segments
* **Customer Type:** One-time and repeat-customer categories
* **Delivery-status tables:** Business-facing labels and custom sorting
* **Measure table:** Central organization of reusable DAX measures

## 7. Key Metric Definitions

### Delivered Orders

Distinct count of orders where order_status = "delivered"

### Delivered Sales

Sum of item prices associated with delivered orders. Freight is excluded and calculated separately.

Delivered Sales represents the value of completed merchandise sales processed through the marketplace. It does not represent Olist’s recognized accounting revenue because the dataset does not provide commission rates, seller fees, costs, or other revenue components.

### Delivered Freight

Sum of freight values associated with delivered order items. This measure is maintained separately from Delivered Sales.

### Items Sold

Count of item-level records associated with delivered orders. This value can exceed delivered orders because one order may contain multiple items.

### Average Order Value

```text
Delivered Sales ÷ Delivered Orders
```

This represents the average product value of a delivered order and excludes freight.

### Average Selling Price

```text
Delivered Sales ÷ Delivered Items Sold
```

This represents the average price paid per delivered item.

### Customers Served

Distinct customers with at least one delivered order, using `customer_unique_id`.

### Repeat Customers

Distinct customers with more than one delivered order.

### Repeat Customer Rate

```text
Repeat Customers ÷ Customers with at least one delivered order
```

### Average Review Rating

Average retained review score after keeping no more than one review per order.

### Late Delivery Rate

```text
Late Delivered Orders ÷ Total Delivered Orders
```

### Average Delay for Late Orders

Average number of days between the estimated delivery date and actual delivery date for orders delivered after the estimated date.

## 8. Delivery Classification

Delivered orders were classified by comparing actual and estimated delivery dates:

* **Early:** Delivered before the estimated date
* **On Time:** Delivered on the estimated date
* **Late:** Delivered after the estimated date
* **Not Delivered:** Order does not have a completed delivered outcome

Late delivered orders were further classified as:

* 1–3 Days Late
* 4–7 Days Late
* 8–14 Days Late
* 15+ Days Late

## 9. Cohort and Retention Methodology

Each customer was assigned to a cohort using the month of their first delivered order.

`Months Since First Delivered` represents the number of whole calendar months between:

* the customer’s first delivered-order month, and
* the month of a subsequent delivered order.

Month 0 represents the acquisition month and therefore begins at 100%.

### Cohort Customers

Distinct customers whose first delivered order occurred in the selected cohort month.

### Active Customers

Distinct cohort customers who placed a delivered order in the specified month index.

### Retention Rate

```text
Active Customers in Month N ÷ Original Cohort Customers
```

Blank cells indicate that no eligible delivered activity was recorded for that cohort and month combination.

## 10. RFM Methodology

RFM analysis was performed using delivered orders only.

The fixed reference date was **30 August 2018**, one day after the latest delivered purchase date used in the RFM analysis.

### Recency

Number of days between the reference date and the customer’s most recent delivered order.

Lower recency indicates more recent activity and receives a stronger score.

### Frequency

Number of distinct delivered orders placed by the customer.

Because the dataset is heavily concentrated among one-time purchasers, business thresholds were used:

| Delivered-order frequency | F-Score |
| ------------------------: | ------: |
|                         1 |       1 |
|                         2 |       2 |
|                         3 |       3 |
|                       4–5 |       4 |
|                 6 or more |       5 |

### Monetary Value

Total delivered sales generated by the customer.

Monetary scores were created using ranked value bands so that customers with greater delivered sales received stronger scores.

### RFM Segmentation

Recency, Frequency, and Monetary scores were combined to assign customers to business-facing groups:

* High-Value Recent
* High-Value At Risk
* Mid-Tier
* Recent, Low Spend
* Low-Value Lapsed

The resulting segments were used to compare:

* Customer distribution
* Delivered sales
* Average recency
* Repeat-customer rate

## 11. Seller-Revenue Concentration

Sellers were ranked by delivered sales in descending order.

Cumulative delivered-sales contribution was calculated for:

* Top 5% of sellers
* Top 10%
* Top 20%
* Top 50%
* All sellers

The calculation evaluates how much marketplace revenue depends on its highest-contributing sellers.

## 12. Analytical Assumptions

* Delivered sales represent item price and exclude freight.
* Commercial, customer, product, cohort, and RFM metrics use delivered orders only.
* Fulfilment and status-distribution metrics may include all order statuses.
* Each customer is identified using `customer_unique_id`, not the order-level `customer_id`.
* The latest review was retained when more than one review existed for an order.
* The RFM page is a fixed snapshot as of **30 August 2018**.
* The 72 Product Categories KPI represents the full translated product catalogue and does not respond to the Year slicer.
* Currency is displayed in Brazilian Real (`R$`).
* Blank cohort cells represent the absence of eligible delivered activity rather than a calculated zero.

## 13. Known Limitations

* The dataset ends in 2018 and therefore does not represent current marketplace performance.
* Very few customers placed multiple orders, resulting in extremely low cohort-retention values.
* RFM Frequency scores use business thresholds rather than equal-frequency quintiles because the frequency distribution is highly skewed.
* Product and seller performance is based on item price and excludes freight.
* Marketplace profitability cannot be measured because product cost and operating-expense data are unavailable.
* Review analysis reflects the latest retained review per order rather than every review record.
