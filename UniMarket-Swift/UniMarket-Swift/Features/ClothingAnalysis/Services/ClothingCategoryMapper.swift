//
//  ClothingCategoryMapper.swift
//  UniMarket-Swift
//
//  Created by Felipe Mesa on 19/03/26.
//

import Foundation

/// Maps ImageNet/Core ML classification labels to simplified clothing categories
class ClothingCategoryMapper {
    
    /// Maps an ImageNet label to a simplified clothing category
    /// - Parameter identifier: The classification label from Core ML
    /// - Returns: User-friendly category name (e.g., "Shirt", "Pants", "Shoes")
    func mapToClothingCategory(_ identifier: String) -> String {
        let lowercased = identifier.lowercased()
        
        // Shirt / Top categories
        if lowercased.contains("shirt") || lowercased.contains("t-shirt") ||
           lowercased.contains("tee") || lowercased.contains("jersey") ||
           lowercased.contains("blouse") || lowercased.contains("top") ||
           lowercased.contains("tank") || lowercased.contains("sleeveless") {
            return "Shirt"
        }
        
        // Pants / Bottom categories
        if lowercased.contains("pants") || lowercased.contains("pant") ||
           lowercased.contains("jean") || lowercased.contains("denim") ||
           lowercased.contains("trousers") || lowercased.contains("shorts") ||
           lowercased.contains("short") || lowercased.contains("leggings") {
            return "Pants"
        }
        
        // Dress categories
        if lowercased.contains("dress") || lowercased.contains("gown") ||
           lowercased.contains("skirt") {
            return "Dress"
        }
        
        // Shoe categories
        if lowercased.contains("shoe") || lowercased.contains("sneaker") ||
           lowercased.contains("boot") || lowercased.contains("loafer") ||
           lowercased.contains("sandal") || lowercased.contains("pump") ||
           lowercased.contains("heel") || lowercased.contains("flip-flop") {
            return "Shoes"
        }
        
        // Outerwear categories
        if lowercased.contains("jacket") || lowercased.contains("coat") ||
           lowercased.contains("blazer") || lowercased.contains("cardigan") ||
           lowercased.contains("sweater") || lowercased.contains("hoodie") ||
           lowercased.contains("sweatshirt") || lowercased.contains("vest") {
            return "Jacket"
        }
        
        // Accessory categories
        if lowercased.contains("hat") || lowercased.contains("cap") ||
           lowercased.contains("scarf") || lowercased.contains("belt") ||
           lowercased.contains("bag") || lowercased.contains("backpack") {
            return "Accessory"
        }
        
        // Suit categories
        if lowercased.contains("suit") {
            return "Suit"
        }
        
        // Default fallback
        return "Clothing"
    }
    
    /// Infers a style attribute based on category and colors
    /// - Parameters:
    ///   - category: The clothing category (e.g., "Shirt")
    ///   - colors: Array of detected colors
    /// - Returns: Style descriptor (e.g., "Casual", "Formal")
    func inferStyle(from category: String, colors: [String]) -> String {
        // Formal indicators
        if category == "Suit" || category == "Jacket" {
            if colors.contains("Black") || colors.contains("Navy") || colors.contains("Gray") {
                return "Formal"
            }
        }
        
        // Check for bright/bold colors suggesting casual or streetwear
        let brightColors = ["Yellow", "Cyan", "Magenta", "Lime"]
        if colors.contains(where: { brightColors.contains($0) }) {
            return "Casual"
        }
        
        // Neutral colors suggest classic/formal
        let neutralColors = ["Black", "White", "Gray"]
        let allNeutral = colors.allSatisfy { neutralColors.contains($0) }
        if allNeutral && colors.count > 0 {
            return "Classic"
        }
        
        // Default to casual
        return "Casual"
    }
    
    /// Infers pattern type based on detected features
    /// - Parameter description: Classification description or label
    /// - Returns: Pattern type (e.g., "Solid", "Striped")
    func inferPattern(from description: String) -> String {
        let lowercased = description.lowercased()
        
        if lowercased.contains("stripe") || lowercased.contains("striped") {
            return "Striped"
        }
        
        if lowercased.contains("checkered") || lowercased.contains("check") {
            return "Checkered"
        }
        
        if lowercased.contains("floral") || lowercased.contains("flower") {
            return "Floral"
        }
        
        if lowercased.contains("dot") || lowercased.contains("polka") {
            return "Dotted"
        }
        
        if lowercased.contains("print") || lowercased.contains("pattern") {
            return "Patterned"
        }
        
        // Default to solid if no pattern detected
        return "Solid"
    }
}
