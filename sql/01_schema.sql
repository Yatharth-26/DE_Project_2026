
-- ============================================================
-- Amazon Online Shopping Database
-- CP1: Schema Design
-- PostgreSQL 15+
-- ============================================================

CREATE SCHEMA IF NOT EXISTS amazon;
SET search_path TO amazon;

-- 1. CITIES
CREATE TABLE cities (
    city_id     INTEGER PRIMARY KEY,
    city_name   VARCHAR(100) NOT NULL UNIQUE,
    state       VARCHAR(100) NOT NULL
);

-- 2. CATEGORIES
CREATE TABLE categories (
    category_id        INTEGER PRIMARY KEY,
    category_name      VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id INTEGER,
    is_digital         BOOLEAN NOT NULL,

    CONSTRAINT fk_category_parent
        FOREIGN KEY (parent_category_id)
        REFERENCES categories(category_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_category_not_own_parent
        CHECK (parent_category_id IS NULL
               OR parent_category_id <> category_id)
);

-- 3. CUSTOMERS
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    phone       VARCHAR(20) NOT NULL UNIQUE,
    city_id     INTEGER NOT NULL,
    signup_date DATE NOT NULL,
    is_prime    BOOLEAN NOT NULL,
    prime_since DATE,

    CONSTRAINT fk_customer_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_prime_date
        CHECK (
            (is_prime = TRUE AND prime_since IS NOT NULL)
            OR
            (is_prime = FALSE AND prime_since IS NULL)
        ),

    CONSTRAINT chk_prime_after_signup
        CHECK (prime_since IS NULL OR prime_since >= signup_date)
);

-- 4. SELLERS
CREATE TABLE sellers (
    seller_id     INTEGER PRIMARY KEY,
    business_name VARCHAR(200) NOT NULL,
    gstin         VARCHAR(15) NOT NULL UNIQUE,
    city_id       INTEGER NOT NULL,
    joined_on     DATE NOT NULL,
    seller_rating NUMERIC(2,1) NOT NULL,
    status        VARCHAR(20) NOT NULL,

    CONSTRAINT fk_seller_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_seller_rating
        CHECK (seller_rating BETWEEN 0 AND 5),

    CONSTRAINT chk_seller_status
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),

    CONSTRAINT chk_gstin_length
        CHECK (char_length(gstin) = 15)
);

-- 5. ADDRESSES
CREATE TABLE addresses (
    address_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    label       VARCHAR(20) NOT NULL,
    line1       VARCHAR(255) NOT NULL,
    city_id     INTEGER NOT NULL,
    pincode     VARCHAR(10) NOT NULL,
    is_default  BOOLEAN NOT NULL,

    CONSTRAINT fk_address_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_address_city
        FOREIGN KEY (city_id)
        REFERENCES cities(city_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_address_label
        CHECK (label IN ('HOME', 'WORK')),

    CONSTRAINT uq_address_customer_pair
        UNIQUE (address_id, customer_id)
);

-- 6. PRODUCTS
CREATE TABLE products (
    product_id        INTEGER PRIMARY KEY,
    asin              VARCHAR(20) NOT NULL UNIQUE,
    seller_id         INTEGER NOT NULL,
    category_id       INTEGER NOT NULL,
    title             VARCHAR(255) NOT NULL,
    brand             VARCHAR(100) NOT NULL,
    mrp               NUMERIC(12,2) NOT NULL,
    price             NUMERIC(12,2) NOT NULL,
    stock_qty         INTEGER NOT NULL,
    is_prime_eligible BOOLEAN NOT NULL,
    avg_rating        NUMERIC(2,1),
    review_count      INTEGER NOT NULL,
    listed_on         DATE NOT NULL,
    status            VARCHAR(20) NOT NULL,

    CONSTRAINT fk_product_seller
        FOREIGN KEY (seller_id)
        REFERENCES sellers(seller_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_product_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_product_price
        CHECK (price > 0 AND mrp >= price),

    CONSTRAINT chk_product_stock
        CHECK (stock_qty >= 0),

    CONSTRAINT chk_product_rating
        CHECK (avg_rating IS NULL OR avg_rating BETWEEN 1 AND 5),

    CONSTRAINT chk_product_review_count
        CHECK (review_count >= 0),

    CONSTRAINT chk_product_rating_count
        CHECK (
            (review_count = 0 AND avg_rating IS NULL)
            OR
            (review_count > 0 AND avg_rating IS NOT NULL)
        ),

    CONSTRAINT chk_product_status
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'OUT_OF_STOCK')),

    CONSTRAINT uq_product_seller_pair
        UNIQUE (product_id, seller_id)
);

-- 7. ORDERS
CREATE TABLE orders (
    order_id       INTEGER PRIMARY KEY,
    customer_id    INTEGER NOT NULL,
    address_id     INTEGER,
    ordered_at     TIMESTAMPTZ NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    total_amount   NUMERIC(12,2) NOT NULL,
    status         VARCHAR(30) NOT NULL,
    shipped_at     TIMESTAMPTZ,
    delivered_at   TIMESTAMPTZ,

    CONSTRAINT fk_order_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_customer_address
        FOREIGN KEY (address_id, customer_id)
        REFERENCES addresses(address_id, customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_payment_method
        CHECK (payment_method IN
            ('CARD', 'COD', 'EMI', 'GIFT_CARD', 'NETBANKING', 'UPI')),

    CONSTRAINT chk_order_amount
        CHECK (total_amount >= 0),

    CONSTRAINT chk_order_status
        CHECK (status IN (
            'PLACED', 'PACKED', 'SHIPPED',
            'OUT_FOR_DELIVERY', 'DELIVERED',
            'CANCELLED', 'RETURNED'
        )),

    CONSTRAINT chk_shipping_time
        CHECK (shipped_at IS NULL OR shipped_at >= ordered_at),

    CONSTRAINT chk_delivery_time
    CHECK (
        delivered_at IS NULL
        OR delivered_at >= ordered_at
    )
);

-- 8. ORDER ITEMS
CREATE TABLE order_items (
    order_id   INTEGER NOT NULL,
    line_no    SMALLINT NOT NULL,
    product_id INTEGER NOT NULL,
    seller_id  INTEGER NOT NULL,
    quantity   SMALLINT NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,

    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, line_no),

    CONSTRAINT fk_item_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_item_product_seller
        FOREIGN KEY (product_id, seller_id)
        REFERENCES products(product_id, seller_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_order_line_number
        CHECK (line_no > 0),

    CONSTRAINT chk_order_item_quantity
        CHECK (quantity > 0),

    CONSTRAINT chk_order_item_price
        CHECK (unit_price > 0)
);

-- 9. CART ITEMS
CREATE TABLE cart_items (
    customer_id INTEGER NOT NULL,
    product_id  INTEGER NOT NULL,
    quantity    SMALLINT NOT NULL,
    added_at    TIMESTAMPTZ NOT NULL,

    CONSTRAINT pk_cart_items
        PRIMARY KEY (customer_id, product_id),

    CONSTRAINT fk_cart_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_cart_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_cart_quantity
        CHECK (quantity > 0)
);

-- 10. PRODUCT REVIEWS
CREATE TABLE product_reviews (
    review_id         INTEGER PRIMARY KEY,
    product_id        INTEGER NOT NULL,
    customer_id       INTEGER NOT NULL,
    rating            SMALLINT NOT NULL,
    title             VARCHAR(255) NOT NULL,
    body              TEXT,
    verified_purchase BOOLEAN NOT NULL,
    helpful_votes     INTEGER NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_review_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_review_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_review_rating
        CHECK (rating BETWEEN 1 AND 5),

    CONSTRAINT chk_helpful_votes
        CHECK (helpful_votes >= 0)
);

-- 11. RETURNS
CREATE TABLE returns (
    return_id     INTEGER PRIMARY KEY,
    order_id      INTEGER NOT NULL,
    line_no       SMALLINT NOT NULL,
    reason        VARCHAR(40) NOT NULL,
    requested_at  TIMESTAMPTZ NOT NULL,
    status        VARCHAR(20) NOT NULL,
    refund_amount NUMERIC(12,2),

    CONSTRAINT fk_return_order_item
        FOREIGN KEY (order_id, line_no)
        REFERENCES order_items(order_id, line_no)
        ON DELETE RESTRICT,

    CONSTRAINT chk_return_reason
        CHECK (reason IN (
            'QUALITY_ISSUE', 'WRONG_ITEM', 'DAMAGED',
            'SIZE_ISSUE', 'NOT_AS_DESCRIBED', 'NO_LONGER_NEEDED'
        )),

    CONSTRAINT chk_return_status
        CHECK (status IN ('REQUESTED', 'PICKED_UP', 'REFUNDED', 'REJECTED')),

    CONSTRAINT chk_return_refund
        CHECK (
            (status = 'REFUNDED' AND refund_amount IS NOT NULL
             AND refund_amount > 0)
            OR
            (status <> 'REFUNDED' AND refund_amount IS NULL)
        )
);
