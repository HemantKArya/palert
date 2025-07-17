// src/flipkart_parser.rs

use scraper::{Html, Selector};
use serde_json::json;
use std::collections::HashMap;
use regex::Regex;

use crate::api::models::ProductDetails; // Import the regex crate

// The function now accepts the URL as an argument
pub fn extract_details(html_source: &str, url: &str) -> anyhow::Result<ProductDetails> {
    let document = Html::parse_document(html_source);

    // --- ID Extraction from URL ---
    // Primary method: extract from the path like `/p/itmd43b65174ffcf`
    let re_path = Regex::new(r"\/p\/([a-zA-Z0-9]+)")?;
    let mut product_id = re_path.captures(url)
        .and_then(|caps| caps.get(1))
        .map(|m| m.as_str().to_string())
        .unwrap_or_else(|| "ID Not Found".to_string());

    // Fallback method: extract from the `pid` query parameter
    if product_id == "ID Not Found" {
        let re_pid = Regex::new(r"pid=([A-Z0-9]+)")?;
        product_id = re_pid.captures(url)
            .and_then(|caps| caps.get(1))
            .map(|m| m.as_str().to_string())
            .unwrap_or_else(|| "ID Not Found".to_string());
    }

    // --- Selectors ---
    let title_selector = Selector::parse("span.VU-ZEz").unwrap();
    // ... other selectors remain the same ...
    let price_selector = Selector::parse("div.Nx9bqj").unwrap();
    let rating_value_selector = Selector::parse("div.XQDdHH").unwrap();
    let rating_count_selector = Selector::parse("span.Wphh3N").unwrap();
    let highlights_selector = Selector::parse("li._7eSDEz").unwrap();
    let specs_table_selector = Selector::parse("div.GNDEQ-").unwrap();
    let out_of_stock_selector = Selector::parse("div.nyRpc8").unwrap();
    let seller_selector = Selector::parse("#sellerName span span").unwrap();
    let image_thumbnail_selector = Selector::parse("li.YGoYIP img").unwrap();

    // --- Data Extraction (largely the same) ---
    let title = document
        .select(&title_selector)
        .next()
        .map(|t| t.text().collect::<String>().trim().to_string())
        .unwrap_or_else(|| "Not Found".to_string());

    let price: Option<i32> = document
        .select(&price_selector)
        .next()
        .and_then(|p| p.text().collect::<String>().replace(['₹', ','], "").trim().parse::<i32>().ok());

    let rating_value = document.select(&rating_value_selector).next().map(|r| r.text().collect::<String>());
    let rating_count = document.select(&rating_count_selector).next().map(|r| r.text().collect::<String>());
    let rating = match (rating_value, rating_count) {
        (Some(val), Some(count)) => format!("{} ★ ({})", val, count),
        (Some(val), None) => format!("{} ★", val),
        _ => "Not Found".to_string(),
    };

    let features: Vec<String> = document
        .select(&highlights_selector)
        .map(|li| li.text().collect::<String>())
        .collect();

    let mut specifications = HashMap::new();
    let category_title_selector = Selector::parse("div._4BJ2V\\+").unwrap();
    let row_selector = Selector::parse("tr.WJdYP6").unwrap();
    let key_selector = Selector::parse("td.\\+fFi1w").unwrap();
    let val_selector = Selector::parse("td.Izz52n li").unwrap();

    for table in document.select(&specs_table_selector) {
        if let Some(category_title_el) = table.select(&category_title_selector).next() {
            let category_title = category_title_el.text().collect::<String>();
            let mut category_specs = HashMap::new();
            for row in table.select(&row_selector) {
                if let (Some(key_el), Some(value_el)) = (row.select(&key_selector).next(), row.select(&val_selector).next()){
                    let key = key_el.text().collect::<String>();
                    let value = value_el.text().collect::<String>();
                    category_specs.insert(key, value);
                }
            }
            specifications.insert(category_title, category_specs);
        }
    }
    
    let in_stock = document.select(&out_of_stock_selector).next().is_none();
    
    let seller = document.select(&seller_selector).next().map(|s| s.text().collect());
    
    let images: Vec<String> = document
        .select(&image_thumbnail_selector)
        .filter_map(|img| img.value().attr("src"))
        .map(|src| src.replace("/128/128/", "/832/832/"))
        .collect();

    Ok(ProductDetails {
        id: product_id, // Add the extracted ID
        site: "Flipkart".to_string(),
        url: "".to_string(),
        title,
        price,
        rating,
        features,
        specifications: json!(specifications),
        in_stock,
        seller,
        images,
    })
}