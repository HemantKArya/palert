// src/models.rs
use serde::{Deserialize, Serialize};

// This struct remains unchanged
#[derive(Debug, Serialize, Deserialize)]
pub struct ProductDetails {
    pub id: String,
    pub site: String,
    pub url: String,
    pub title: String,
    pub price: Option<i32>,
    pub rating: String,
    pub features: Vec<String>,
    pub specifications: serde_json::Value,
    pub in_stock: bool,
    pub seller: Option<String>,
    pub images: Vec<String>,
}

// This struct has been updated to derive Clone
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PriceEntry {
    pub price: i32,
    pub in_stock: bool,
    pub timestamp: String,
}

// --- UPDATE THIS STRUCT ---
// Represents a complete product record with its price history.
#[derive(Debug, Serialize, Deserialize)]
pub struct ProductRecord {
    pub id: String,
    pub site: String,
    pub url: String,
    pub title: String,
    pub seller: Option<String>,
    pub images: Vec<String>,
    pub specifications: String, // Changed to String
    // Add the features field here
    pub features: Vec<String>,
    pub price_history: Vec<PriceEntry>,
}