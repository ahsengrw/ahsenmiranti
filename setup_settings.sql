CREATE TABLE IF NOT EXISTS settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(50) UNIQUE NOT NULL,
    setting_value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO settings (setting_key, setting_value) VALUES
('intro_offer_enabled', '1'),
('express_delivery_fee', '50.00'),
('delivery_cutoff_time', '17:00'),
('express_cutoff_time', '12:00'),
('intro_price_lm', '1.00'),
('normal_price_lm', '1.30'),
('stripe_enabled', '1'),
('stripe_publishable_key', ''),
('stripe_secret_key', ''),
('stripe_surcharge_percent', '2.9'),
('stripe_surcharge_fixed', '0.30');
