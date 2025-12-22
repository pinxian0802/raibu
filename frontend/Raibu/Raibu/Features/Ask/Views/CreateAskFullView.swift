//
//  CreateAskFullView.swift
//  Raibu
//
//  Created on 2025/12/20.
//

import SwiftUI
import MapKit

/// 建立詢問視圖
struct CreateAskFullView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var container: DIContainer
    
    @StateObject private var viewModel: CreateAskViewModel
    @State private var showPhotoPicker = false
    @State private var showErrorAlert = false
    
    init(
        initialLocation: CLLocationCoordinate2D,
        uploadService: UploadService,
        askRepository: AskRepository
    ) {
        _viewModel = StateObject(wrappedValue: CreateAskViewModel(
            initialLocation: initialLocation,
            uploadService: uploadService,
            askRepository: askRepository
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 地圖預覽
                        mapPreview
                        
                        // 範圍選擇
                        radiusSection
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // 問題輸入
                        questionSection
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // 照片（選填）
                        photoSection
                    }
                    .padding(.vertical, 16)
                }
                
                // 提交按鈕
                submitButton
            }
            .navigationTitle("新增詢問")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(viewModel.isUploading)
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                CustomPhotoPickerView(
                    photoPickerService: container.photoPickerService,
                    requireGPS: false,
                    maxSelection: 5
                ) { photos in
                    viewModel.setPhotos(photos)
                }
            }
            .alert("錯誤", isPresented: $showErrorAlert) {
                Button("確定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                showErrorAlert = newValue != nil
            }
            .onChange(of: viewModel.isCompleted) { completed in
                if completed {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Map Preview
    
    private var mapPreview: some View {
        ZStack {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: viewModel.center,
                span: MKCoordinateSpan(
                    latitudeDelta: Double(viewModel.radiusMeters) / 50000,
                    longitudeDelta: Double(viewModel.radiusMeters) / 50000
                )
            )), annotationItems: [MapPin(coordinate: viewModel.center)]) { pin in
                MapAnnotation(coordinate: pin.coordinate) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            .disabled(true)
            
            // 範圍圓圈
            Circle()
                .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                .background(Circle().fill(Color.orange.opacity(0.1)))
                .frame(width: 100, height: 100)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Radius Section
    
    private var radiusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("詢問範圍")
                    .font(.headline)
                
                Spacer()
                
                Text(viewModel.radiusText)
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
            
            // 範圍滑桿
            HStack(spacing: 8) {
                ForEach(viewModel.radiusOptions, id: \.self) { radius in
                    Button {
                        withAnimation {
                            viewModel.radiusMeters = radius
                        }
                    } label: {
                        Text(radius >= 1000 ? "\(radius / 1000)km" : "\(radius)m")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.radiusMeters == radius ?
                                Color.orange : Color(.systemGray6)
                            )
                            .foregroundColor(
                                viewModel.radiusMeters == radius ?
                                .white : .primary
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
            
            Text("在此範圍內的回覆會被標記為實地回報")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Question Section
    
    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("問題內容")
                .font(.headline)
                .padding(.horizontal)
            
            TextEditor(text: $viewModel.question)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal)
                .overlay(
                    Group {
                        if viewModel.question.isEmpty {
                            Text("描述你想詢問的問題...")
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 28)
                                .padding(.top, 16)
                        }
                    },
                    alignment: .topLeading
                )
        }
    }
    
    // MARK: - Photo Section
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("附圖")
                    .font(.headline)
                
                Text("(選填，最多 5 張)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if viewModel.selectedPhotos.isEmpty {
                Button {
                    showPhotoPicker = true
                } label: {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("新增照片")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            } else {
                selectedPhotosView
            }
        }
    }
    
    private var selectedPhotosView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(viewModel.selectedPhotos.enumerated()), id: \.element.id) { index, photo in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: UIImage(data: photo.thumbnailData) ?? UIImage())
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        Button {
                            withAnimation {
                                viewModel.removePhoto(at: index)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
                
                if viewModel.selectedPhotos.count < 5 {
                    Button {
                        showPhotoPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .frame(width: 70, height: 70)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [6]))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Submit Button
    
    private var submitButton: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                Task {
                    await viewModel.submit()
                }
            } label: {
                ZStack {
                    if viewModel.isUploading {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("發布中...")
                        }
                    } else {
                        Text("發布詢問")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.canSubmit ? Color.orange : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!viewModel.canSubmit)
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Helper

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    CreateAskFullView(
        initialLocation: CLLocationCoordinate2D(latitude: 25.033, longitude: 121.565),
        uploadService: UploadService(apiClient: APIClient(baseURL: "", authService: AuthService())),
        askRepository: AskRepository(apiClient: APIClient(baseURL: "", authService: AuthService()))
    )
    .environmentObject(DIContainer())
}
