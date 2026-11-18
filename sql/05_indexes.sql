-- =========================================================
-- CP3: DATABASE OPTIMIZATION
-- Amazon Online Shopping Database
-- PostgreSQL 15+
-- =========================================================

SET search_path TO amazon;

-- Required for substring searches using ILIKE
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =========================================================
-- 1. CATEGORY INDEXES
-- R02: Recursive category hierarchy
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_categories_parent
ON categories(parent_category_id);


-- =========================================================
-- 2. PRODUCT INDEXES
-- R01, R02, R07, R14, R19, W03
-- =========================================================

-- R01: Product title substring search
CREATE INDEX IF NOT EXISTS idx_products_title_trgm
ON products USING GIN (title gin_trgm_ops)
WHERE status = 'ACTIVE';

-- R02: Category filtering and price range
CREATE INDEX IF NOT EXISTS idx_products_category_price
ON products(category_id, price)
WHERE status = 'ACTIVE';

-- R07: Seller's low-stock products
CREATE INDEX IF NOT EXISTS idx_products_seller_stock
ON products(seller_id, stock_qty)
WHERE status IN ('ACTIVE', 'OUT_OF_STOCK');

-- W03: Seller and category filtering
CREATE INDEX IF NOT EXISTS idx_products_seller_category
ON products(seller_id, category_id);

-- R14: Discount sorting by price/MRP ratio
CREATE INDEX IF NOT EXISTS idx_products_discount_ratio
ON products((price / mrp))
WHERE status = 'ACTIVE';


-- =========================================================
-- 3. ORDER INDEXES
-- R04, R05, R06, R09, R10, R13, R15,
-- R18, R20, R21, R22, R17, W05
-- =========================================================

-- Customer order history
CREATE INDEX IF NOT EXISTS idx_orders_customer_date
ON orders(customer_id, ordered_at DESC)
INCLUDE (status, total_amount);

-- Date-based reports, date filtering and pagination
CREATE INDEX IF NOT EXISTS idx_orders_ordered_at
ON orders(ordered_at DESC)
INCLUDE (customer_id, status, total_amount, shipped_at, delivered_at);

-- R05: Find older shipped orders
CREATE INDEX IF NOT EXISTS idx_orders_shipped_date
ON orders(shipped_at)
WHERE status = 'SHIPPED';

-- R13: Find addresses used by orders
CREATE INDEX IF NOT EXISTS idx_orders_address
ON orders(address_id)
WHERE address_id IS NOT NULL;

-- R17: Find delivered or returned orders by customer
-- CREATE INDEX IF NOT EXISTS idx_orders_customer_completed
-- ON orders(customer_id, order_id)
-- WHERE status IN ('DELIVERED', 'RETURNED');

-- W05: Find the oldest packed order
CREATE INDEX IF NOT EXISTS idx_orders_packed
ON orders(order_id)
WHERE status = 'PACKED';


-- =========================================================
-- 4. ORDER ITEM INDEXES
-- R06, R08, R11, R12, R15, R17, R19
-- =========================================================

-- Seller sales and seller performance
CREATE INDEX IF NOT EXISTS idx_order_items_seller_order
ON order_items(seller_id, order_id)
INCLUDE (product_id, quantity, unit_price);

-- Product sales aggregation and frequently bought together
CREATE INDEX IF NOT EXISTS idx_order_items_product_order
ON order_items(product_id, order_id)
INCLUDE (quantity);

-- Frequently bought together: find products in the same order
CREATE INDEX IF NOT EXISTS idx_order_items_order_product
ON order_items(order_id, product_id)
INCLUDE (quantity);


-- =========================================================
-- 5. PRODUCT REVIEW INDEXES
-- R03, R16, R17
-- =========================================================

-- Rating breakdown
CREATE INDEX IF NOT EXISTS idx_reviews_product_rating
ON product_reviews(product_id, rating);

-- Review body substring search
CREATE INDEX IF NOT EXISTS idx_reviews_body_trgm
ON product_reviews USING GIN (body gin_trgm_ops);

-- Verified reviews by customer and product
CREATE INDEX IF NOT EXISTS idx_reviews_verified_customer_product
ON product_reviews(customer_id, product_id)
WHERE verified_purchase = TRUE;


-- =========================================================
-- 6. CUSTOMER INDEXES
-- R18
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_customers_city_customer
ON customers(city_id, customer_id);


-- =========================================================
-- 7. CART INDEXES
-- R10, W06
-- =========================================================

CREATE INDEX IF NOT EXISTS idx_cart_items_added
ON cart_items(added_at);

-- =========================================================
-- UPDATE STATISTICS
-- =========================================================

ANALYZE;

-- =========================================================
-- END OF CP3 INDEXES
-- =========================================================
