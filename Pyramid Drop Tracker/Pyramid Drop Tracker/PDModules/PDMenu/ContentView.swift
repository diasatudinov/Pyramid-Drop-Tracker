//
//  ContentView.swift
//  Pyramid Drop Tracker
//
//

import SwiftUI

// MARK: - Root

struct ContentView: View {
    @StateObject private var viewModel = PyramidDropViewModel()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackground()
                .ignoresSafeArea()
            
            currentScreen
                .padding(.bottom, 86)
            
            BottomTabBar(viewModel: viewModel)
        }
        .overlay(alignment: .top) {
            if let message = viewModel.toastMessage {
                Text(message)
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.yellow)
                    .clipShape(Capsule())
                    .padding(.top, 55)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: viewModel.toastMessage)
    }
    
    @ViewBuilder
    private var currentScreen: some View {
        switch viewModel.selectedTab {
        case .setup:
            SetupView(viewModel: viewModel)
        case .live:
            LiveDropBoardView(viewModel: viewModel)
        case .archive:
            RulesView()
        case .statistics:
            StatisticsView(viewModel: viewModel)
        case .rules:
            ArchiveView(viewModel: viewModel)
        }
    }
}

#Preview {
    ContentView()
}
