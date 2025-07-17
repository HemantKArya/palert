// src/scraper_engine.rs
use std::time::Duration;
use flutter_rust_bridge::frb;
use crate::api::browser_service_manager::{BrowserServiceManager, ServiceStatus};

/// The main engine to control a persistent browser session with fallback mechanisms.
#[derive(Debug)]
#[frb(opaque)]
pub struct BrowserEngine {
    driver: Option<thirtyfour::WebDriver>,
    service_manager: BrowserServiceManager,
}

#[derive(Debug, Clone)]
pub struct BrowserEngineStatus {
    pub is_running: bool,
    pub current_port: u16,
    pub message: String,
    pub requires_restart: bool,
}

impl BrowserEngine {
    /// Creates a new BrowserEngine with service management and fallback
    pub async fn new(port: u16, browser_path: &str, driver_path: &str) -> anyhow::Result<Self> {
        let mut service_manager = BrowserServiceManager::new(port, driver_path, browser_path);
        
        // Start the service
        let status = service_manager.start_service().await?;
        if !status.is_healthy {
            anyhow::bail!("Failed to start browser service: {}", status.error_message.unwrap_or_else(|| "Unknown error".to_string()));
        }

        // Create WebDriver
        let driver = service_manager.create_webdriver_internal().await?;

        Ok(Self {
            driver: Some(driver),
            service_manager,
        })
    }

    /// Creates a new BrowserEngine with automatic port management
    pub async fn new_with_fallback(
        initial_port: u16, 
        browser_path: &str, 
        driver_path: &str
    ) -> anyhow::Result<(Self, ServiceStatus)> {
        let mut service_manager = BrowserServiceManager::new(initial_port, driver_path, browser_path);
        
        // Try to start service with fallback
        let status = match service_manager.start_service().await {
            Ok(s) if s.is_healthy => s,
            Ok(_) | Err(_) => {
                // Service failed, try to restart with new port
                service_manager.restart_service().await?
            }
        };

        if !status.is_healthy {
            anyhow::bail!("Failed to start browser service after fallback: {}", status.error_message.unwrap_or_else(|| "Unknown error".to_string()));
        }

        // Create WebDriver
        let driver = service_manager.create_webdriver_internal().await?;

        Ok((Self {
            driver: Some(driver),
            service_manager,
        }, status))
    }

    /// Checks the health of the browser service
    pub async fn check_service_status(&self) -> BrowserEngineStatus {
        let service_status = self.service_manager.check_service_health().await;
        
        BrowserEngineStatus {
            is_running: service_status.is_healthy && self.driver.is_some(),
            current_port: service_status.port,
            message: service_status.error_message.unwrap_or_else(|| "Service is healthy".to_string()),
            requires_restart: !service_status.is_healthy,
        }
    }

    /// Restarts the browser service with fallback mechanisms
    pub async fn restart_with_fallback(&mut self) -> anyhow::Result<ServiceStatus> {
        // Close existing driver by taking ownership
        self.driver = None; // This will drop the WebDriver

        // Restart service
        let status = self.service_manager.restart_service().await?;
        
        if status.is_healthy {
            // Create new WebDriver
            match self.service_manager.create_webdriver_internal().await {
                Ok(driver) => {
                    self.driver = Some(driver);
                    Ok(status)
                }
                Err(e) => {
                    anyhow::bail!("Service restarted but failed to create WebDriver: {}", e)
                }
            }
        } else {
            anyhow::bail!("Failed to restart service: {}", status.error_message.unwrap_or_else(|| "Unknown error".to_string()))
        }
    }

    /// Navigates to a URL and returns the page source with automatic retry
    pub async fn get_page_source(&mut self, url: &str) -> anyhow::Result<String> {
        // First, try with existing driver
        if let Some(driver) = self.driver.as_ref() {
            match self.try_get_page_source(driver, url).await {
                Ok(html) => return Ok(html),
                Err(e) => {
                    println!("Failed to get page source, attempting restart: {}", e);
                }
            }
        }

        // If that fails, restart and retry
        let restart_status = self.restart_with_fallback().await?;
        println!("Browser restarted: {}", restart_status.error_message.unwrap_or_else(|| "Service restarted successfully".to_string()));

        if let Some(driver) = self.driver.as_ref() {
            self.try_get_page_source(driver, url).await
        } else {
            anyhow::bail!("Browser is not available after restart")
        }
    }

    /// Internal method to try getting page source
    async fn try_get_page_source(&self, driver: &thirtyfour::WebDriver, url: &str) -> anyhow::Result<String> {
        driver.goto(url).await?;
        tokio::time::sleep(Duration::from_secs(2)).await;
        let html = driver.source().await?;
        Ok(html)
    }

    /// Gets the current port being used
    pub fn get_current_port(&self) -> u16 {
        self.service_manager.get_current_port()
    }

    /// Closes the currently active tab/window.
    pub async fn close_current_tab(&self) -> anyhow::Result<()> {
        if let Some(driver) = self.driver.as_ref() {
            driver.close_window().await?;
            Ok(())
        } else {
            anyhow::bail!("Browser has been shut down and is no longer available.")
        }
    }

    /// Explicitly shuts down the browser session.
    pub async fn shutdown(mut self) -> anyhow::Result<()> {
        println!("Shutting down browser session...");
        if let Some(driver) = self.driver.take() {
            let _ = driver.quit().await; // Ignore errors on quit
            println!("Browser session closed.");
        }
        // Service manager will be dropped and stop the chromedriver process
        Ok(())
    }
}

impl Drop for BrowserEngine {
    fn drop(&mut self) {
        if self.driver.is_some() {
            eprintln!("Warning: BrowserEngine was dropped without calling shutdown(). The browser window may have been left open.");
        }
    }
}