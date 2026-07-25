-- SQL for App Functions Update (v2)

-- Add cod_note to orders
ALTER TABLE orders ADD COLUMN cod_note TEXT NULL AFTER payment_method;

-- Add image_url to products
ALTER TABLE products ADD COLUMN image_url VARCHAR(255) NULL AFTER name;

-- Ensure status supports 'cancelled'
-- If status is ENUM, you might need to update it, but usually it's VARCHAR in this project.
