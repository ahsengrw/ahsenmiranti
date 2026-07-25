# Home Page Redesign & Content Management Walkthrough

I have completely overhauled the customer-side home page based on your HTML mockup and enabled dynamic content management from the Admin Panel.

## Changes Overview

### 1. Modern UI Overhaul (Customer App)
- **[MODIFY] [HomeView](file:///D:/Fiverr2024/merantibeading/lib/screens/customer/home_view.dart)**:
    - **Sticky Header**: Now features a blurred background and clean location display.
    - **Hero Section**: Includes a rounded banner with a gradient overlay and a dynamic title/description.
    - **1-Tap Order**: A high-contrast card for quick reordering of previous items.
    - **Product Experience**:
        - **Image Gallery**: Products now support multiple images. Users can swipe through them horizontally.
        - **Length Selector**: Premium-styled selection cards with real-time stock indicators and checkmark animations.
        - **Lightning Checkout**: A "Buy Now" button with bolt icon for immediate action.
    - **Feature Showcase**: Professional cards for "Delivery Options" and "Live GPS Tracking".
    - **Branded Closing**: A styled thank-you message with a handshake icon.

### 2. Dynamic Content Management (Admin Panel)
- **[MODIFY] [index.php](file:///D:/Fiverr2024/merantibeading/backendadmin/admin/index.php) & [app.js](file:///D:/Fiverr2024/merantibeading/backendadmin/admin/js/app.js)**:
    - **Home Page Settings**: Added an upload field for the **Hero Banner Image** and a text area for the **Welcome Description**.
    - **Multi-Image Upload**: Admins can now select and upload multiple images for each product simultaneously.
- **[MODIFY] [API](file:///D:/Fiverr2024/merantibeading/backendadmin/api/Controllers/ProductController.php)**:
    - Updated `SettingsController` and `ProductController` to handle file uploads and associate multiple images with products.

### 3. Backend & Data
- **[NEW] [update_v3.sql](file:///D:/Fiverr2024/merantibeading/update_v3.sql)**: Created a `product_images` table and added home page configuration keys to the `settings` table.
- **[MODIFY] [Product Model](file:///D:/Fiverr2024/merantibeading/lib/models/product.dart)**: Updated to handle a list of image URLs.

## How to Verify

### Database Setup
> [!IMPORTANT]
> Run the following SQL on your database to enable these features:
> ```sql
> INSERT IGNORE INTO settings (setting_key, setting_value) VALUES
> ('hero_banner_url', ''),
> ('welcome_description', 'Adelaide\'s dedicated Meranti beading delivery service...');
>
> CREATE TABLE IF NOT EXISTS product_images (
>     id INT AUTO_INCREMENT PRIMARY KEY,
>     product_id INT NOT NULL,
>     image_url VARCHAR(255) NOT NULL,
>     FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
> );
> ```

### Verification Steps
1.  **Admin Customization**:
    - Go to **System Settings**.
    - Upload a custom **Hero Banner** and edit the **Welcome Description**.
    - Go to **Products** and upload 2-3 images for a product.
2.  **App Experience**:
    - Open the app. The home page should match your mockup perfectly.
    - Swipe through the product images.
    - Select different lengths and notice the "Left in Stock" indicators and price updates.
    - Verify the "Buy Now" button proceeds to checkout as expected.

## Technical Highlights
- Uses `PageView` for efficient horizontal swiping in the product gallery.
- Implements `FormData` in the admin panel for reliable binary/file transmission to the PHP backend.
- Optimized image loading with error fallbacks to maintain a professional look even if images are missing.
