//
//  SkeletonViews.swift
//  Raibu
//
//  Created on 2026/01/01.
//

import SwiftUI

// MARK: - Record Detail Skeleton

/// 紀錄詳情頁的骨架載入畫面
struct RecordDetailSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 圖片輪播區域
                ShimmerBox(height: 280, cornerRadius: 0)

                VStack(alignment: .leading, spacing: 16) {
                    // 描述文字
                    ShimmerBox(height: 16)
                    ShimmerBox(width: 250, height: 16)
                    ShimmerBox(width: 180, height: 16)

                    // 時間
                    HStack {
                        ShimmerBox(width: 20, height: 20, cornerRadius: 4)
                        ShimmerBox(width: 120, height: 14)
                    }

                    // 作者
                    HStack(spacing: 10) {
                        ShimmerCircle(size: 36)
                        ShimmerBox(width: 80, height: 16)
                    }

                    // Divider
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)

                    // 回覆區標題
                    HStack {
                        ShimmerBox(width: 60, height: 18)
                        ShimmerBox(width: 30, height: 14)
                    }

                    // 回覆列表
                    ForEach(0..<2, id: \.self) { _ in
                        ReplyRowSkeleton()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Ask Detail Skeleton

/// 詢問詳情頁的骨架載入畫面
struct AskDetailSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 問題標題
                ShimmerBox(height: 20)
                ShimmerBox(width: 200, height: 20)

                // 範圍資訊
                HStack {
                    ShimmerBox(width: 100, height: 14)
                    ShimmerBox(width: 80, height: 14)
                }

                // Divider
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                // 作者資訊
                HStack(spacing: 12) {
                    ShimmerCircle(size: 44)
                    VStack(alignment: .leading, spacing: 4) {
                        ShimmerBox(width: 80, height: 14)
                        ShimmerBox(width: 60, height: 12)
                    }
                    Spacer()
                    ShimmerBox(width: 50, height: 28, cornerRadius: 14)
                }

                // Divider
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                // 回覆區標題
                HStack {
                    ShimmerBox(width: 60, height: 18)
                    ShimmerBox(width: 30, height: 14)
                }

                // 回覆列表
                ForEach(0..<3, id: \.self) { _ in
                    ReplyRowSkeleton()
                }
            }
            .padding()
        }
    }
}

// MARK: - Reply Row Skeleton

/// 回覆列的骨架
struct ReplyRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 作者 & 時間
            HStack {
                ShimmerCircle(size: 28)
                ShimmerBox(width: 60, height: 12)
                Spacer()
                ShimmerBox(width: 40, height: 10)
            }

            // 內容
            ShimmerBox(height: 14)
            ShimmerBox(width: 200, height: 14)

            // 愛心
            HStack {
                Spacer()
                ShimmerBox(width: 50, height: 24, cornerRadius: 12)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Profile Card Skeleton

/// 個人資料卡片的骨架
struct ProfileCardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // 頭像
            ShimmerCircle(size: 100)

            // 名稱
            ShimmerBox(width: 120, height: 22)

            // 加入時間
            ShimmerBox(width: 100, height: 12)
        }
        .padding()
    }
}

// MARK: - Record Row Skeleton

/// 紀錄列表項目的骨架
struct RecordRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // 縮圖
            ShimmerSquare(size: 60)

            VStack(alignment: .leading, spacing: 4) {
                // 描述
                ShimmerBox(height: 14)
                ShimmerBox(width: 120, height: 14)

                // 統計
                HStack(spacing: 12) {
                    ShimmerBox(width: 40, height: 12)
                    ShimmerBox(width: 40, height: 12)
                }
            }

            Spacer()

            ShimmerBox(width: 8, height: 14, cornerRadius: 2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

// MARK: - Ask Row Skeleton

/// 詢問列表項目的骨架
struct AskRowSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // 圖示
            ShimmerSquare(size: 60)

            VStack(alignment: .leading, spacing: 4) {
                // 問題
                ShimmerBox(height: 14)
                ShimmerBox(width: 150, height: 14)

                // 統計
                HStack(spacing: 12) {
                    ShimmerBox(width: 50, height: 12)
                    ShimmerBox(width: 40, height: 12)
                }
            }

            Spacer()

            ShimmerBox(width: 8, height: 14, cornerRadius: 2)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

// MARK: - Previews

#Preview("Record Detail Skeleton") {
    RecordDetailSkeleton()
}

#Preview("Ask Detail Skeleton") {
    AskDetailSkeleton()
}

#Preview("Profile Card Skeleton") {
    ProfileCardSkeleton()
}

#Preview("Record Row Skeleton") {
    VStack(spacing: 12) {
        RecordRowSkeleton()
        RecordRowSkeleton()
    }
    .padding()
}

#Preview("Ask Row Skeleton") {
    VStack(spacing: 12) {
        AskRowSkeleton()
        AskRowSkeleton()
    }
    .padding()
}
