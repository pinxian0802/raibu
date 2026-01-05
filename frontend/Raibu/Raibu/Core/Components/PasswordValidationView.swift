//
//  PasswordValidationView.swift
//  Raibu
//
//  Created on 2026/01/06.
//

import SwiftUI

struct PasswordValidationView: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    // 驗證狀態
    var isValid: Bool {
        hasMinimumLength && hasLetterAndNumber
    }
    
    private var hasMinimumLength: Bool {
        text.count >= 8
    }
    
    private var hasLetterAndNumber: Bool {
        let hasLetter = text.rangeOfCharacter(from: .letters) != nil
        let hasNumber = text.rangeOfCharacter(from: .decimalDigits) != nil
        return hasLetter && hasNumber
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 標題
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 輸入框
            SecureField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
            
            // 驗證條件清單
            if !text.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ValidationRow(isValid: hasMinimumLength, text: "至少 8 個字元")
                    ValidationRow(isValid: hasLetterAndNumber, text: "包含英文和數字")
                }
                .padding(.top, 4)
            }
        }
    }
}

// 單條驗證規則顯示
struct ValidationRow: View {
    let isValid: Bool
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .gray)
                .font(.caption)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isValid ? .green : .secondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PasswordValidationView(
            title: "密碼",
            placeholder: "請輸入密碼",
            text: .constant("")
        )
        
        PasswordValidationView(
            title: "密碼 (輸入中)",
            placeholder: "請輸入密碼",
            text: .constant("1234")
        )
        
        PasswordValidationView(
            title: "密碼 (完成)",
            placeholder: "請輸入密碼",
            text: .constant("Raibu2024")
        )
    }
    .padding()
}
