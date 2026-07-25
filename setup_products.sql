-- SQL to setup initial products based on requirements
-- 3000 mm pack = 120 l/m
-- 2800 mm pack = 112 l/m
-- Normal Price = $1.30 per L/M

TRUNCATE TABLE products;

INSERT INTO products (name, size_mm, bundle_length_lm, stock_quantity, price)
VALUES
('14mm Beading', 2800, 112, 100, 145.60), -- 112 * 1.30 = 145.60
('14mm Beading', 3000, 120, 5, 156.00);   -- 120 * 1.30 = 156.00
