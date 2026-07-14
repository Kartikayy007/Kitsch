//
//  BackgroundPhoneCard.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI

struct BackgroundPhoneCard<Content: View>: View {
    var width: CGFloat = 110
    @ViewBuilder var content: () -> Content

    private let cornerRadius: CGFloat = 22

    var body: some View {
        content()
            .frame(width: width, height: width * (19.5 / 9.0))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }
}

#Preview {
    BackgroundPhoneCard {
        Color.blue
    }
    .padding()
    .background(Color.black)
}
