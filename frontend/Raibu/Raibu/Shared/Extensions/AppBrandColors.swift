import SwiftUI

extension Color {
    static let brandBlue = Color(
        red: 210.0 / 255.0,
        green: 233.0 / 255.0,
        blue: 255.0 / 255.0
    )
    
    static let brandOrange = Color(
        red: 255.0 / 255.0,
        green: 250.0 / 255.0,
        blue: 244.0 / 255.0
    )
}

#if canImport(UIKit)
import UIKit

extension UIColor {
    static let brandBlue = UIColor(
        red: 210.0 / 255.0,
        green: 233.0 / 255.0,
        blue: 255.0 / 255.0,
        alpha: 1.0
    )
    
    static let brandOrange = UIColor(
        red: 255.0 / 255.0,
        green: 250.0 / 255.0,
        blue: 244.0 / 255.0,
        alpha: 1.0
    )
}
#endif
