//
//  BackgroundImageSourceView.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI

struct BackgroundImageSourceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 28) {
                sourceOption(
                    title: "From Your Images",
                    systemImage: "photo.on.rectangle"
                )

                sourceOption(
                    title: "Image Playground",
                    systemImage: "sparkles"
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Images")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func sourceOption(title: String, systemImage: String) -> some View {
        Button {} label: {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Color.white.opacity(0.12), in: Circle())

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .frame(width: 90)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        BackgroundImageSourceView()
    }
    .preferredColorScheme(.dark)
}
