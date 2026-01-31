//
//  ReportSheetView.swift
//  raibu
//
//  Created on 2026/01/27.
//

import SwiftUI

/// 檢舉彈窗視圖
struct ReportSheetView: View {
    @StateObject private var viewModel: ReportViewModel
    @Environment(\.dismiss) private var dismiss
    
    let onReported: (() -> Void)?
    
    init(target: ReportTargetType, apiClient: APIClient, onReported: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: ReportViewModel(target: target, apiClient: apiClient))
        self.onReported = onReported
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.hasReported && !viewModel.showSuccess {
                    // 已經檢舉過
                    alreadyReportedView
                } else if viewModel.showSuccess {
                    // 檢舉成功
                    successView
                } else {
                    // 檢舉表單
                    reportFormView
                }
            }
            .navigationTitle("檢舉內容")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                if !viewModel.hasReported && !viewModel.showSuccess {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("提交") {
                            Task {
                                await viewModel.submitReport()
                            }
                        }
                        .disabled(!viewModel.canSubmit)
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await viewModel.checkIfReported()
        }
    }
    
    // MARK: - Subviews
    
    private var reportFormView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 說明
                Text("請選擇檢舉原因，我們會盡快審核處理。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // 檢舉原因選項
                VStack(alignment: .leading, spacing: 12) {
                    Text("檢舉原因")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        ForEach(ReportCategory.allCases) { category in
                            CategoryRow(
                                category: category,
                                isSelected: viewModel.selectedCategory == category
                            ) {
                                viewModel.selectedCategory = category
                            }
                            
                            if category != ReportCategory.allCases.last {
                                Divider()
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
                
                // 詳細說明
                VStack(alignment: .leading, spacing: 12) {
                    Text("詳細說明")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextEditor(text: $viewModel.reason)
                        .frame(minHeight: 100)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .overlay(alignment: .topLeading) {
                            if viewModel.reason.isEmpty {
                                Text("請描述您檢舉的原因...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 28)
                                    .padding(.top, 20)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                // 錯誤訊息
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
                
                // 載入中
                if viewModel.isSubmitting {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                        Spacer()
                    }
                    .padding()
                }
            }
            .padding(.bottom, 32)
        }
    }
    
    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)
            
            Text("檢舉已送出")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("感謝您的回報，我們會盡快審核處理。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button {
                onReported?()
                dismiss()
            } label: {
                Text("完成")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
    
    private var alreadyReportedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
            
            Text("您已經檢舉過此內容")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("每則內容只能檢舉一次，我們會盡快審核處理。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Text("關閉")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: ReportCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(category.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ReportSheetView(
        target: .record(id: "test-id"),
        apiClient: DIContainer().apiClient
    )
}
