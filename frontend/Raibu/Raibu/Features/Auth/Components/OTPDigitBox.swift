//
//  OTPDigitBox.swift
//  Raibu
//
//  Shared component for OTP digit input
//

import SwiftUI

/// OTP 單一數字輸入框元件
struct OTPDigitBox: View {
    @Binding var digit: String
    let isFocused: Bool
    let onDigitEntered: () -> Void
    let onBackspace: () -> Void
    
    var body: some View {
        TextField("", text: $digit)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 24, weight: .bold, design: .rounded))
            .frame(width: 48, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.brandBlue : Color.clear, lineWidth: 2)
            )
            .onChange(of: digit) { oldValue, newValue in
                // 只保留數字
                let filtered = newValue.filter { $0.isNumber }
                
                if filtered.isEmpty && !oldValue.isEmpty {
                    // 刪除操作
                    digit = ""
                    onBackspace()
                } else if filtered.count >= 1 {
                    // 只保留最後輸入的數字
                    digit = String(filtered.suffix(1))
                    onDigitEntered()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    HStack {
        OTPDigitBox(
            digit: .constant("1"),
            isFocused: true,
            onDigitEntered: {},
            onBackspace: {}
        )
        OTPDigitBox(
            digit: .constant(""),
            isFocused: false,
            onDigitEntered: {},
            onBackspace: {}
        )
    }
    .padding()
}
