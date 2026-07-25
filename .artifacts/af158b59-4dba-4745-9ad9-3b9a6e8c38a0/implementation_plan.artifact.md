# Home Page Redesign & Dynamic Content Plan

This plan overhauls the customer-side home page based on the provided mockup and enables dynamic management of home page content and product images from the Admin Panel.

## Proposed Changes

### 1. Backend & Database (API)
#### [NEW] [update_v3.sql](file:///D:/Fiverr2024/merantibeading/update_v3.sql)
- Add `hero_banner_url` and `welcome_description` keys to the `settings` table.
- Create a `product_images` table to support multiple images per product.

#### [MODIFY] [SettingsController.php](file:///D:/Fiverr2024/merantibeading/backendadmin/api/Controllers/SettingsController.php)
- Update `updateSettings()` to handle image upload for the hero banner.

#### [MODIFY] [ProductController.php](file:///D:/Fiverr2024/merantibeading/backendadmin/api/Controllers/ProductController.php) & [Product.php](file:///D:/Fiverr2024/merantibeading/backendadmin/api/Models/Product.php)
- Update `addProduct()` and `editProduct()` to handle multiple image uploads.
- Update `getProducts()` to include all images for each product.

### 2. Admin Panel (Web)
#### [MODIFY] [index.php](file:///D:/Fiverr2024/merantibeading/backendadmin/admin/index.php)
- Add upload field for "Hero Banner" and textarea for "Welcome Description" in System Settings.
- Update product modal to allow multiple image selection.

#### [MODIFY] [app.js](file:///D:/Fiverr2024/merantibeading/backendadmin/admin/js/app.js)
- Update JS to handle multiple file uploads and the new setting fields.

### 3. Flutter App (Customer)
#### [MODIFY] [product.dart](file:///D:/Fiverr2024/merantibeading/lib/models/product.dart)
- Update model to support `List<String> imageUrls`.

#### [MODIFY] [home_view.dart](file:///D:/Fiverr2024/merantibeading/lib/screens/customer/home_view.dart)
- Complete UI overhaul to match the HTML mockup:
    - **Hero Section**: Dynamic image and welcome text from settings.
    - **1-Tap Order**: Redesigned card for recent orders.
    - **Product Card**:
        - Horizontal scrolling image gallery.
        - Redesigned length selection buttons.
        - "Buy Now" button with lightning icon.
    - **Features Section**: "Delivery Options" and "Live GPS Tracking" cards.
    - **Closing Message**: Styled box with a handshake icon.

## Verification Plan

### Manual Verification
1.  **Admin Panel**:
    - Upload a new Hero Banner and edit the Welcome Description.
    - Add/Edit a product with multiple images.
2.  **Home Page**:
    - Verify the Hero Section displays the uploaded banner and text.
    - Verify the Product Card shows a scrollable gallery of images.
    - Verify the "Select Length" buttons update the price and stock correctly.
    - Check the overall layout alignment and colors against the mockup.
