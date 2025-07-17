// src/price_engine.rs
use crate::api::{
    amazon_parser, database::Database, flipkart_parser, models::ProductRecord, 
    scraper_engine::BrowserEngine, 
    browser_service_manager::ServiceStatus,
};
use chrono;

#[derive(Debug, Clone)]
pub struct PriceEngineStatus {
    pub is_healthy: bool,
    pub current_port: u16,
    pub message: String,
    pub last_check: String,
}

pub struct PriceEngine {
    browser_engine: BrowserEngine,
    database: Database,
    initial_port: u16,
    browser_path: String,
    driver_path: String,
}

impl PriceEngine {
    pub async fn new(port: u16, browser_path: &str, db_path: &str, driver_path: &str) -> anyhow::Result<Self> {
        println!("Initializing browser engine with fallback...");
        let (browser_engine, service_status) = BrowserEngine::new_with_fallback(port, browser_path, driver_path).await?;
        
        if service_status.port != port {
            println!("Browser service started on different port: {} (requested: {})", service_status.port, port);
        }

        println!("Connecting to database at '{}'...", db_path);
        let database = Database::new(db_path)?;
        
        Ok(Self {
            browser_engine,
            database,
            initial_port: port,
            browser_path: browser_path.to_string(),
            driver_path: driver_path.to_string(),
        })
    }

    /// Checks the health status of the browser service
    pub async fn check_service_status(&self) -> PriceEngineStatus {
        let browser_status = self.browser_engine.check_service_status().await;
        
        PriceEngineStatus {
            is_healthy: browser_status.is_running,
            current_port: browser_status.current_port,
            message: browser_status.message,
            last_check: chrono::Utc::now().format("%Y-%m-%d %H:%M:%S UTC").to_string(),
        }
    }

    /// Gets the current port being used by the browser service
    pub fn get_current_port(&self) -> u16 {
        self.browser_engine.get_current_port()
    }

    /// Restarts the browser service if needed
    pub async fn restart_browser_service(&mut self) -> anyhow::Result<ServiceStatus> {
        println!("Restarting browser service...");
        self.browser_engine.restart_with_fallback().await
    }
    
    /// Fetches product details with automatic retry and fallback mechanisms
    pub async fn fetch_and_update_product(&mut self, url: &str) -> anyhow::Result<ProductRecord> {
        // This will automatically handle service failures and restarts
        let html_source = self.browser_engine.get_page_source(url).await?;

        let mut details = if url.contains("amazon.in") {
            amazon_parser::extract_details(&html_source, url)?
        } else if url.contains("flipkart.com") {
            flipkart_parser::extract_details(&html_source, url)?
        } else {
            anyhow::bail!("Unsupported URL: {}", url)
        };
        details.url = url.to_string();

        println!("Updating database for product ID: {}", details.id);
        
        // Always update the product basic information (title, seller, images, etc.)
        self.database.upsert_product(&details)?;
        
        // Only update price entry if the item is in stock
        if details.in_stock {
            if let Some(price) = details.price {
                println!("Item is in stock with price: {}, updating price entry", price);
                self.database.insert_price_entry(&details)?;
            } else {
                println!("Item is marked as in stock but no price found, skipping price update");
            }
        } else {
            println!("Item is out of stock, skipping price update to avoid unreliable pricing data");
        }
        
        // After updating, fetch the full record with history to return it
        let product_record = self.database.get_product_with_history(&details.id)?
            .ok_or_else(|| anyhow::anyhow!("Failed to retrieve product record after update"))?;

        Ok(product_record)
    }

    /// Removes a product from the database by its ID.
    pub fn remove_product_by_id(&self, product_id: &str) -> anyhow::Result<()> {
        println!("remove_product_by_id called with ID: {}", product_id);
        match self.database.remove_product(product_id) {
            Ok(()) => {
                println!("Successfully removed product with ID: {}", product_id);
                Ok(())
            }
            Err(e) => {
                println!("Failed to remove product with ID: {}, error: {}", product_id, e);
                Err(anyhow::anyhow!("Database error: {}", e))
            }
        }
    }
    
    pub fn get_all_products_in_db(&self) -> anyhow::Result<Vec<ProductRecord>> {
        self.database.get_all_products_with_history().map_err(|e| anyhow::anyhow!(e))
    }
    
    /// Creates a backup of the database in JSON format
    pub fn create_backup(&self, backup_path: &str) -> anyhow::Result<()> {
        self.database.create_backup(backup_path).map_err(|e| anyhow::anyhow!(e))
    }
    
    /// Restores database from a JSON backup file
    pub fn restore_from_backup(&self, backup_path: &str, replace_existing: bool) -> anyhow::Result<()> {
        self.database.restore_from_backup(backup_path, replace_existing).map_err(|e| anyhow::anyhow!(e))
    }
    
    /// Shuts down the browser engine gracefully.
    pub async fn shutdown(self) -> anyhow::Result<()> {
        self.browser_engine.shutdown().await
    }
}