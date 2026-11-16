# CP1 schema design

## Scope and implementation

The schema is `amazon`; both SQL scripts begin by selecting that schema. `sql/01_schema.sql` is intentionally limited to tables and integrity constraints. Apart from indexes PostgreSQL creates for primary and unique keys, the sole explicit index is `uq_addresses_one_default_per_customer`, a partial **unique integrity index** needed to enforce the cross-row rule of one default address; it is not a query-performance index.

`sql/02_load_data.sql` uses psql's `\copy` (so paths are relative to the repository root), loads referenced rows before referencing rows, and ends with `ANALYZE;`. The source is a snapshot: checks deliberately validate local facts but do not impose time-dependent business policy such as “an inactive product can never be in a historical order.”

## Data dictionary

`PK`, `FK`, and `UK` below name key roles. `NN` means `NOT NULL`; all checks named `chk_*` are in [01_schema.sql](../sql/01_schema.sql).

| Table | Column (type) | Constraints | Rationale |
|---|---|---|---|
| cities | city_id (integer) | PK, NN | Export identifier. |
| cities | city_name (varchar(50)) | UK, NN | Each exported city name is distinct. |
| cities | state (varchar(50)) | NN | Required geographic attribute; states repeat. |
| categories | category_id (integer) | PK, NN | Export identifier. |
| categories | category_name (varchar(100)) | UK, NN | All 40 names are distinct; workload looks names up. |
| categories | parent_category_id (integer) | nullable self FK, RESTRICT; not-own-parent check | Root categories are null; deleting a category with children is unsafe. |
| categories | is_digital (boolean) | NN | Distinguishes delivery-free product categories. |
| sellers | seller_id (integer) | PK, NN | Export identifier. |
| sellers | business_name (varchar(150)) | NN | Required seller display name (not declared unique business policy). |
| sellers | gstin (char(15)) | UK, NN, GSTIN-format check | Stable tax registration; all source values match the Indian GSTIN shape. |
| sellers | city_id (integer) | FK→cities, NN, RESTRICT | A seller has a city; retain referenced geography. |
| sellers | joined_on (date) | NN | Date-only joining event. |
| sellers | seller_rating (numeric(2,1)) | NN, 1.0–5.0 check | One-decimal rating in the source. |
| sellers | status (varchar(10)) | NN, ACTIVE/CLOSED/SUSPENDED check | Exact observed domain. |
| products | product_id (integer) | PK, NN | Export identifier. |
| products | asin (char(10)) | UK, NN, `B`+9-uppercase-alphanumerics check | Natural product lookup code. |
| products | seller_id (integer) | FK→sellers, NN, RESTRICT; with product_id UK | A listing belongs to its seller; composite UK supports order-line seller consistency. |
| products | category_id (integer) | FK→categories, NN, RESTRICT | Every listing is classified; used in browse and delivery checks. |
| products | title (varchar(255)) | NN | Required listing title. |
| products | brand (varchar(100)) | NN | Required brand. |
| products | mrp (numeric(12,2)) | NN, positive and ≥ price check | Rupee monetary amount with two decimals. |
| products | price (numeric(12,2)) | NN, positive and ≤ MRP check | Current sell price. |
| products | stock_qty (integer) | NN, ≥0 check | Integral inventory count. |
| products | is_prime_eligible (boolean) | NN | Observed boolean flag. |
| products | avg_rating (numeric(2,1)) | nullable; summary check | Null exactly when `review_count=0`; otherwise 1.0–5.0. |
| products | review_count (integer) | NN; summary check | Non-negative source review summary. |
| products | listed_on (date) | NN | Date-only listing date. |
| products | status (varchar(20)) | NN, ACTIVE/INACTIVE/OUT_OF_STOCK check | Exact observed domain. |
| customers | customer_id (integer) | PK, NN | Export identifier. |
| customers | full_name (varchar(150)) | NN | Names repeat, so are not keys. |
| customers | email (varchar(254)) | UK, NN, basic email-shape check | Distinct contact/login candidate. |
| customers | phone (char(10)) | UK, NN, Indian mobile-shape check | Distinct ten-digit contact candidate. |
| customers | city_id (integer) | FK→cities, NN, RESTRICT | Required home city. |
| customers | signup_date (date) | NN | Date-only signup event. |
| customers | is_prime (boolean) | NN | Membership flag. |
| customers | prime_since (date) | nullable; paired-Prime check | Present only for Prime members and not earlier than signup. |
| addresses | address_id (integer) | PK, NN | Export identifier. |
| addresses | customer_id (integer) | FK→customers, NN, CASCADE | A saved address is owned by a customer. |
| addresses | label (varchar(10)) | NN, HOME/WORK check | Exact observed domain. |
| addresses | line1 (varchar(255)) | NN | Required free-form address line. |
| addresses | city_id (integer) | FK→cities, NN, RESTRICT | Required delivery city. |
| addresses | pincode (char(6)) | NN, six-digit Indian pincode check | Stored as text to preserve its format. |
| addresses | is_default (boolean) | NN; partial UK(customer_id) where true | Exactly one default exists for every supplied customer; database enforces at most one. |
| orders | order_id (integer) | PK, NN | Export identifier. |
| orders | customer_id (integer) | FK→customers, NN, RESTRICT | Historical order ownership must not be deleted. |
| orders | address_id (integer) | nullable composite FK with customer_id→addresses, RESTRICT | Digital orders legitimately lack an address; composite FK ensures a supplied address belongs to the ordering customer. |
| orders | ordered_at (timestamptz) | NN | Source timestamps include `+05:30`. |
| orders | payment_method (varchar(20)) | NN, six-value check | CARD, COD, EMI, GIFT_CARD, NETBANKING, UPI. |
| orders | total_amount (numeric(14,2)) | NN, >0 check | Two-decimal order snapshot. |
| orders | status (varchar(20)) | NN, seven-value check | CANCELLED, DELIVERED, OUT_FOR_DELIVERY, PACKED, PLACED, RETURNED, SHIPPED. |
| orders | shipped_at (timestamptz) | nullable; ≥ ordered_at check | Absent for some unshipped orders. |
| orders | delivered_at (timestamptz) | nullable; ≥ ordered_at and ≥ shipped_at check | Absent for some undelivered orders. |
| order_items | order_id (integer) | PK part, FK→orders, NN, RESTRICT | Line's immutable parent order. |
| order_items | line_no (smallint) | PK part, NN, >0 check | Positive line sequence (source 1–3). |
| order_items | product_id (integer) | NN; composite FK with seller_id→products, RESTRICT | Product sold on the line. |
| order_items | seller_id (integer) | FK→sellers, NN; composite product FK | Required historical fulfiller; composite FK guarantees it equals the listing seller. |
| order_items | quantity (smallint) | NN, >0 check | Positive integer quantity. |
| order_items | unit_price (numeric(12,2)) | NN, >0 check | Historical per-unit price. |
| returns | return_id (integer) | PK, NN | Export identifier. |
| returns | order_id (integer) | UK pair and composite FK→order_items, NN, RESTRICT | Identifies the returned order line. |
| returns | line_no (smallint) | UK pair and composite FK→order_items, NN | Completes required order-item reference. |
| returns | reason (varchar(30)) | NN, six-value check | DAMAGED, NOT_AS_DESCRIBED, NO_LONGER_NEEDED, QUALITY_ISSUE, SIZE_ISSUE, WRONG_ITEM. |
| returns | requested_at (timestamptz) | NN | Timestamp with source offset. |
| returns | status (varchar(20)) | NN, four-value check | PICKED_UP, REFUNDED, REJECTED, REQUESTED. |
| returns | refund_amount (numeric(12,2)) | nullable; status/refund check | Positive and present iff status is REFUNDED. |
| product_reviews | review_id (integer) | PK, NN | Export identifier. |
| product_reviews | product_id (integer) | FK→products, NN, RESTRICT | Reviewed product. |
| product_reviews | customer_id (integer) | FK→customers, NN, RESTRICT | Review author. |
| product_reviews | rating (smallint) | NN, 1–5 check | Integral star rating. |
| product_reviews | title (varchar(100)) | NN | Required short review title. |
| product_reviews | body (text) | nullable | 13,811 source bodies are empty. |
| product_reviews | verified_purchase (boolean) | NN | Observed boolean assertion. |
| product_reviews | helpful_votes (integer) | NN, ≥0 check | Non-negative count. |
| product_reviews | created_at (timestamptz) | NN | Timestamp with source offset. |
| cart_items | customer_id (integer) | PK part, FK→customers, NN, CASCADE | Cart is disposable customer-owned state. |
| cart_items | product_id (integer) | PK part, FK→products, NN, CASCADE | One row per product in a cart. |
| cart_items | quantity (smallint) | NN, >0 check | Positive requested quantity. |
| cart_items | added_at (timestamptz) | NN | Timestamp with source offset. |

## Relationships and deletion rules

Cities have many sellers, customers, and addresses. Categories form an optional-parent tree and have many products. Sellers list many products; customers save many addresses and place many orders. An order has one or more order items; product and seller each occur on many order items. A return is optional and one-to-one with an order item (`UNIQUE(order_id,line_no)`). Products and customers each have many reviews and cart rows; `cart_items` is the customer–product M:N bridge.

Most master and historical relationships use `RESTRICT`: removing a city, category, seller, product, customer, address used by an order, order, or order item would destroy or orphan auditable facts. Address and cart rows instead use `CASCADE` from their owning customer; cart rows also cascade when a product is removed because they are transient shopping state. In practice, a customer with orders still cannot be deleted because `orders.customer_id` is restricted. The ER source is [er_diagram.mmd](../diagrams/er_diagram.mmd) and the rendered diagram is [er_diagram.png](../diagrams/er_diagram.png).

## Load and validation results

Validation used PostgreSQL 18 in clean local test databases (including verified clean run on fresh database `amazon_cp1_test_db`). `psql -v ON_ERROR_STOP=1 -f sql/01_schema.sql` and then `psql -v ON_ERROR_STOP=1 -f sql/02_load_data.sql` completed with no errors. All `\copy` commands reported the following actual counts.

| Table | Rows |
|---|---:|
| cities | 10 |
| categories | 40 |
| sellers | 1,500 |
| products | 30,000 |
| customers | 30,000 |
| addresses | 45,000 |
| orders | 120,000 |
| order_items | 240,000 |
| returns | 5,374 |
| product_reviews | 38,662 |
| cart_items | 44,998 |

Actual integrity-check SQL and results:

```sql
-- Result: 0
SELECT count(*) AS seller_mismatches
FROM order_items oi JOIN products p ON p.product_id = oi.product_id
WHERE oi.seller_id <> p.seller_id;

-- Result: 0
SELECT count(*) AS customers_without_exactly_one_default
FROM customers c
WHERE (SELECT count(*) FROM addresses a
       WHERE a.customer_id = c.customer_id AND a.is_default) <> 1;

-- Result: 0 (and there are 5,882 address-less orders)
SELECT count(*) AS addressless_orders_with_non_digital_item
FROM orders o
WHERE o.address_id IS NULL
  AND EXISTS (
      SELECT 1 FROM order_items oi
      JOIN products p ON p.product_id = oi.product_id
      JOIN categories c ON c.category_id = p.category_id
      WHERE oi.order_id = o.order_id AND NOT c.is_digital
  );
```

The unmodified `queries/workload_30.sql` also ran with `ON_ERROR_STOP`; it reached its supplied `ROLLBACK` with no SQL or constraint error.

## Functional dependencies and normal forms

All tables have atomic fields (1NF). The principal FDs below come from declared keys; foreign keys do not make descriptive attributes functionally dependent on a child key. Each table is in BCNF, hence 3NF, with the documented denormalized snapshots as intentional exceptions at the *business* level rather than determinant violations within their own row.

| Table | Functional dependencies | 3NF / BCNF assessment |
|---|---|---|
| cities | `city_id → city_name, state`; `city_name → city_id, state` | Both determinants are candidate keys: BCNF. |
| categories | `category_id → category_name, parent_category_id, is_digital`; `category_name →` all other fields | Candidate-key determinants only: BCNF. |
| sellers | `seller_id →` non-key fields; `gstin →` non-key fields | PK and GSTIN are candidate keys: BCNF. |
| products | `product_id →` non-key fields; `asin →` non-key fields; `(product_id,seller_id) →` non-key fields | PK/ASIN determine attributes; composite UK is a superkey: BCNF. |
| customers | `customer_id →` non-key fields; `email →` non-key fields; `phone →` non-key fields | Candidate-key determinants only: BCNF. |
| addresses | `address_id →` non-key fields; `(address_id,customer_id) →` non-key fields | PK determines all; redundant composite UK is a superkey: BCNF. |
| orders | `order_id →` non-key fields | Only declared determinant is the PK: BCNF. |
| order_items | `(order_id,line_no) → product_id,seller_id,quantity,unit_price` | Whole composite PK determines each fact; no partial dependency: BCNF. |
| returns | `return_id →` non-key fields; `(order_id,line_no) →` non-key fields | Both the PK and one-return-per-line UK are candidate keys: BCNF. |
| product_reviews | `review_id →` non-key fields | Review ID is the only asserted key; duplicate customer/product reviews are allowed by source: BCNF. |
| cart_items | `(customer_id,product_id) → quantity,added_at` | Full composite key determines each cart fact: BCNF. |

### Redundant and derived fields

- `products.avg_rating` and `products.review_count` are cached review aggregates derivable from `product_reviews`. They make product-page reads cheap but can drift; the schema enforces only the safe null/zero relationship, not equality to a mutable aggregate.
- `order_items.seller_id` is derivable from the current `products.seller_id`. It is retained as the historical fulfilment/seller snapshot and is additionally protected by the composite FK, which produced 0 mismatches in the supplied export.
- `orders.total_amount` is derivable from `sum(order_items.quantity * unit_price)` (subject to business treatment of taxes/shipping/discounts not exported). It is retained as an order-header snapshot for reporting and checkout. A cross-row equality check would require a trigger and is intentionally outside CP1.

## Data-quality findings and assumptions

- All 30,000 customers have exactly one default address (no exception). The unique partial index enforces at most one; requiring at least one needs a cross-table/deferred rule and is documented rather than implemented with a trigger.
- 5,882 orders have `address_id` null, and the integrity query found zero non-digital items among them. This is the supplied digital-product exception. It cannot be expressed as a simple declarative check spanning order items, products, and categories.
- 7,968 products have a null `avg_rating`; every one has `review_count=0`, which motivated the rating-summary check.
- 21,034 customers are not Prime and have null `prime_since`; no source row violated the paired Prime rule.
- 13,926 orders have null `shipped_at`; 9,354 have null `delivered_at`. The source obeyed all non-null timestamp ordering checks, but status-to-timestamp implication is deliberately not overconstrained because the workload changes a packed order to shipped.
- 1,388 return refunds are null, all on non-REFUNDED statuses; every REFUNDED row has a positive amount.
- `product_reviews.verified_purchase` is an assertion, not a foreign-key proof: the given trust-and-safety workload intentionally searches for asserted verified reviews without a matching delivered purchase.
