BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  price REAL NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  description TEXT,
  category TEXT,
  image_url TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE products ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;

DELETE FROM products;

INSERT INTO products (name, price, stock, description, category, image_url)
VALUES
  (
    'Vitumbuwa',
    35,
    100,
    'Sweet fried dough balls made from flour, sugar, and yeast, perfect as a starter or snack.',
    'Appetizers',
    'assets/images/vitumbuwa.jpg'
  ),
  (
    'Chikanda',
    55,
    60,
    'Traditional Zambian "African polony" made from wild orchid tubers, peanuts, and spices.',
    'Appetizers',
    'assets/images/chikanda.jpg'
  ),
  (
    'Samosas',
    45,
    120,
    'Crispy triangular pastries filled with spiced minced meat or vegetables.',
    'Appetizers',
    'assets/images/samosas.jpg'
  ),
  (
    'Nshima with Chicken and Vegetables',
    120,
    80,
    'Traditional staple made from maize meal served with grilled chicken and seasonal greens.',
    'Main Courses',
    'assets/images/nshima_chicken.jpg'
  ),
  (
    'T-Bone Steak with Nshima',
    160,
    50,
    'Grilled T-bone steak accompanied by nshima and tomato-onion relish.',
    'Main Courses',
    'assets/images/tbone_nshima.jpg'
  ),
  (
    'Ifisashi',
    95,
    70,
    'Creamy peanut and vegetable stew served with nshima.',
    'Main Courses',
    'assets/images/ifisashi.jpg'
  ),
  (
    'Kalembula',
    40,
    90,
    'Steamed pumpkin leaves cooked with tomatoes, onions, and groundnuts.',
    'Extras',
    'assets/images/kalembula.jpg'
  ),
  (
    'Chibwabwa',
    38,
    90,
    'Cooked pumpkin leaves prepared with groundnut powder.',
    'Extras',
    'assets/images/chibwabwa.jpg'
  ),
  (
    'Village Chicken Relish',
    85,
    65,
    'Free-range chicken cooked in a rich tomato and onion sauce.',
    'Extras',
    'assets/images/village_chicken_relish.jpg'
  ),
  (
    'Munkoyo',
    30,
    150,
    'Traditional fermented drink made from maize and munkoyo roots.',
    'Drinks',
    'assets/images/munkoyo.jpg'
  ),
  (
    'Maheu',
    28,
    150,
    'Sweet, refreshing non-alcoholic beverage made from fermented maize meal.',
    'Drinks',
    'assets/images/maheu.jpg'
  ),
  (
    'Chibuku Shake Shake',
    32,
    110,
    'Traditional opaque beer made from maize and sorghum.',
    'Drinks',
    'assets/images/chibuku.jpg'
  );

COMMIT;