// src/browser_service_manager.rs
use std::net::TcpListener;
use std::process::{Child, Command, Stdio};
use std::time::Duration;
use thirtyfour::prelude::*;
use flutter_rust_bridge::frb;

/// Result of a browser service check
#[frb]
#[derive(Debug, Clone)]
pub struct ServiceStatus {
    pub is_healthy: bool,
    pub port: u16,
    pub error_message: Option<String>,
}

/// A robust browser service manager with fallback mechanisms
#[frb(opaque)]
#[derive(Debug)]
pub struct BrowserServiceManager {
    current_port: u16,
    min_port: u16,
    max_port: u16,
    driver_path: String,
    browser_path: String,
    chrome_process: Option<Child>,
}

impl BrowserServiceManager {
    /// Creates a new service manager
    pub fn new(
        initial_port: u16,
        driver_path: &str,
        browser_path: &str,
    ) -> Self {
        Self {
            current_port: initial_port,
            min_port: initial_port,
            max_port: initial_port + 100, // Allow 100 port range
            driver_path: driver_path.to_string(),
            browser_path: browser_path.to_string(),
            chrome_process: None,
        }
    }

    /// Checks if a port is available
    pub fn is_port_available(port: u16) -> bool {
        TcpListener::bind(format!("127.0.0.1:{}", port)).is_ok()
    }

    /// Finds the next available port starting from the current port
    pub fn find_available_port(&mut self) -> anyhow::Result<u16> {
        for port in self.min_port..=self.max_port {
            if Self::is_port_available(port) {
                self.current_port = port;
                return Ok(port);
            }
        }
        anyhow::bail!("No available ports found in range {}-{}", self.min_port, self.max_port)
    }

    /// Checks if the browser service is responsive at the current port
    pub async fn check_service_health(&self) -> ServiceStatus {
        let url = format!("http://localhost:{}/status", self.current_port);
        
        match reqwest::get(&url).await {
            Ok(response) => {
                if response.status().is_success() {
                    ServiceStatus {
                        is_healthy: true,
                        port: self.current_port,
                        error_message: None,
                    }
                } else {
                    ServiceStatus {
                        is_healthy: false,
                        port: self.current_port,
                        error_message: Some(format!("Service unhealthy on port {}: HTTP {}", self.current_port, response.status())),
                    }
                }
            }
            Err(e) => ServiceStatus {
                is_healthy: false,
                port: self.current_port,
                error_message: Some(format!("Service not responding on port {}: {}", self.current_port, e)),
            },
        }
    }

    /// Starts the chromedriver service on the current port
    pub async fn start_service(&mut self) -> anyhow::Result<ServiceStatus> {
        // First, check if port is available
        if !Self::is_port_available(self.current_port) {
            // Find available port
            let new_port = self.find_available_port()?;
            return Ok(ServiceStatus {
                is_healthy: false,
                port: new_port,
                error_message: Some(format!("Port {} was busy, found available port {}", self.current_port, new_port)),
            });
        }

        // Kill existing process if any
        self.stop_service();

        println!("Starting chromedriver on port {}...", self.current_port);

        let mut cmd = Command::new(&self.driver_path);
        cmd.arg(format!("--port={}", self.current_port));
        cmd.arg("--whitelisted-ips=");

        #[cfg(windows)] {
            use std::os::windows::process::CommandExt;
            const CREATE_NO_WINDOW: u32 = 0x08000000;
            cmd.creation_flags(CREATE_NO_WINDOW);
        }

        let process = cmd
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| {
                anyhow::anyhow!("Failed to start chromedriver. Is it in your PATH? Error: {}", e)
            })?;

        self.chrome_process = Some(process);

        // Wait for service to start
        tokio::time::sleep(Duration::from_secs(3)).await;

        // Verify service is running
        let status = self.check_service_health().await;
        if status.is_healthy {
            Ok(ServiceStatus {
                is_healthy: true,
                port: self.current_port,
                error_message: None,
            })
        } else {
            Ok(ServiceStatus {
                is_healthy: false,
                port: self.current_port,
                error_message: Some(format!("Service started but not responding on port {}", self.current_port)),
            })
        }
    }

    /// Stops the chromedriver service
    pub fn stop_service(&mut self) {
        if let Some(mut process) = self.chrome_process.take() {
            println!("Stopping chromedriver process...");
            if let Err(e) = process.kill() {
                eprintln!("Failed to kill chromedriver process: {}", e);
            }
        }
    }

    /// Restarts the service with fallback to new port if needed
    pub async fn restart_service(&mut self) -> anyhow::Result<ServiceStatus> {
        self.stop_service();
        
        // Try current port first
        if Self::is_port_available(self.current_port) {
            return self.start_service().await;
        }

        // Find new available port
        let new_port = self.find_available_port()?;
        self.current_port = new_port;
        self.start_service().await
    }

    /// Gets the current port
    pub fn get_current_port(&self) -> u16 {
        self.current_port
    }

    /// Sets a new port range
    pub fn set_port_range(&mut self, min_port: u16, max_port: u16) {
        self.min_port = min_port;
        self.max_port = max_port;
        if self.current_port < min_port || self.current_port > max_port {
            self.current_port = min_port;
        }
    }

    /// Creates a WebDriver instance internally (not exposed to FFI)
    pub(crate) async fn create_webdriver_internal(&self) -> anyhow::Result<thirtyfour::WebDriver> {
        let mut caps = DesiredCapabilities::chrome();
        let _ = caps.set_headless();
        caps.set_binary(&self.browser_path)?;

        let driver_url = format!("http://localhost:{}", self.current_port);
        let driver = thirtyfour::WebDriver::new(&driver_url, caps).await?;
        Ok(driver)
    }
}

impl Drop for BrowserServiceManager {
    fn drop(&mut self) {
        self.stop_service();
    }
}
