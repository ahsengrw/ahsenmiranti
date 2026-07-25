-- SQL for Home Page Redesign (v3)

-- Add keys to settings for dynamic content
INSERT IGNORE INTO settings (setting_key, setting_value) VALUES
('hero_banner_url', ''),
('welcome_description', 'Adelaide\'s dedicated Meranti beading delivery service. Our mission is to supply premium-quality Meranti beading with fast, reliable delivery across metropolitan Adelaide.');

-- Create product_images table
CREATE TABLE IF NOT EXISTS product_images (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT NOT NULL,
    image_url VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

-- Migrating existing images if any (optional, usually image_url in products is the primary one)
-- INSERT INTO product_images (product_id, image_url) SELECT id, image_url FROM products WHERE image_url IS NOT NULL;
