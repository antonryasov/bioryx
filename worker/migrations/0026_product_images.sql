-- BIORYX: изображения товаров в D1. Существующие ссылки на файлы assets остаются без изменений.
CREATE TABLE IF NOT EXISTS bx_media_assets (
 hash TEXT PRIMARY KEY CHECK(length(hash)=64),
 mime TEXT NOT NULL CHECK(mime IN ('image/webp','image/jpeg')),
 data_base64 TEXT NOT NULL CHECK(length(data_base64)<=600000),
 created_at TEXT NOT NULL DEFAULT(datetime('now'))
);
CREATE TABLE IF NOT EXISTS bx_product_images (
 product_id TEXT PRIMARY KEY REFERENCES products(id),
 catalog_hash TEXT REFERENCES bx_media_assets(hash),
 page_hash TEXT REFERENCES bx_media_assets(hash),
 updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
