-- Run from the repository root: psql -d <database> -f sql/02_load_data.sql
SET search_path TO amazon;

\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true)
\copy categories FROM 'seed_data/categories.csv' WITH (FORMAT csv, HEADER true)
\copy sellers FROM 'seed_data/sellers.csv' WITH (FORMAT csv, HEADER true)
\copy products FROM 'seed_data/products.csv' WITH (FORMAT csv, HEADER true)
\copy customers FROM 'seed_data/customers.csv' WITH (FORMAT csv, HEADER true)
\copy addresses FROM 'seed_data/addresses.csv' WITH (FORMAT csv, HEADER true)
\copy orders FROM 'seed_data/orders.csv' WITH (FORMAT csv, HEADER true)
\copy order_items FROM 'seed_data/order_items.csv' WITH (FORMAT csv, HEADER true)
\copy returns FROM 'seed_data/returns.csv' WITH (FORMAT csv, HEADER true)
\copy product_reviews FROM 'seed_data/product_reviews.csv' WITH (FORMAT csv, HEADER true)
\copy cart_items FROM 'seed_data/cart_items.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;
