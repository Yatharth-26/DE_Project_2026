# Problem Understanding – Amazon Online Shopping Database

## Project Overview

Amazon India is an online marketplace where multiple sellers list products under a hierarchical category structure. Customers browse products, maintain shopping carts, place orders, make payments, track deliveries, request returns, and submit product reviews.

The database must support customer-facing operations as well as seller dashboards, logistics operations, marketing activities, trust and safety checks, and financial reporting.

## Business Problems and Stakeholders

| ID | Business Need | Stakeholder | Classification |
|---|---|---|---|
| P1 | Improve product search and category browsing speed, especially for categories with many subcategories. | Customer, Category Manager | Customer-facing / Real-time |
| P2 | Load product details, ratings breakdowns, and frequently bought-together recommendations quickly. | Customer, Product Team | Customer-facing / Real-time |
| P3 | Retrieve customer order history and order details efficiently. | Customer | Customer-facing / Real-time |
| P4 | Improve seller dashboards for monthly sales, low stock, and price changes. | Seller | Reporting / Analytics |
| P5 | Identify delayed shipments and process packing queues efficiently. | Logistics Team | Customer-facing / Real-time |
| P6 | Identify saved addresses that have never been used for an order. | Admin, Customer Support | Reporting / Analytics |
| P7 | Improve abandoned-cart analysis and cart cleanup operations. | Marketing Team, Admin | Reporting / Analytics |
| P8 | Detect potentially fraudulent verified-purchase reviews and analyze review content. | Trust and Safety Team | Reporting / Analytics |
| P9 | Improve category, Prime, and financial reports while preparing for a projected 20× increase in traffic. | Category Manager, Prime Team, Finance Team | Reporting / Analytics |

## Assumptions

1. Each customer has a unique customer ID, email address, and phone number.
2. Each seller has a unique seller ID and GSTIN.
3. Products belong to one category and are listed by one seller.
4. Categories may have parent categories, forming a hierarchical category tree.
5. Customers can save multiple addresses, but exactly one address is marked as their default address.
6. Digital products do not require a delivery address.
7. Orders can contain multiple order lines.
8. A return is associated with a specific order line.
9. Product ratings and review counts are maintained in the product listing data, even though they can also be derived from reviews.
10. Prime membership is represented by a Boolean flag and an optional membership start date.
11. The supplied CSV files are the source of truth for the initial database load.

## Performance Priorities

Customer-facing operations such as product lookup, order details, and shipment tracking require low response times. Reporting and analytics operations may process larger portions of the database and therefore require efficient aggregation and query optimization.

The database design should preserve data integrity while supporting the supplied 30-query workload and future growth.