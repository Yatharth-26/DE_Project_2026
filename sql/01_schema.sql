-- CP1: Amazon Online Shopping schema. Run from the repository root with psql.
CREATE SCHEMA amazon;
SET search_path TO amazon;

CREATE TABLE cities (
    city_id       integer PRIMARY KEY,
    city_name     varchar(50) NOT NULL UNIQUE,
    state         varchar(50) NOT NULL
);

CREATE TABLE categories (
    category_id        integer PRIMARY KEY,
    category_name      varchar(100) NOT NULL UNIQUE,
    parent_category_id integer REFERENCES categories(category_id) ON DELETE RESTRICT,
    is_digital         boolean NOT NULL,
    CONSTRAINT chk_categories_not_own_parent CHECK (parent_category_id IS NULL OR parent_category_id <> category_id)
);

CREATE TABLE sellers (
    seller_id     integer PRIMARY KEY,
    business_name varchar(150) NOT NULL,
    gstin         char(15) NOT NULL UNIQUE,
    city_id       integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    joined_on     date NOT NULL,
    seller_rating numeric(2,1) NOT NULL,
    status        varchar(10) NOT NULL,
    CONSTRAINT chk_sellers_gstin_format CHECK (gstin ~ '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9]Z[0-9]$'),
    CONSTRAINT chk_sellers_rating CHECK (seller_rating BETWEEN 1.0 AND 5.0),
    CONSTRAINT chk_sellers_status CHECK (status IN ('ACTIVE', 'CLOSED', 'SUSPENDED'))
);

CREATE TABLE products (
    product_id        integer PRIMARY KEY,
    asin              char(10) NOT NULL UNIQUE,
    seller_id         integer NOT NULL REFERENCES sellers(seller_id) ON DELETE RESTRICT,
    category_id       integer NOT NULL REFERENCES categories(category_id) ON DELETE RESTRICT,
    title             varchar(255) NOT NULL,
    brand             varchar(100) NOT NULL,
    mrp               numeric(12,2) NOT NULL,
    price             numeric(12,2) NOT NULL,
    stock_qty         integer NOT NULL,
    is_prime_eligible boolean NOT NULL,
    avg_rating        numeric(2,1),
    review_count      integer NOT NULL,
    listed_on         date NOT NULL,
    status            varchar(20) NOT NULL,
    CONSTRAINT uq_products_product_seller UNIQUE (product_id, seller_id),
    CONSTRAINT chk_products_asin_format CHECK (asin ~ '^B[0-9A-Z]{9}$'),
    CONSTRAINT chk_products_money CHECK (mrp > 0 AND price > 0 AND price <= mrp),
    CONSTRAINT chk_products_stock CHECK (stock_qty >= 0),
    CONSTRAINT chk_products_status CHECK (status IN ('ACTIVE', 'INACTIVE', 'OUT_OF_STOCK')),
    CONSTRAINT chk_products_rating_summary CHECK (
        (review_count = 0 AND avg_rating IS NULL) OR
        (review_count > 0 AND avg_rating BETWEEN 1.0 AND 5.0)
    )
);

CREATE TABLE customers (
    customer_id integer PRIMARY KEY,
    full_name   varchar(150) NOT NULL,
    email       varchar(254) NOT NULL UNIQUE,
    phone       char(10) NOT NULL UNIQUE,
    city_id     integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    signup_date date NOT NULL,
    is_prime    boolean NOT NULL,
    prime_since date,
    CONSTRAINT chk_customers_email_format CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
    CONSTRAINT chk_customers_phone_format CHECK (phone ~ '^[6-9][0-9]{9}$'),
    CONSTRAINT chk_customers_prime_since CHECK (
        (is_prime AND prime_since IS NOT NULL AND prime_since >= signup_date) OR
        (NOT is_prime AND prime_since IS NULL)
    )
);

CREATE TABLE addresses (
    address_id  integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    label       varchar(10) NOT NULL,
    line1       varchar(255) NOT NULL,
    city_id     integer NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    pincode     char(6) NOT NULL,
    is_default  boolean NOT NULL,
    CONSTRAINT uq_addresses_id_customer UNIQUE (address_id, customer_id),
    CONSTRAINT chk_addresses_label CHECK (label IN ('HOME', 'WORK')),
    CONSTRAINT chk_addresses_pincode_format CHECK (pincode ~ '^[1-9][0-9]{5}$')
);
-- An integrity index, rather than a tuning index: one default address per customer.
CREATE UNIQUE INDEX uq_addresses_one_default_per_customer
    ON addresses (customer_id) WHERE is_default;

CREATE TABLE orders (
    order_id       integer PRIMARY KEY,
    customer_id    integer NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    address_id     integer,
    ordered_at     timestamptz NOT NULL,
    payment_method varchar(20) NOT NULL,
    total_amount   numeric(14,2) NOT NULL,
    status         varchar(20) NOT NULL,
    shipped_at     timestamptz,
    delivered_at   timestamptz,
    CONSTRAINT fk_orders_address_owner FOREIGN KEY (address_id, customer_id)
        REFERENCES addresses(address_id, customer_id) ON DELETE RESTRICT,
    CONSTRAINT chk_orders_payment_method CHECK (payment_method IN ('CARD', 'COD', 'EMI', 'GIFT_CARD', 'NETBANKING', 'UPI')),
    CONSTRAINT chk_orders_total_amount CHECK (total_amount > 0),
    CONSTRAINT chk_orders_status CHECK (status IN ('CANCELLED', 'DELIVERED', 'OUT_FOR_DELIVERY', 'PACKED', 'PLACED', 'RETURNED', 'SHIPPED')),
    CONSTRAINT chk_orders_shipped_after_ordered CHECK (shipped_at IS NULL OR shipped_at >= ordered_at),
    CONSTRAINT chk_orders_delivered_after_ordered CHECK (delivered_at IS NULL OR delivered_at >= ordered_at),
    CONSTRAINT chk_orders_delivery_after_shipping CHECK (delivered_at IS NULL OR shipped_at IS NULL OR delivered_at >= shipped_at)
);

CREATE TABLE order_items (
    order_id   integer NOT NULL REFERENCES orders(order_id) ON DELETE RESTRICT,
    line_no    smallint NOT NULL,
    product_id integer NOT NULL,
    seller_id  integer NOT NULL REFERENCES sellers(seller_id) ON DELETE RESTRICT,
    quantity   smallint NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    PRIMARY KEY (order_id, line_no),
    CONSTRAINT fk_order_items_product_seller FOREIGN KEY (product_id, seller_id)
        REFERENCES products(product_id, seller_id) ON DELETE RESTRICT,
    CONSTRAINT chk_order_items_line_no CHECK (line_no > 0),
    CONSTRAINT chk_order_items_quantity CHECK (quantity > 0),
    CONSTRAINT chk_order_items_unit_price CHECK (unit_price > 0)
);

CREATE TABLE returns (
    return_id     integer PRIMARY KEY,
    order_id      integer NOT NULL,
    line_no       smallint NOT NULL,
    reason        varchar(30) NOT NULL,
    requested_at  timestamptz NOT NULL,
    status        varchar(20) NOT NULL,
    refund_amount numeric(12,2),
    CONSTRAINT uq_returns_order_line UNIQUE (order_id, line_no),
    CONSTRAINT fk_returns_order_item FOREIGN KEY (order_id, line_no)
        REFERENCES order_items(order_id, line_no) ON DELETE RESTRICT,
    CONSTRAINT chk_returns_reason CHECK (reason IN ('DAMAGED', 'NOT_AS_DESCRIBED', 'NO_LONGER_NEEDED', 'QUALITY_ISSUE', 'SIZE_ISSUE', 'WRONG_ITEM')),
    CONSTRAINT chk_returns_status CHECK (status IN ('PICKED_UP', 'REFUNDED', 'REJECTED', 'REQUESTED')),
    CONSTRAINT chk_returns_refund CHECK (
        (status = 'REFUNDED' AND refund_amount IS NOT NULL AND refund_amount > 0) OR
        (status <> 'REFUNDED' AND refund_amount IS NULL)
    )
);

CREATE TABLE product_reviews (
    review_id         integer PRIMARY KEY,
    product_id        integer NOT NULL REFERENCES products(product_id) ON DELETE RESTRICT,
    customer_id       integer NOT NULL REFERENCES customers(customer_id) ON DELETE RESTRICT,
    rating            smallint NOT NULL,
    title             varchar(100) NOT NULL,
    body              text,
    verified_purchase boolean NOT NULL,
    helpful_votes     integer NOT NULL,
    created_at        timestamptz NOT NULL,
    CONSTRAINT chk_product_reviews_rating CHECK (rating BETWEEN 1 AND 5),
    CONSTRAINT chk_product_reviews_helpful_votes CHECK (helpful_votes >= 0)
);

CREATE TABLE cart_items (
    customer_id integer NOT NULL REFERENCES customers(customer_id) ON DELETE CASCADE,
    product_id  integer NOT NULL REFERENCES products(product_id) ON DELETE CASCADE,
    quantity    smallint NOT NULL,
    added_at    timestamptz NOT NULL,
    PRIMARY KEY (customer_id, product_id),
    CONSTRAINT chk_cart_items_quantity CHECK (quantity > 0)
);
