# 04 — Query Optimization and Indexing Report

## 1. Introduction

This report documents the indexing and query optimization performed on the Amazon Online Shopping Database for Team T0083, Section D.

The objective was to improve query execution performance through appropriate indexing, SQL query rewriting, and execution-plan analysis.

The database was implemented using PostgreSQL and contains customer, product, seller, order, order-item, review, return, category, address, and cart data.

## 2. Experimental Environment

| Parameter | Configuration |
|---|---|
| Database | Amazon Online Shopping Database |
| DBMS | PostgreSQL 18.6 |
| Required version | PostgreSQL 15+ |
| Dataset | Provided project seed data |
| Read queries | 24 |
| Write queries | 6 |
| Baseline benchmark runs | 3 |
| Optimized benchmark runs | 5 |
| Execution analysis | EXPLAIN (ANALYZE, BUFFERS) |

The baseline benchmark was executed before applying the optimization indexes and query rewrites.

The optimized benchmark was executed using the final SQL files.

## 3. Indexing Strategy

Indexes were created to improve query performance by reducing unnecessary table scans and supporting frequently used filtering, joining, sorting, and aggregation operations.

The indexing strategy included:

### 3.1 Products

- Trigram GIN index on product titles for text searching.
- Composite index on category and price.
- Composite index on seller and stock quantity.
- Composite index on seller and category.
- Expression index on discount ratio.

### 3.2 Orders

- Composite index on customer ID and order date.
- Index on order date with included columns.
- Partial index on shipped orders.
- Partial index on non-null address IDs.
- Partial index on packed orders.

The customer-completed-orders partial index was tested but excluded from the final index configuration because it contributed to an inefficient execution plan for R17.

### 3.3 Order Items

- Composite index on seller and order ID.
- Composite index on product and order ID.
- Composite index on order and product ID.

### 3.4 Reviews

- Composite index on product ID and rating.
- Trigram GIN index on review body.
- Partial index on verified customer-product reviews.

### 3.5 Other Tables

Additional indexes were created for:
- Category parent relationships.
- Customer city relationships.
- Cart item timestamps.

The final index script contains 18 active index definitions, excluding the tested and commented-out R17 index.

## 4. Query Optimization Techniques

The following query rewrites were implemented in `sql/06_optimized_queries.sql`.

### R06 — Date Filtering

Replaced the `DATE_TRUNC`-based month filtering with a timestamp range condition.

This allows PostgreSQL to use an appropriate date index more effectively.

### R09 — Year Filtering

Replaced `EXTRACT(YEAR FROM ...)` with a timestamp range covering the required year.

This avoids applying a function to the indexed timestamp column.

### R13 — NULL-Safe Subquery

Replaced `NOT IN` with `NOT EXISTS` to avoid unexpected behavior when NULL values are present in subquery results.

### R19 — Category Sales Report

Replaced repeated correlated subqueries with a common table expression and aggregation.

Sales information is calculated by product and joined with the products belonging to the Mobiles category.

This produced one of the largest performance improvements in the workload.

### R20 — Date Range Optimization

Replaced date casting and `BETWEEN` filtering with a timestamp range.

This makes the condition more suitable for index-based filtering.

### R17 — Verified Purchase Validation

Multiple approaches were tested, including `NOT EXISTS`, materialized CTEs, and different join strategies.

The final version uses a materialized CTE without `DISTINCT` to avoid repeated index lookups and expensive aggregation.

Although this improved performance compared with earlier optimized attempts, it remained slower than the original baseline.

## 5. Benchmark Results

Execution times are averages in milliseconds.

| Query | Baseline | Optimized |
|---|---:|---:|
| R01 | 18.754 | 2.353 |
| R02 | 3.274 | 1.847 |
| R03 | 1.190 | 0.054 |
| R04 | 3.184 | 0.092 |
| R05 | 4.525 | 0.297 |
| R06 | 4.762 | 0.606 |
| R07 | 0.397 | 0.017 |
| R08 | 22.430 | 19.295 |
| R09 | 22.257 | 13.582 |
| R10 | 17.072 | 12.595 |
| R11 | 4.161 | 0.071 |
| R12 | 56.915 | 63.845 |
| R13 | 14.688 | 13.486 |
| R14 | 3.713 | 0.086 |
| R15 | 22.996 | 21.345 |
| R16 | 11.763 | 4.482 |
| R17 | 49.794 | 72.333 |
| R18 | 9.276 | 5.917 |
| R19 | 9014.770 | 53.695 |
| R20 | 6.110 | 1.224 |
| R21 | 4.733 | 0.950 |
| R22 | 24.969 | 6.570 |
| R23 | 0.070 | 0.059 |
| R24 | 0.027 | 0.030 |

### Write Query Results

| Query | Baseline | Optimized |
|---|---:|---:|
| W01 | 0.621 | 0.624 |
| W02 | 0.289 | 0.577 |
| W03 | 0.474 | 0.214 |
| W04 | 28.312 | 30.150 |
| W05 | 7.144 | 0.305 |
| W06 | 5.285 | 2.509 |

## 6. Performance Analysis

### 6.1 Major Improvements

The following queries demonstrated significant improvements:

- R19 improved from 9014.770 ms to 53.695 ms.
- R11 improved from 4.161 ms to 0.071 ms.
- R14 improved from 3.713 ms to 0.086 ms.
- R20 improved from 6.110 ms to 1.224 ms.
- R04 improved from 3.184 ms to 0.092 ms.

R19 achieved approximately 99.4% lower execution time after replacing correlated subqueries with aggregation and joins.

### 6.2 Queries with Regressions

Some queries became slower after optimization.

**R12:** Execution time increased from 56.915 ms to 63.845 ms. Its execution plan continued to use sequential scans and hash joins. The timing difference may be influenced by execution variability.

**R17:** Execution time increased from 49.794 ms to 72.333 ms. Several alternative execution plans were tested. The final plan reduced repeated index lookups and used a hash anti join, but materializing the customer-product pairs still required additional processing and temporary disk space.

**R24:** A small increase from 0.027 ms to 0.030 ms was observed. This difference is very small in absolute terms.

### 6.3 Write Performance

W03, W05, and W06 improved, while W01, W02, and W04 became slightly or substantially slower.

This demonstrates that additional indexes can improve read operations while introducing maintenance overhead for write operations.

## 7. Execution Plan Analysis

Execution plans were examined using:

`EXPLAIN (ANALYZE, BUFFERS)`

The analysis considered:

- Sequential scans.
- Index scans and index-only scans.
- Bitmap heap scans.
- Hash joins and anti joins.
- Buffer hits.
- Temporary disk reads and writes.
- Actual execution time.

The results show that indexes are not always beneficial. PostgreSQL may correctly choose sequential scans when a query needs to process a large portion of a table.

## 8. Limitations

1. Baseline timings were collected over three runs, while optimized timings were collected over five runs.
2. Execution times can vary due to caching, system activity, and query planning.
3. R12 and R17 remained slower than their baseline timings.
4. Some write operations experienced additional index-maintenance overhead.
5. Results represent the provided dataset and may differ on larger production datasets.

## 9. Conclusion

The optimization exercise demonstrated the importance of combining indexing with SQL query rewriting and execution-plan analysis.

Most read queries improved, with particularly significant gains in R19, R11, R14, and R20.

The results also demonstrate that excessive indexing and unsuitable query plans can negatively affect performance.

The final implementation provides substantial improvements across most of the workload while documenting the remaining performance regressions.

## 10. Deliverables

| File | Description |
|---|---|
| `sql/05_indexes.sql` | Final index definitions |
| `sql/06_optimized_queries.sql` | Optimized SQL workload |
| `benchmarks/results/baseline/` | Baseline execution plans |
| `benchmarks/results/optimized/` | Final optimized execution plans |
| `benchmarks/results/optimized/summary.csv` | Optimized benchmark summary |
| `docs/04_optimization_report.md` | This report |
