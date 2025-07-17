// src/database.rs
use crate::api::models::{PriceEntry, ProductDetails, ProductRecord};
use chrono::{DateTime, Utc};
use rusqlite::{Connection, Result};
use std::sync::Mutex;
use serde::{Deserialize, Serialize};
use std::fs::File;

#[derive(Debug, Serialize, Deserialize)]
pub struct DatabaseBackup {
    pub products: Vec<ProductRecord>,
    pub backup_timestamp: String,
    pub version: String,
}

pub struct Database {
    conn: Mutex<Connection>,
}

impl Database {
    /// Opens a connection to the SQLite database and sets up the tables.
    pub fn new(db_path: &str) -> Result<Self> {
        let conn = Connection::open(db_path)?;
        let db = Database {
            conn: Mutex::new(conn),
        };
        db.setup_database()?;
        Ok(db)
    }

    /// Creates the `products` and `prices` tables if they don't exist.
    fn setup_database(&self) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute_batch(
            "BEGIN;
            CREATE TABLE IF NOT EXISTS products (
                id TEXT PRIMARY KEY,
                site TEXT NOT NULL,
                url TEXT NOT NULL,
                title TEXT NOT NULL,
                seller TEXT,
                images TEXT,
                features TEXT,
                specifications TEXT
            );
            CREATE TABLE IF NOT EXISTS prices (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                product_id TEXT NOT NULL,
                price INTEGER NOT NULL,
                in_stock BOOLEAN NOT NULL,
                timestamp TEXT NOT NULL,
                FOREIGN KEY (product_id) REFERENCES products (id)
            );
            COMMIT;",
        )?;
        Ok(())
    }

    /// Inserts or updates a product's static details.
    pub fn upsert_product(&self, details: &ProductDetails) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let images_json = serde_json::to_string(&details.images).unwrap_or_default();
        let specs_json = serde_json::to_string(&details.specifications).unwrap_or_default();
        let features_json = serde_json::to_string(&details.features).unwrap_or_default();

        conn.execute(
            "INSERT INTO products (id, site, url, title, seller, images, features, specifications)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
             ON CONFLICT(id) DO UPDATE SET
                site=excluded.site,
                url=excluded.url,
                title=excluded.title,
                seller=excluded.seller,
                images=excluded.images,
                features=excluded.features,
                specifications=excluded.specifications;",
            rusqlite::params![
                details.id,
                details.site,
                details.url,
                details.title,
                details.seller,
                images_json,
                features_json,
                specs_json,
            ],
        )?;
        Ok(())
    }

    pub fn insert_price_entry(&self, details: &ProductDetails) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        if let Some(price) = details.price {
            let now: DateTime<Utc> = Utc::now();
            conn.execute(
                "INSERT INTO prices (product_id, price, in_stock, timestamp) VALUES (?1, ?2, ?3, ?4)",
                rusqlite::params![
                    details.id,
                    price,
                    details.in_stock,
                    now.to_rfc3339(),
                ],
            )?;
        }
        Ok(())
    }

    pub fn get_all_products_with_history(&self) -> Result<Vec<ProductRecord>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt_products = conn.prepare("SELECT id, site, url, title, seller, images, features, specifications FROM products")?;
        let mut rows_products = stmt_products.query([])?;
        let mut products = Vec::new();

        while let Some(row) = rows_products.next()? {
            let product_id: String = row.get(0)?;
            let images_json: String = row.get(5).unwrap_or_default();
            let features_json: String = row.get(6).unwrap_or_default();
            let specs_json: String = row.get(7).unwrap_or_default();

            let images: Vec<String> = serde_json::from_str(&images_json).unwrap_or_default();
            let features: Vec<String> = serde_json::from_str(&features_json).unwrap_or_default();
            let specifications: String = specs_json;

            let mut stmt_prices =
                conn.prepare("SELECT price, in_stock, timestamp FROM prices WHERE product_id = ?1 ORDER BY timestamp ASC")?;
            let mut rows_prices = stmt_prices.query([&product_id])?;
            let mut price_history = Vec::new();

            while let Some(price_row) = rows_prices.next()? {
                price_history.push(PriceEntry {
                    price: price_row.get(0)?,
                    in_stock: price_row.get(1)?,
                    timestamp: price_row.get(2)?,
                });
            }

            products.push(ProductRecord {
                id: product_id,
                site: row.get(1)?,
                url: row.get(2)?,
                title: row.get(3)?,
                seller: row.get(4)?,
                images,
                features,
                specifications,
                price_history,
            });
        }

        Ok(products)
    }

    pub fn get_product_with_history(&self, product_id: &str) -> Result<Option<ProductRecord>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt_product = conn.prepare(
            "SELECT id, site, url, title, seller, images, features, specifications FROM products WHERE id = ?1",
        )?;
        let mut rows_product = stmt_product.query([product_id])?;

        if let Some(row) = rows_product.next()? {
            let images_json: String = row.get(5).unwrap_or_default();
            let features_json: String = row.get(6).unwrap_or_default();
            let specs_json: String = row.get(7).unwrap_or_default();

            let images: Vec<String> = serde_json::from_str(&images_json).unwrap_or_default();
            let features: Vec<String> = serde_json::from_str(&features_json).unwrap_or_default();
            let specifications: String = specs_json;

            let mut stmt_prices =
                conn.prepare("SELECT price, in_stock, timestamp FROM prices WHERE product_id = ?1 ORDER BY timestamp ASC")?;
            let mut rows_prices = stmt_prices.query([product_id])?;
            let mut price_history = Vec::new();

            while let Some(price_row) = rows_prices.next()? {
                price_history.push(PriceEntry {
                    price: price_row.get(0)?,
                    in_stock: price_row.get(1)?,
                    timestamp: price_row.get(2)?,
                });
            }

            Ok(Some(ProductRecord {
                id: row.get(0)?,
                site: row.get(1)?,
                url: row.get(2)?,
                title: row.get(3)?,
                seller: row.get(4)?,
                images,
                features,
                specifications,
                price_history,
            }))
        } else {
            Ok(None)
        }
    }

    pub fn remove_product(&self, product_id: &str) -> Result<()> {
        println!("Database::remove_product called with ID: {}", product_id);
        let conn = self.conn.lock().unwrap();
        
        // First, let's check if the product exists
        let mut stmt = conn.prepare("SELECT COUNT(*) FROM products WHERE id = ?1")?;
        let count: i64 = stmt.query_row([product_id], |row| row.get(0))?;
        println!("Found {} products with ID: {}", count, product_id);
        
        if count == 0 {
            println!("No product found with ID: {}", product_id);
            return Ok(());
        }
        
        // Delete from prices table first (due to foreign key constraint)
        let prices_deleted = conn.execute("DELETE FROM prices WHERE product_id = ?1", [product_id])?;
        println!("Deleted {} price entries for product ID: {}", prices_deleted, product_id);
        
        // Delete from products table
        let products_deleted = conn.execute("DELETE FROM products WHERE id = ?1", [product_id])?;
        println!("Deleted {} product entries for product ID: {}", products_deleted, product_id);
        
        if products_deleted > 0 {
            println!("Product with ID {} removed successfully", product_id);
        } else {
            println!("No product was deleted (this shouldn't happen)");
        }
        
        Ok(())
    }

    /// Creates a backup of all data in JSON format
    pub fn create_backup(&self, backup_path: &str) -> Result<()> {
        use std::io::Write;
        
        let products = self.get_all_products_with_history()?;
        
        let backup = DatabaseBackup {
            products,
            backup_timestamp: Utc::now().to_rfc3339(),
            version: "1.0.0".to_string(),
        };
        
        let json_data = serde_json::to_string_pretty(&backup)
            .map_err(|e| rusqlite::Error::InvalidColumnType(0, format!("JSON serialization error: {}", e), rusqlite::types::Type::Text))?;
        
        let mut file = File::create(backup_path)
            .map_err(|e| rusqlite::Error::InvalidColumnType(0, format!("File creation error: {}", e), rusqlite::types::Type::Text))?;
        
        file.write_all(json_data.as_bytes())
            .map_err(|e| rusqlite::Error::InvalidColumnType(0, format!("File write error: {}", e), rusqlite::types::Type::Text))?;
        
        println!("Backup created successfully at: {}", backup_path);
        Ok(())
    }
    
    /// Restores data from a JSON backup file
    pub fn restore_from_backup(&self, backup_path: &str, replace_existing: bool) -> Result<()> {
        use std::io::Read;
        
        let mut file = File::open(backup_path)
            .map_err(|e| rusqlite::Error::InvalidColumnType(0, format!("File open error: {}", e), rusqlite::types::Type::Text))?;
        
        let mut json_data = String::new();
        file.read_to_string(&mut json_data)
            .map_err(|e| rusqlite::Error::InvalidColumnType(0, format!("File read error: {}", e), rusqlite::types::Type::Text))?;
        
        let backup: DatabaseBackup = serde_json::from_str(&json_data)
            .map_err(|e| rusqlite::Error::InvalidColumnType(0, format!("JSON deserialization error: {}", e), rusqlite::types::Type::Text))?;
        
        println!("Restoring backup from: {} (created: {})", backup_path, backup.backup_timestamp);
        
        let conn = self.conn.lock().unwrap();
        
        // If replace_existing is true, clear existing data
        if replace_existing {
            conn.execute("DELETE FROM prices", [])?;
            conn.execute("DELETE FROM products", [])?;
            println!("Cleared existing data");
        }
        
        // Begin transaction for batch insert
        let tx = conn.unchecked_transaction()?;
        
        let product_count = backup.products.len();
        for product in backup.products {
            // Insert product
            tx.execute(
                "INSERT OR REPLACE INTO products (id, site, url, title, seller, images, features, specifications) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
                (
                    &product.id,
                    &product.site,
                    &product.url,
                    &product.title,
                    &product.seller,
                    &serde_json::to_string(&product.images).unwrap_or_default(),
                    &serde_json::to_string(&product.features).unwrap_or_default(),
                    &product.specifications,
                ),
            )?;
            
            // Insert price history
            for price_entry in product.price_history {
                tx.execute(
                    "INSERT OR REPLACE INTO prices (product_id, price, in_stock, timestamp) VALUES (?1, ?2, ?3, ?4)",
                    (
                        &product.id,
                        price_entry.price,
                        price_entry.in_stock,
                        &price_entry.timestamp,
                    ),
                )?;
            }
        }
        
        tx.commit()?;
        println!("Backup restored successfully. Imported {} products", product_count);
        Ok(())
    }
}