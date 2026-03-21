//
//  ColorAnalyzer.swift
//  UniMarket-Swift
//
//  Created by Felipe Mesa on 19/03/26.
//

import UIKit
import CoreImage

/// Analyzes dominant colors in a clothing image using Core Image filters
class ColorAnalyzer {
    
    /// Extracts dominant colors from an image
    /// - Parameters:
    ///   - image: The UIImage to analyze
    ///   - count: Number of dominant colors to extract (default: 3)
    /// - Returns: Array of color name strings (e.g., ["Blue", "White", "Gray"])
    func extractDominantColors(from image: UIImage, count: Int = 3) -> [String] {
        guard let ciImage = CIImage(image: image) else {
            return ["Unknown"]
        }
        
        // Get the dominant color using CIAreaAverage filter
        guard let dominantColor = extractDominantColor(from: ciImage) else {
            return ["Unknown"]
        }
        
        // Convert RGB to color names
        var colors = [colorNameFromRGB(dominantColor)]
        
        // For simplicity, we extract one dominant color
        // In a more advanced implementation, you could sample multiple regions
        // For now, return the dominant color with common complementary colors
        if count > 1 {
            colors.append(contentsOf: getComplementaryColors(for: colors[0]))
        }
        
        return Array(colors.prefix(count))
    }
    
    /// Extracts the dominant color from a CIImage
    private func extractDominantColor(from ciImage: CIImage) -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        let extentVector = CIVector(
            x: ciImage.extent.origin.x,
            y: ciImage.extent.origin.y,
            z: ciImage.extent.size.width,
            w: ciImage.extent.size.height
        )
        
        guard let filter = CIFilter(
            name: "CIAreaAverage",
            parameters: [
                kCIInputImageKey: ciImage,
                kCIInputExtentKey: extentVector
            ]
        ) else {
            return nil
        }
        
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        // Render the output image to get pixel data
        let context = CIContext(options: nil)
        _ = CGColorSpaceCreateDeviceRGB()
        
        guard let cgImage = context.createCGImage(
            outputImage,
            from: outputImage.extent
        ) else {
            return nil
        }
        
        guard let pixelData = cgImage.dataProvider?.data else {
            return nil
        }
        
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let red = CGFloat(data[0]) / 255.0
        let green = CGFloat(data[1]) / 255.0
        let blue = CGFloat(data[2]) / 255.0
        
        return (red, green, blue)
    }
    
    /// Converts RGB values to a color name
    /// - Parameters:
    ///   - red: Red component (0.0 to 1.0)
    ///   - green: Green component (0.0 to 1.0)
    ///   - blue: Blue component (0.0 to 1.0)
    /// - Returns: Human-readable color name
    private func colorNameFromRGB(_ rgb: (red: CGFloat, green: CGFloat, blue: CGFloat)) -> String {
        let r = rgb.red
        let g = rgb.green
        let b = rgb.blue
        
        // Convert RGB to grayscale to detect neutral colors
        let grayscale = (r * 0.299) + (g * 0.587) + (b * 0.114)
        
        // Check for neutrals first
        if grayscale < 0.2 {
            return "Black"
        } else if grayscale > 0.8 {
            return "White"
        } else if abs(r - g) < 0.1 && abs(g - b) < 0.1 {
            // Neutral gray tones
            if grayscale < 0.5 {
                return "Gray"
            } else {
                return "Light Gray"
            }
        }
        
        // Find the dominant color channel
        let max = max(r, g, b)
        
        // Determine hue-based colors
        if r == max {
            if g > b {
                return "Yellow"
            } else if b > g {
                return "Magenta"
            } else {
                return "Red"
            }
        } else if g == max {
            if r > b {
                return "Yellow"
            } else if b > r {
                return "Cyan"
            } else {
                return "Green"
            }
        } else { // b == max
            if r > g {
                return "Magenta"
            } else if g > r {
                return "Cyan"
            } else {
                return "Blue"
            }
        }
    }
    
    /// Gets complementary or common color names for variety
    /// - Parameter colorName: The primary color name
    /// - Returns: Array of complementary color suggestions
    private func getComplementaryColors(for colorName: String) -> [String] {
        let commonCombinations: [String: [String]] = [
            "Black": ["White", "Gray"],
            "White": ["Black", "Gray"],
            "Gray": ["Black", "White"],
            "Light Gray": ["Black", "Dark Gray"],
            "Blue": ["White", "Gray"],
            "Red": ["White", "Black"],
            "Green": ["White", "Black"],
            "Yellow": ["Black", "White"],
            "Cyan": ["Black", "White"],
            "Magenta": ["White", "Black"]
        ]
        
        return commonCombinations[colorName] ?? ["Gray", "White"]
    }
}
