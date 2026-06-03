//
//  PyramidDropTrackerApp.swift
//  Pyramid Drop Tracker
//
//


import SwiftUI
import Foundation

#Preview {
    ContentView()
}

// MARK: - Models

enum AppTab: Int, CaseIterable, Identifiable {
    case setup
    case live
    case archive
    case statistics
    case rules
    
    var id: Int { rawValue }
    
    var selectedIcon: String {
        switch self {
        case .setup: return "selectedTab1"
        case .live: return "selectedTab2"
        case .archive: return "selectedTab3"
        case .statistics: return "selectedTab4"
        case .rules: return "selectedTab5"
        }
    }
    
    var icon: String {
        switch self {
        case .setup: return "tab1"
        case .live: return "tab2"
        case .archive: return "tab3"
        case .statistics: return "tab4"
        case .rules: return "tab5"
        }
    }
}

enum RiskLevel: String, CaseIterable, Codable, Identifiable {
    case low
    case medium
    case high
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .low: return "LOW"
        case .medium: return "MEDIUM"
        case .high: return "HARD"
        }
    }
    
    var displayTitle: String {
        switch self {
        case .low: return "Low Risk"
        case .medium: return "Medium Risk"
        case .high: return "High Risk"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum EndReason: String, Codable {
    case takeProfit
    case stopLoss
    case manualExit
    
    var title: String {
        switch self {
        case .takeProfit: return "Take-Profit"
        case .stopLoss: return "Stop-Loss"
        case .manualExit: return "Manual Exit"
        }
    }
    
    var icon: String {
        switch self {
        case .takeProfit: return "takeIcon"
        case .stopLoss: return "stopIcon"
        case .manualExit: return "manualIcon"
        }
    }
}

enum TiltState {
    case normal
    case warning
    case locked
}

struct SessionConfig: Codable {
    var platform: String
    var rows: Int
    var risk: RiskLevel
    var betSize: Double
    var stopLoss: Double
    var takeProfit: Double?
}

struct DropResult: Identifiable, Codable {
    let id: UUID
    let date: Date
    let multiplier: Double
    let profit: Double
    
    init(date: Date, multiplier: Double, profit: Double) {
        self.id = UUID()
        self.date = date
        self.multiplier = multiplier
        self.profit = profit
    }
}

struct GameSession: Identifiable, Codable {
    let id: UUID
    var config: SessionConfig
    let startDate: Date
    var endDate: Date?
    var drops: [DropResult]
    var endReason: EndReason?
    var tiltViolations: Int
    
    init(config: SessionConfig) {
        self.id = UUID()
        self.config = config
        self.startDate = Date()
        self.endDate = nil
        self.drops = []
        self.endReason = nil
        self.tiltViolations = 0
    }
    
    // В этом каркасе stopLoss используем как стартовый лимит сессии.
    // Например stopLoss = 200 значит стартовый банк сессии 200$.
    var startBalance: Double {
        config.stopLoss
    }
    
    var profit: Double {
        drops.reduce(0) { $0 + $1.profit }
    }
    
    var currentBalance: Double {
        max(0, startBalance + profit)
    }
    
    var roi: Double {
        guard startBalance > 0 else { return 0 }
        return profit / startBalance * 100
    }
    
    var maxMultiplier: Double {
        drops.map(\.multiplier).max() ?? 0
    }
    
    var dropsCount: Int {
        drops.count
    }
    
    func duration(until date: Date = Date()) -> TimeInterval {
        (endDate ?? date).timeIntervalSince(startDate)
    }
    
    var isCompletedByLimitWithoutTilt: Bool {
        (endReason == .takeProfit || endReason == .stopLoss) && tiltViolations == 0
    }
}


// MARK: - Multiplier Factory

enum MultiplierFactory {
    static func make(rows: Int, risk: RiskLevel) -> [Double] {
        let count = max(6, min(rows + 1, 12))
        let center = Double(count - 1) / 2
        
        return (0..<count).map { index in
            let distance = abs(Double(index) - center) / center
            
            switch risk {
            case .low:
                if distance > 0.85 { return 5 }
                if distance > 0.60 { return 2 }
                if distance > 0.35 { return 1 }
                return 0.5
                
            case .medium:
                if distance > 0.90 { return 16 }
                if distance > 0.70 { return 5 }
                if distance > 0.45 { return 1 }
                return 0.2
                
            case .high:
                if distance > 0.90 { return 130 }
                if distance > 0.70 { return 26 }
                if distance > 0.50 { return 5 }
                return 0.2
            }
        }
    }
}

// MARK: - Setup Screen

struct SetupView: View {
    @ObservedObject var viewModel: PyramidDropViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Image(.setupText)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .padding(.top, 24)
                
                NeonCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(.setupIcon1)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                        
                        TextField("Provider name", text: $viewModel.platform)
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(12)
                    }
                }
                
                NeonCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(.setupIcon2)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                        
                        HStack {
                            Text("\(Int(viewModel.rowsValue))")
                                .foregroundColor(.white)
                                .font(.title2.bold())
                            
                            Slider(value: $viewModel.rowsValue, in: 8...16, step: 1)
                        }
                        
                        PyramidPreview(rows: Int(viewModel.rowsValue), risk: viewModel.risk)
                            .frame(height: 120)
                    }
                    .padding(.bottom, 120)
                }
                
                NeonCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(.setupIcon3)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                        
                        RiskSegmentedPicker(selection: $viewModel.risk)
                    }
                }
                
                NeonCard {
                    AmountInputRow(
                        title: "BET SIZE",
                        icon: "setupIcon4",
                        text: $viewModel.betSizeText,
                        placeholder: "1"
                    )
                }
                
                NeonCard {
                    AmountInputRow(
                        title: "STOP-LOSS REQUIRED",
                        icon: "setupIcon5",
                        text: $viewModel.stopLossText,
                        placeholder: "200"
                    )
                }
                
                NeonCard {
                    AmountInputRow(
                        title: "TAKE PROFIT OPTIONAL",
                        icon: "setupIcon6",
                        text: $viewModel.takeProfitText,
                        placeholder: "100"
                    )
                }
                
                Button {
                    viewModel.startSession()
                    viewModel.platform = ""
                } label: {
                    Image(.startBtn)
                        .resizable()
                        .scaledToFit()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

struct AmountInputRow: View {
    let title: String
    let icon: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        HStack {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(height: 24)
            
            Spacer()
            
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(width: 110)
                .background(Color.black.opacity(0.35))
                .cornerRadius(10)
        }
    }
}

struct RiskSegmentedPicker: View {
    @Binding var selection: RiskLevel
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(RiskLevel.allCases) { risk in
                Button {
                    selection = risk
                } label: {
                    Text(risk.title)
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selection == risk ? risk.color : Color.black.opacity(0.35))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shared UI

struct BottomTabBar: View {
    @ObservedObject var viewModel: PyramidDropViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    viewModel.selectedTab = tab
                    
                } label: {
                    Image(isSelected(tab) ? tab.selectedIcon : tab.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 60)
                        .offset(y: tab == .archive ? -10 : 0)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
    
    private func isSelected(_ tab: AppTab) -> Bool {
        viewModel.selectedTab == tab
    }
}

struct PyramidPreview: View {
    let rows: Int
    let risk: RiskLevel
    
    var body: some View {
        GeometryReader { geometry in
            let dotSize = min(geometry.size.width / CGFloat(rows + 10), 9)
            
            VStack(spacing: 4) {
                Spacer()
                
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(0...row, id: \.self) { _ in
                            Circle()
                                .fill(Color.white.opacity(0.82))
                                .frame(width: dotSize, height: dotSize)
                                .shadow(color: .white.opacity(0.5), radius: 2)
                        }
                    }
                }
                
                HStack(spacing: 4) {
                    ForEach(0..<min(rows + 1, 12), id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(binColor(index: index, count: min(rows + 1, 12)))
                            .frame(width: 18, height: 12)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func binColor(index: Int, count: Int) -> Color {
        let center = Double(count - 1) / 2
        let distance = abs(Double(index) - center) / center
        
        if distance > 0.75 { return .red }
        if distance > 0.45 { return .yellow }
        return .green
    }
}

struct NeonCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                Image(.cardBg)
                    .resizable()
            )
    }
}

struct NeonDarkCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                ZStack {
                    Image(.cardBg)
                        .resizable()
                    Color.black.opacity(0.5)
                }
            )
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.05, blue: 0.32),
                Color(red: 0.01, green: 0.24, blue: 0.80),
                Color(red: 0.01, green: 0.03, blue: 0.24)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}


