-- BIORYX: расширенная информация для страниц товаров. Действующие товары и остатки сохраняются.
CREATE TABLE IF NOT EXISTS bx_product_details (
 product_id TEXT PRIMARY KEY REFERENCES products(id),
 long_description TEXT NOT NULL DEFAULT '' CHECK(length(long_description)<=3000),
 composition TEXT NOT NULL DEFAULT '' CHECK(length(composition)<=3000),
 directions TEXT NOT NULL DEFAULT '' CHECK(length(directions)<=3000),
 nutrition TEXT NOT NULL DEFAULT '' CHECK(length(nutrition)<=3000),
 warnings TEXT NOT NULL DEFAULT '' CHECK(length(warnings)<=3000),
 size_text TEXT NOT NULL DEFAULT '' CHECK(length(size_text)<=200),
 updated_at TEXT NOT NULL DEFAULT(datetime('now'))
);
