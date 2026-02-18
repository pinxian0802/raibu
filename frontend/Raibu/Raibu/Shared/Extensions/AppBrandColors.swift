import SwiftUI

extension Color {
    // Centralized system palette.
    static let appPrimary = Color(uiColor: .systemPurple)
    static let appSecondary = Color(
        red: 174.0 / 255.0,
        green: 211.0 / 255.0,
        blue: 252.0 / 255.0
    )
    static let appDanger = Color(uiColor: .systemRed)
    static let appSuccess = Color(uiColor: .systemGreen)
    static let appWarning = Color(uiColor: .systemOrange)
    static let appDisabled = Color(uiColor: .systemGray3)
    static let appOverlay = Color(uiColor: .black)
    static let appOnPrimary = Color(uiColor: .white)
    static let appSurface = Color(uiColor: .systemBackground)
    static let appSurfaceSecondary = Color(uiColor: .secondarySystemBackground)

    // Backward compatible aliases used across the app.
    static let brandBlue = appSecondary
    static let brandPurple = appPrimary
    static let brandPurpleLight = Color(uiColor: .systemIndigo)
    static let brandPurpleDark = Color(uiColor: .systemPurple)
    static let brandOrange = appPrimary
}

#if canImport(UIKit)
import UIKit

extension UIColor {
    static let appPrimary = UIColor.systemPurple
    static let appSecondary = UIColor(
        red: 174.0 / 255.0,
        green: 211.0 / 255.0,
        blue: 252.0 / 255.0,
        alpha: 1.0
    )
    static let appDanger = UIColor.systemRed
    static let appSuccess = UIColor.systemGreen
    static let appWarning = UIColor.systemOrange
    static let appDisabled = UIColor.systemGray3
    static let appOverlay = UIColor.black
    static let appOnPrimary = UIColor.white
    static let appSurface = UIColor.systemBackground
    static let appSurfaceSecondary = UIColor.secondarySystemBackground

    static let brandBlue = appSecondary
    static let brandPurple = appPrimary
    static let brandPurpleLight = UIColor.systemIndigo
    static let brandPurpleDark = appPrimary
    static let brandOrange = appPrimary
}
#endif
