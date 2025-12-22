//
//  EditAskView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import Combine

/// 編輯詢問視圖
struct EditAskView: View {
    let askId: String
    let ask: Ask
    let uploadService: UploadService
    let askRepository: AskRepository
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditAskViewModel
    @State private var showErrorAlert = false
    
    init(
        askId: String,
        ask: Ask,
        uploadService: UploadService,
        askRepository: AskRepository,
        onComplete: @escaping () -> Void
    ) {
        self.askId = askId
        self.ask = ask
        self.uploadService = uploadService
        self.askRepository = askRepository
        self.onComplete = onComplete
        
        _viewModel = StateObject(wrappedValue: EditAskViewModel(
            ask: ask,
            uploadService: uploadService,
            askRepository: askRepository
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 問題
                    questionSection
                    
                    // 現有圖片 (可選)
                    if viewModel.existingImages.count > 0 {
                        existingImagesSection
                    }
                    
                    // 狀態
                    statusSection
                }
                .padding()
            }
            .navigationTitle("編輯詢問")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("儲存") {
                        Task {
                            await viewModel.save()
                            if viewModel.isCompleted {
                                onComplete()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave || viewModel.isSaving)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView("儲存中...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
            }
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("確定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let error = viewModel.errorMessage {
                    Text(error)
                }
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                showErrorAlert = newValue != nil
            }
        }
    }
    
    // MARK: - Question Section
    
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("問題")
                .font(.headline)
            
            TextEditor(text: $viewModel.question)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Existing Images Section
    
    private var existingImagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("附圖")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.existingImages) { image in
                        ZStack(alignment: .topTrailing) {
                            AsyncImage(url: URL(string: image.thumbnailPublicUrl ?? "")) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 80, height: 80)
                                        .clipped()
                                        .cornerRadius(8)
                                default:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(8)
                                }
                            }
                            
                            Button {
                                viewModel.removeImage(image)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("狀態")
                .font(.headline)
            
            Picker("狀態", selection: $viewModel.status) {
                Text("進行中").tag(AskStatus.active)
                Text("已解決").tag(AskStatus.resolved)
            }
            .pickerStyle(.segmented)
        }
    }
}

// MARK: - View Model

@MainActor
class EditAskViewModel: ObservableObject {
    @Published var question: String
    @Published var existingImages: [ImageMedia]
    @Published var status: AskStatus
    @Published var isSaving = false
    @Published var isCompleted = false
    @Published var errorMessage: String?
    
    private let askId: String
    private let uploadService: UploadService
    private let askRepository: AskRepository
    
    var canSave: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    init(ask: Ask, uploadService: UploadService, askRepository: AskRepository) {
        self.askId = ask.id
        self.question = ask.question
        self.existingImages = ask.images ?? []
        self.status = ask.status
        self.uploadService = uploadService
        self.askRepository = askRepository
    }
    
    func removeImage(_ image: ImageMedia) {
        existingImages.removeAll { $0.id == image.id }
    }
    
    func save() async {
        guard canSave else { return }
        
        isSaving = true
        errorMessage = nil
        
        do {
            try await askRepository.updateAsk(
                id: askId,
                question: question.trimmingCharacters(in: .whitespacesAndNewlines),
                status: status,
                sortedImages: nil
            )
            
            isCompleted = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
}
