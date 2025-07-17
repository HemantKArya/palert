// src/amazon_parser.rs
use crate::api::models::ProductDetails;
use scraper::{Html, Selector};
use serde_json::json;
use std::collections::HashMap;
use regex::Regex; // Import the regex crate

// Helper function to extract text from an element based on a selector.
fn get_text(element: &scraper::ElementRef, selector_str: &str) -> String {
    let selector = Selector::parse(selector_str).unwrap();
    element
        .select(&selector)
        .next()
        .map(|el| el.text().collect::<String>().trim().to_string())
        .unwrap_or_else(|| "Not Found".to_string())
}

// The function now accepts the URL as an argument
pub fn extract_details(html_source: &str, url: &str) -> anyhow::Result<ProductDetails> {
    let document = Html::parse_document(html_source);

    // --- ID Extraction from URL ---
    let re = Regex::new(r"\/dp\/([A-Z0-9]{10})")?;
    let product_id = re.captures(url)
        .and_then(|caps| caps.get(1))
        .map_or("ID Not Found".to_string(), |m| m.as_str().to_string());

    // --- Selectors ---
    let title_selector = Selector::parse("span#productTitle").unwrap();
    // ... other selectors remain the same ...
    let price_selector = Selector::parse("span.a-price-whole").unwrap();
    let _rating_text_selector = Selector::parse("i.a-icon-star span.a-icon-alt").unwrap();
    let _rating_count_selector = Selector::parse("span#acrCustomerReviewText").unwrap();
    let features_selector = Selector::parse("#feature-bullets .a-list-item").unwrap();
    let specs_table_selector = Selector::parse("table#productDetails_techSpec_section_1 tr").unwrap();
    let in_stock_selector = Selector::parse("#availability span.a-color-success").unwrap();
    let seller_selector = Selector::parse("#sellerProfileTriggerId").unwrap();
    let image_thumbnails_selector = Selector::parse("li.item.imageThumbnail img").unwrap();

    // --- Data Extraction (largely the same) ---
    let title = document
        .select(&title_selector)
        .next()
        .map(|t| t.text().collect::<String>().trim().to_string())
        .unwrap_or_else(|| "Not Found".to_string());
    
    let price: Option<i32> = document.select(&price_selector).next().and_then(|p| {
        p.text()
            .collect::<String>()
            .replace(',', "")
            .split('.')
            .next()
            .unwrap_or("")
            .parse::<i32>()
            .ok()
    });

    let rating_text = get_text(&document.root_element(), "i.a-icon-star span.a-icon-alt");
    let rating_count = get_text(&document.root_element(), "span#acrCustomerReviewText");
    let rating = if rating_text != "Not Found" && rating_count != "Not Found" {
        format!("{} ({})", rating_text, rating_count)
    } else {
        "Not Found".to_string()
    };

    let features: Vec<String> = document
        .select(&features_selector)
        .map(|f| f.text().collect::<String>().trim().to_string())
        .filter(|s| !s.is_empty())
        .collect();

    let mut specifications = HashMap::new();
    for row in document.select(&specs_table_selector) {
        let key = get_text(&row, "th");
        let value = get_text(&row, "td");
        if key != "Not Found" {
            specifications.insert(key, value.replace('\u{200e}', ""));
        }
    }

    let in_stock = document
        .select(&in_stock_selector)
        .next()
        .map(|s| s.text().collect::<String>().trim().to_lowercase() == "in stock")
        .unwrap_or(false);

    let seller = document
        .select(&seller_selector)
        .next()
        .map(|s| s.text().collect::<String>().trim().to_string());
    
    let images: Vec<String> = document
        .select(&image_thumbnails_selector)
        .filter_map(|img| img.value().attr("src"))
        .map(|src| src.replace("._SS40_.", "._SL1500_."))
        .collect();

    Ok(ProductDetails {
        id: product_id, // Add the extracted ID
        site: "Amazon".to_string(),
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