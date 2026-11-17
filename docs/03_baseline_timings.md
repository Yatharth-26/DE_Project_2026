# Phase 3: Baseline Query Timings

## How We Measured

- **Tool:** `EXPLAIN (ANALYZE, BUFFERS)` in PostgreSQL — this actually runs the query and reports the real execution time plus how many memory pages were read.
- **Runs:** Every query was run **3 times**. The average of the three times is recorded.
- **Write queries (W01–W06):** Run inside `BEGIN; … ROLLBACK;` so the data is **never changed**. The changes are rolled back after timing.
- **Script used:** `benchmarks/run_benchmark.sh amazon_db baseline 3`
- **Raw plans:** Saved in `benchmarks/results/baseline/R01.txt` … `W06.txt` (all 30 files).
- **Date run:** 17 November 2026
- **Machine:** Same laptop used for all phases.

> **Important (R19):** The README warns that one query takes several seconds. R19 uses two correlated subqueries, one per product row (~937 rows), causing ~2.9 million shared buffer reads. Average time: **9,078 ms (~9 seconds)**. This is intentional and was let to finish as instructed.

---

## Results Table

| Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| R01: Search box – active products whose title contains "wireless", best rated first | READ | 19.630 | 16.457 | 14.438 | **16.842** |
| R02: Category browse – everything under "Electronics" priced ₹1,000–₹5,000 | READ | 3.380 | 3.184 | 2.785 | **3.116** |
| R03: Product page – rating breakdown for product 4321 | READ | 1.635 | 1.106 | 1.098 | **1.280** |
| R04: "Your Orders" – customer 1042's orders with item counts | READ | 4.310 | 3.159 | 3.066 | **3.512** |
| R05: Logistics – shipments in transit for more than 10 days | READ | 4.478 | 4.348 | 4.740 | **4.522** |
| R06: Seller Central – seller 217's order lines in June 2026 | READ | 7.762 | 4.787 | 5.056 | **5.868** |
| R07: Seller Central – seller 217's low-stock products | READ | 0.466 | 0.341 | 0.309 | **0.372** |
| R08: Merchandising – top 5 best-selling products per sub-category, last 30 days | READ | 21.956 | 22.038 | 22.442 | **22.145** |
| R09: Prime team – average order value Prime vs non-Prime per month in 2026 | READ | 22.440 | 22.503 | 22.483 | **22.475** |
| R10: Marketing – abandoned carts untouched since May 2026 | READ | 16.201 | 15.595 | 15.527 | **15.774** |
| R11: Product page – "Frequently bought together" with product 4321 | READ | 4.616 | 4.606 | 4.279 | **4.500** |
| R12: Category managers – return rate per top-level category | READ | 60.633 | 58.261 | 58.524 | **59.139** |
| R13: Data clean-up – saved addresses never used for any order | READ | 16.366 | 14.919 | 15.045 | **15.443** |
| R14: Deals page – active products at less than half of MRP, biggest discount first | READ | 3.750 | 3.768 | 3.578 | **3.699** |
| R15: Seller performance – top 20 sellers by revenue in 2026 (≥50 lines) | READ | 21.936 | 21.587 | 21.814 | **21.779** |
| R16: Review insights – Electronics reviews mentioning "battery" | READ | 12.078 | 11.949 | 12.057 | **12.028** |
| R17: Trust & Safety – verified-purchase reviews with no matching delivered order | READ | 49.852 | 49.873 | 49.714 | **49.813** |
| R18: Customer analytics – Mumbai customers in 4 spending tiers (2026) | READ | 8.988 | 8.881 | 9.232 | **9.034** |
| R19: Category report – every Mobile phone, last sale date and units sold (all time) | READ | 9058.713 | 9071.694 | 9103.756 | **9078.054** |
| R20: Finance – daily GMV and running total for June 2026 | READ | 6.801 | 7.109 | 6.881 | **6.930** |
| R21: Logistics – June 2026 deliveries that took more than 5 days | READ | 4.721 | 4.868 | 4.674 | **4.754** |
| R22: Admin – "All orders" newest first, page 3,001 (25 rows, OFFSET 75000) | READ | 24.508 | 24.750 | 24.494 | **24.584** |
| R23: Order details page – one order with lines, products and sellers | READ | 0.076 | 0.067 | 0.076 | **0.073** |
| R24: Product lookup by ASIN | READ | 0.025 | 0.024 | 0.022 | **0.024** |
| W01: Checkout – create a new order | WRITE | 0.974 | 0.521 | 0.540 | **0.678** |
| W02: Checkout – reduce stock of product 4322 | WRITE | 0.378 | 0.591 | 0.177 | **0.382** |
| W03: Seller Central – 10% price cut on seller 217's Watches | WRITE | 0.456 | 0.443 | 0.433 | **0.444** |
| W04: Big sale – insert 5,000 cart items in one batch | WRITE | 88.518 | 37.420 | 28.016 | **51.318** |
| W05: Logistics – mark oldest PACKED order as SHIPPED | WRITE | 7.181 | 7.203 | 7.030 | **7.138** |
| W06: Nightly clean-up – delete cart items older than 90 days | WRITE | 6.372 | 5.800 | 5.409 | **5.860** |
| **Total (sum of all 30 averages)** | | | | | **9,436.455** |

---

## Per-Query Scan Type and Explanation

Below is the scan type (from `EXPLAIN` output) and a plain-language explanation for each query.

---

### R01 — Search box: products with "wireless" in title
**Scan:** `Seq Scan on products`  
**Shared buffers hit:** 481 pages (all from cache)  
**Why slow/fast:** A `ILIKE '%wireless%'` pattern with a wildcard on **both** sides cannot use a B-tree index. PostgreSQL must read all 30,000 product rows and check each title. 2,727 rows match; the rest (27,273) are discarded. Average: **16.842 ms**.

---

### R02 — Category browse: Electronics, price ₹1,000–₹5,000
**Scan:** `Seq Scan on categories`, `Seq Scan on products`  
**Why fast:** Only 40 category rows exist — the recursive CTE is instant. The product scan filters by category_id and price range across 30,000 rows but finishes quickly. Average: **3.116 ms**.

---

### R03 — Rating breakdown for product 4321
**Scan:** `Seq Scan on product_reviews`  
**Why fast:** Only 38,662 reviews exist. PostgreSQL scans them, filters by product_id = 4321, and groups by rating. With no index on product_id the whole table is scanned, but it is small and already in memory. Average: **1.280 ms**.

---

### R04 — Customer 1042's order history
**Scan:** `Seq Scan on orders`, `Index Only Scan using pk_order_items on order_items`  
**Why moderate:** 120,000 orders are scanned to find customer 1042's records. The join to order_items reuses the primary-key index (very fast). The bottleneck is the full sequential scan of orders. Average: **3.512 ms**.

---

### R05 — Shipments in transit more than 10 days
**Scan:** `Seq Scan on orders`  
**Why moderate:** No index exists on `status` or `shipped_at`, so all 120,000 orders are read to find rows where `status = 'SHIPPED' AND shipped_at < '2026-06-20'`. Average: **4.522 ms**.

---

### R06 — Seller 217's order lines in June 2026
**Scan:** `Seq Scan on order_items`, `Index Scan using orders_pkey on orders`  
**Why moderate:** All 240,000 order_items rows are scanned to find seller 217's lines. Each matching row then looks up the order date via the primary-key index. `date_trunc('month', ordered_at)` prevents using an index on `ordered_at` directly. Average: **5.868 ms**.

---

### R07 — Seller 217's low-stock products
**Scan:** `Index Scan using uq_product_seller_pair on products`  
**Why fast:** PostgreSQL uses the unique index on `(product_id, seller_id)` to jump directly to seller 217's products (~20 rows). Then it checks `stock_qty <= 20`. Very few rows returned. Average: **0.372 ms**.

---

### R08 — Top 5 best-selling products per sub-category (last 30 days)
**Scan:** `Seq Scan on order_items`, `Seq Scan on orders`, `Seq Scan on products`  
**Why slow:** This query joins three large tables (240,000 + 120,000 + 30,000 rows) with no indexes on the join/filter columns. The `RANK()` window function then processes all grouped results. Average: **22.145 ms**.

---

### R09 — Average order value Prime vs non-Prime per month in 2026
**Scan:** `Seq Scan on orders`, `Seq Scan on customers`  
**Why moderate:** Both large tables (120,000 + 30,000 rows) are scanned. The join is on `customer_id`. No index exists on `ordered_at` for year filtering, so all rows are read and filtered. Average: **22.475 ms**.

---

### R10 — Abandoned carts not updated since May 2026
**Scan:** `Seq Scan on orders`, `Seq Scan on cart_items`, `Seq Scan on products`  
**Why moderate:** `NOT EXISTS` with a subquery on orders (120,000 rows) is evaluated for each cart_item customer. The cart_items table (44,998 rows) is scanned first; for each distinct customer, orders are checked. Average: **15.774 ms**.

---

### R11 — "Frequently bought together" with product 4321
**Scan:** `Seq Scan on order_items`, `Index Scan using pk_order_items on order_items`  
**Why fast:** A self-join on order_items. First, all rows where `product_id = 4321` are found via sequential scan (few rows match). For each, the other items in the same order are found via the primary-key index. Average: **4.500 ms**.

---

### R12 — Return rate per top-level category
**Scan:** `Seq Scan on order_items`, `Seq Scan on products`, `Seq Scan on categories`, `Seq Scan on returns`  
**Why slowest read (after R19):** Four tables are joined without covering indexes. All 240,000 order_items rows are read, joined to products, then to categories (twice — sub and parent), then LEFT JOIN to returns. This is the most expensive multi-table join in the workload. Average: **59.139 ms**.

---

### R13 — Unused saved addresses
**Scan:** `Seq Scan on addresses`, `Seq Scan on orders`  
**Why moderate:** `NOT IN (SELECT address_id FROM orders)` causes PostgreSQL to build a full list of all address_ids used in orders (120,000 rows), then check each of the 45,000 address rows against it. Average: **15.443 ms**.

---

### R14 — Products selling at less than half MRP
**Scan:** `Seq Scan on products`  
**Why fast:** A simple filter on 30,000 product rows using arithmetic (`price < mrp * 0.5`). No index can help arithmetic conditions on two columns without an expression index. Fast because products table is small. Average: **3.699 ms**.

---

### R15 — Top 20 sellers by revenue in 2026
**Scan:** `Seq Scan on order_items`, `Seq Scan on orders`, `Seq Scan on sellers`  
**Why moderate:** Three tables joined, 240,000 order_items rows processed. The `HAVING count(*) >= 50` filter reduces the final set, but the initial aggregation must process all matching rows. Average: **21.779 ms**.

---

### R16 — Electronics reviews mentioning "battery"
**Scan:** `Seq Scan on product_reviews`, `Seq Scan on products`, `Seq Scan on categories`  
**Why moderate:** `ILIKE '%battery%'` cannot use a B-tree index (wildcard on both sides), so all 38,662 review bodies are checked. Products and categories are joined for the Electronics filter. Average: **12.028 ms**.

---

### R17 — Fake verified-purchase reviews
**Scan:** `Seq Scan on order_items`, `Seq Scan on orders`, `Seq Scan on product_reviews`  
**Why slow:** For each verified review (many rows), `NOT EXISTS` checks whether that customer has a delivered order for that product. This is a correlated subquery evaluated for every review row, touching orders and order_items each time. Average: **49.813 ms**.

---

### R18 — Mumbai customers in 4 spending tiers
**Scan:** `Seq Scan on orders`, `Seq Scan on customers`  
**Why fast:** Only Mumbai customers (`city_id = 2`) in 2026 are aggregated; the customer table is scanned once and the join to orders narrows the set quickly. `NTILE(4)` runs on the small result set. Average: **9.034 ms**.

---

### R19 — Every Mobile phone: last sale date and units sold
**Scan:** `Seq Scan on categories`, `Seq Scan on products`, `Seq Scan on order_items`, `Index Scan using orders_pkey on orders`  
**Shared buffers hit:** 2,991,908 pages (the highest in the workload)  
**Why very slow (intentional):** This query has **two correlated subqueries** inside `SELECT`. For each of the ~937 Mobile products, PostgreSQL runs a full sequential scan of all 240,000 order_items rows — once to find `max(ordered_at)` and once to find `sum(quantity)`. That is 937 × 2 × 240,000 = ~450 million row-checks. Average: **9,078.054 ms (~9 seconds)**. The README explicitly warns this will be slow and instructs us to let it finish.

---

### R20 — Daily GMV and running total for June 2026
**Scan:** `Seq Scan on orders`  
**Why fast:** A date-range filter on `ordered_at` for June 2026. Only ~20,000 orders (roughly 1 month of 18 months) are in this range. The window function (`SUM OVER`) runs on only 30 rows (one per day). Average: **6.930 ms**.

---

### R21 — June 2026 deliveries taking more than 5 days
**Scan:** `Seq Scan on orders`  
**Why fast:** A sequential scan filters on `ordered_at >= '2026-06-01'` and `delivered_at > ordered_at + interval '5 days'`. The date arithmetic is applied row by row but only to the ~20,000 June orders. Average: **4.754 ms**.

---

### R22 — "All orders", page 3,001 (OFFSET 75,000)
**Scan:** `Seq Scan on orders`  
**Why moderate:** `OFFSET 75000` forces PostgreSQL to read and sort **all** 120,000 orders (by `ordered_at DESC`) and then discard the first 75,000, returning only 25 rows. The more pages you go, the slower it gets — this is the classic OFFSET pagination problem. Average: **24.584 ms**.

---

### R23 — Full order details for order 100001
**Scan:** `Index Scan using pk_order_items`, `Index Scan using orders_pkey`, `Index Scan using uq_product_seller_pair on products`, `Index Scan using sellers_pkey on sellers`  
**Why very fast:** Four joins, all resolved via primary-key or unique-key index lookups. Only a handful of rows are returned. All indexes hit cache. Average: **0.073 ms**.

---

### R24 — Product lookup by ASIN
**Scan:** `Index Scan using products_asin_key on products`  
**Why fastest read:** A single equality lookup on the UNIQUE index on `asin`. Finds exactly one row in nanoseconds. Average: **0.024 ms**.

---

### W01 — Insert a new order
**Scan:** (no scan — it is an INSERT)  
**Why fast:** Inserts one row into orders. Primary-key check is done via index lookup (not a scan). Rolled back after timing. Average: **0.678 ms**.

---

### W02 — Reduce stock of product 4322
**Scan:** `Index Scan using uq_product_seller_pair on products`  
**Why fast:** An UPDATE filtered by `product_id = 4322` — resolved via index to one row. Rolled back. Average: **0.382 ms**.

---

### W03 — 10% price cut on seller 217's Watches
**Scan:** `Seq Scan on categories`, `Index Scan using uq_product_seller_pair on products`  
**Why fast:** categories (40 rows) is scanned to find the "Watches" category, then seller 217's products in that category are found via index. Very few rows updated. Rolled back. Average: **0.444 ms**.

---

### W04 — Batch insert 5,000 cart items
**Scan:** (no scan — it is an INSERT … SELECT from generate_series)  
**Why highly variable:** The `ON CONFLICT DO NOTHING` clause checks the primary key for each of the 5,000 generated rows. Run 1 (88.5 ms) was much slower than Run 3 (28 ms) due to OS/disk variance on first execution (cold lock structures). Average: **51.318 ms**. Rolled back.

---

### W05 — Mark oldest PACKED order as SHIPPED
**Scan:** `Index Scan using orders_pkey on orders`  
**Why moderate:** The subquery `SELECT min(order_id) FROM orders WHERE status = 'PACKED'` requires a sequential scan to find PACKED orders (no index on status), then the outer UPDATE uses the primary-key index. Average: **7.138 ms**. Rolled back.

---

### W06 — Delete cart items older than 90 days
**Scan:** `Seq Scan on cart_items`  
**Why moderate:** No index on `added_at` in cart_items, so all 44,998 rows are scanned and those with `added_at < '2026-04-02'` are deleted. Average: **5.860 ms**. Rolled back.

---

## Summary: Slowest and Fastest Queries

| Rank | Query | Avg (ms) | Reason |
|------|-------|---:|--------|
| Slowest | R19 | 9,078.054 | Two correlated subqueries × 937 products |
| 2nd slowest | R12 | 59.139 | 4-table join, all sequential scans |
| 3rd slowest | R17 | 49.813 | Correlated NOT EXISTS across orders + order_items |
| 4th slowest | W04 | 51.318 | Batch insert of 5,000 rows with conflict check |
| Fastest | R24 | 0.024 | Single ASIN index lookup |
| 2nd fastest | R23 | 0.073 | All-index-scan 4-table join |
| 3rd fastest | W02 | 0.382 | Single row UPDATE via index |
