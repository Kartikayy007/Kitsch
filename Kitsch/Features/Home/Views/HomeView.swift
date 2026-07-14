//
//  HomeView.swift
//  Kitsch
//
//  Created by kartikay on 10/07/26.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var isEditorPresented = false

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()

                Text(viewModel.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Button("something") {
                    isEditorPresented = true
                }
                .padding(.bottom, 40)
            }
            .navigationTitle(viewModel.title)
            .fullScreenCover(isPresented: $isEditorPresented) {
                EditorView()
            }
        }
    }
}

#Preview {
    HomeView()
}
