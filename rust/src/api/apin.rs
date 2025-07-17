
use crate::api::{models::ProductRecord, price_engine::{PriceEngine, PriceEngineStatus}};

pub async fn get_price_engine(port: u16, browser_path: &str, db_path: &str, driver_path:&str) -> anyhow::Result<PriceEngine> {
    PriceEngine::new(port, browser_path, db_path, driver_path).await
}

pub async fn shutdown_price_engine(engine: PriceEngine) -> anyhow::Result<()> {
    engine.shutdown().await
}

pub async fn fetch_and_update_product(
    engine: &mut PriceEngine,
    url: &str,
) -> anyhow::Result<ProductRecord> {
    engine.fetch_and_update_product(url).await
}

pub async fn get_all_products_in_db(
    engine: &PriceEngine,
) -> anyhow::Result<Vec<ProductRecord>> {
    engine.get_all_products_in_db()
}

pub async fn remove_product_by_id(
    engine: &PriceEngine,
    product_id: &str,
) -> anyhow::Result<()> {
    engine.remove_product_by_id(product_id) 
        .map_err(|e| anyhow::anyhow!("Failed to remove product by ID: {}", e))
}

pub async fn create_backup(
    engine: &PriceEngine,
    backup_path: &str,
) -> anyhow::Result<()> {
    engine.create_backup(backup_path)
        .map_err(|e| anyhow::anyhow!("Failed to create backup: {}", e))
}

pub async fn restore_from_backup(
    engine: &PriceEngine,
    backup_path: &str,
    replace_existing: bool,
) -> anyhow::Result<()> {
    engine.restore_from_backup(backup_path, replace_existing)
        .map_err(|e| anyhow::anyhow!("Failed to restore from backup: {}", e))
}

// New functions for service management
pub async fn check_service_status(engine: &PriceEngine) -> anyhow::Result<PriceEngineStatus> {
    Ok(engine.check_service_status().await)
}

pub async fn get_current_port(engine: &PriceEngine) -> anyhow::Result<u16> {
    Ok(engine.get_current_port())
}

pub async fn restart_browser_service(engine: &mut PriceEngine) -> anyhow::Result<String> {
    let status = engine.restart_browser_service().await?;
    Ok(format!("Service restarted: {} on port {}", status.error_message.unwrap_or_else(|| "Successfully restarted".to_string()), status.port))
}
