
-- ============================================================
-- Amazon Online Shopping Database
-- CP1: Load seed data
-- ============================================================

SET search_path TO amazon;

-- Parent tables first
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true);
\copy categories FROM 'seed_data/categories.csv' WITH (FORMAT csv, HEADER true);
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true);
\copy sellers FROM 'seed_data/sellers.csv' WITH (FORMAT csv, HEADER true);

-- Tables depending on customers and cities
\copy addresses FROM 'seed_data/addresses.csv' WITH (FORMAT csv, HEADER true);

-- Products depend on sellers and categories
\copy products FROM 'seed_data/products.csv' WITH (FORMAT csv, HEADER true);

-- Orders and their dependent tables
\copy orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true);
\copy order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true);
\copy returns FROM 'seed_data/returns.csv' WITH (FORMAT csv, HEADER true);

-- Independent dependent records
\copy product_reviews FROM 'seed_data/product_reviews.csv' WITH (FORMAT csv, HEADER true);
\copy cart_items FROM 'seed_data/cart_items.csv' WITH (FORMAT csv, HEADER true);

ANALYZE;
