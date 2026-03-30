//
//  DetailReportPopup.swift
//  Raibu
//
//  共用元件：檢舉表單 Popup（Detail 樣式）
//

import SwiftUI

/// 檢舉表單 overlay
/// 視覺樣式與 DetailDeleteConfirmation 一致（遮罩 + 中央卡片）
struct DetailReportPopup: View {
    @Binding var isPresented: Bool
    @StateObject private var viewModel: ReportViewModel
    let onDismiss: (() -> Void)?

    init(
        isPresented: Binding<Bool>,
        target: ReportTargetType,
        apiClient: APIClient,
        onDismiss: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._viewModel = StateObject(wrappedValue: ReportViewModel(target: target, apiClient: apiClient))
        self.onDismiss = onDismiss
    }

    var body: some View {
        GeometryReader { proxy in
            let popupWidth = min(max(proxy.size.width - 40, 280), 360)
            let popupMaxHeight = min(proxy.size.height - 80, 560)

            ZStack {
                Color.appOverlay.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closePopup()
                    }

                popupCard(maxHeight: popupMaxHeight)
                    .frame(width: popupWidth)
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(.systemGray5), lineWidth: 0.8)
                    )
                    .shadow(color: Color.appOverlay.opacity(0.15), radius: 14, x: 0, y: 5)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .transition(.scale(scale: 0.94).combined(with: .opacity))
        .zIndex(210)
        .task {
            await viewModel.checkIfReported()
        }
    }

    private func popupCard(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            Text("檢舉內容")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.top, 16)
                .padding(.bottom, 14)

            Divider()

            if viewModel.hasReported && !viewModel.showSuccess {
                alreadyReportedContent(maxHeight: maxHeight)
            } else if viewModel.showSuccess {
                successContent(maxHeight: maxHeight)
            } else {
                reportFormContent(maxHeight: maxHeight)
            }
        }
    }

    private func reportFormContent(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("請選擇檢舉原因，我們會盡快審核處理。")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 14)

                    Text("檢舉原因")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    VStack(spacing: 0) {
                        ForEach(ReportCategory.allCases) { category in
                            reportCategoryRow(category)
                            if category != ReportCategory.allCases.last {
                                Divider()
                                    .padding(.leading, 36)
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text("詳細說明")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.reason)
                            .frame(minHeight: 96, maxHeight: 120)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .scrollContentBackground(.hidden)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if viewModel.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("請描述您檢舉的原因...")
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                .allowsHitTesting(false)
                        }
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.appDanger)
                    }

                    if viewModel.isSubmitting {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(.circular)
                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .frame(maxHeight: max(maxHeight - 156, 260))

            Divider()

            HStack(spacing: 0) {
                Button {
                    closePopup()
                } label: {
                    Text("取消")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    Task {
                        await viewModel.submitReport()
                    }
                } label: {
                    Text("提交")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(viewModel.canSubmit ? .appPrimary : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSubmit)
            }
            .frame(height: 54)
        }
    }

    private func alreadyReportedContent(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.brandOrange)

                Text("您已經檢舉過此內容")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text("每則內容只能檢舉一次，我們會盡快審核處理。")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: min(maxHeight - 110, 190))

            Divider()

            Button {
                closePopup()
            } label: {
                Text("關閉")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.appPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func successContent(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.appSuccess)

                Text("檢舉已送出")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Text("感謝您的回報，我們會盡快審核處理。")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: min(maxHeight - 110, 190))

            Divider()

            Button {
                closePopup()
            } label: {
                Text("完成")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.appPrimary)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func reportCategoryRow(_ category: ReportCategory) -> some View {
        Button {
            viewModel.selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.selectedCategory == category ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(viewModel.selectedCategory == category ? .appPrimary : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)

                    Text(category.description)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func closePopup() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isPresented = false
        }
        onDismiss?()
    }
}
