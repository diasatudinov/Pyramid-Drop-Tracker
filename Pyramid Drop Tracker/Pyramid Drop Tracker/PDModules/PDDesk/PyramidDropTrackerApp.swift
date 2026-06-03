import SwiftUI
import Foundation

@main
struct PyramidDropTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Models

enum AppTab: Int, CaseIterable, Identifiable {
    case setup
    case live
    case archive
    case statistics
    case rules
    
    var id: Int { rawValue }
    
    var icon: String {
        switch self {
        case .setup: return "house.fill"
        case .live: return "triangle.fill"
        case .archive: return "circle.fill"
        case .statistics: return "chart.bar.fill"
        case .rules: return "book.fill"
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

struct RuleCardModel: Identifiable {
    let id = UUID()
    let number: Int
    let icon: String
    let title: String
    let text: String
    let color: Color
    
    static let samples: [RuleCardModel] = [
        .init(
            number: 1,
            icon: "die.face.5.fill",
            title: "Illusion of Control",
            text: "You can’t control where the ball goes. It’s pure RNG. Every drop is independent.",
            color: .purple
        ),
        .init(
            number: 2,
            icon: "magnet.fill",
            title: "Magnetic Center",
            text: "On 16 rows, the ball often lands in central zones. Build your bankroll around that.",
            color: .red
        ),
        .init(
            number: 3,
            icon: "calendar",
            title: "100-Drop Rule",
            text: "If the multiplier doesn’t hit in 100 drops, don’t increase your bet. The algorithm has no memory.",
            color: .blue
        ),
        .init(
            number: 4,
            icon: "nosign",
            title: "Spam Protection",
            text: "Don’t drop 10 balls at once. It leads to loss of control. Track each drop.",
            color: .orange
        ),
        .init(
            number: 5,
            icon: "lungs.fill",
            title: "Stop-Breath Rule",
            text: "After 3 losses in a row, take a 1-minute break. Adrenaline distorts risk assessment.",
            color: .green
        )
    ]
}

// MARK: - ViewModel

@MainActor
final class PyramidDropViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .setup
    
    @Published var platform: String = ""
    @Published var rowsValue: Double = 16
    @Published var risk: RiskLevel = .medium
    @Published var betSizeText: String = "1"
    @Published var stopLossText: String = "200"
    @Published var takeProfitText: String = "100"
    
    @Published var activeSession: GameSession?
    @Published var sessions: [GameSession] = [] {
        didSet { saveSessions() }
    }
    
    @Published var now = Date()
    @Published var tiltState: TiltState = .normal
    @Published var toastMessage: String?
    @Published var lockRemaining: Int = 0
    
    private var tapDates: [Date] = []
    private var timer: Timer?
    private var toastTask: Task<Void, Never>?
    private var lockTask: Task<Void, Never>?
    
    private let storageKey = "pyramid.drop.sessions"
    
    init() {
        loadSessions()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
            }
        }
    }
    
    func startSession() {
        guard let betSize = parseAmount(betSizeText), betSize > 0 else {
            showToast("Enter valid bet size")
            return
        }
        
        guard let stopLoss = parseAmount(stopLossText), stopLoss > 0 else {
            showToast("Stop-Loss is required")
            return
        }
        
        let takeProfit = parseAmount(takeProfitText)
        
        let config = SessionConfig(
            platform: platform.trimmingCharacters(in: .whitespacesAndNewlines),
            rows: Int(rowsValue),
            risk: risk,
            betSize: betSize,
            stopLoss: stopLoss,
            takeProfit: takeProfit
        )
        
        activeSession = GameSession(config: config)
        tapDates.removeAll()
        tiltState = .normal
        selectedTab = .live
    }
    
    func recordDrop(multiplier: Double) {
        guard activeSession != nil else {
            selectedTab = .setup
            return
        }
        
        guard tiltState != .locked else { return }
        
        let date = Date()
        tapDates = tapDates.filter { date.timeIntervalSince($0) <= 10 }
        tapDates.append(date)
        
        if tapDates.count > 13 || (tiltState == .warning && tapDates.count > 11) {
            if var session = activeSession {
                session.tiltViolations += 1
                activeSession = session
            }
            startLock(seconds: 15)
            return
        }
        
        if tapDates.count > 10 {
            tiltState = .warning
            showToast("Slow down. Every drop matters.")
        }
        
        guard var session = activeSession else { return }
        
        let profit = session.config.betSize * (multiplier - 1)
        let drop = DropResult(date: date, multiplier: multiplier, profit: profit)
        session.drops.append(drop)
        activeSession = session
        
        checkLimits()
    }
    
    func finishSession(reason: EndReason) {
        guard var session = activeSession else { return }
        
        session.endDate = Date()
        session.endReason = reason
        
        sessions.insert(session, at: 0)
        activeSession = nil
        tapDates.removeAll()
        tiltState = .normal
        selectedTab = .archive
    }
    
    func multipliersForCurrentSession() -> [Double] {
        let rows = activeSession?.config.rows ?? Int(rowsValue)
        let risk = activeSession?.config.risk ?? risk
        return MultiplierFactory.make(rows: rows, risk: risk)
    }
    
    func roiForRisk(_ risk: RiskLevel) -> Double {
        let filtered = sessions.filter { $0.config.risk == risk }
        let totalStart = filtered.reduce(0) { $0 + $1.startBalance }
        let totalProfit = filtered.reduce(0) { $0 + $1.profit }
        guard totalStart > 0 else { return 0 }
        return totalProfit / totalStart * 100
    }
    
    var totalSessions: Int {
        sessions.count
    }
    
    var totalProfit: Double {
        sessions.reduce(0) { $0 + $1.profit }
    }
    
    var overallROI: Double {
        let totalStart = sessions.reduce(0) { $0 + $1.startBalance }
        guard totalStart > 0 else { return 0 }
        return totalProfit / totalStart * 100
    }
    
    var disciplineRate: Double {
        guard !sessions.isEmpty else { return 0 }
        let disciplined = sessions.filter(\.isCompletedByLimitWithoutTilt).count
        return Double(disciplined) / Double(sessions.count) * 100
    }
    
    var averageSessionTime: TimeInterval {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.reduce(0) { $0 + $1.duration() }
        return total / Double(sessions.count)
    }
    
    var bankrollPoints: [Double] {
        var result: [Double] = [0]
        var current: Double = 0
        
        for session in sessions.reversed() {
            current += session.profit
            result.append(current)
        }
        
        return result
    }
    
    private func checkLimits() {
        guard let session = activeSession else { return }
        
        if session.profit <= -session.config.stopLoss {
            finishSession(reason: .stopLoss)
            return
        }
        
        if let takeProfit = session.config.takeProfit, session.profit >= takeProfit {
            finishSession(reason: .takeProfit)
            return
        }
    }
    
    private func startLock(seconds: Int) {
        tiltState = .locked
        toastMessage = nil
        lockTask?.cancel()
        
        lockTask = Task { @MainActor [weak self] in
            var remaining = seconds
            
            while remaining > 0 {
                self?.lockRemaining = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            
            self?.lockRemaining = 0
            self?.tiltState = .normal
            self?.tapDates.removeAll()
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.toastMessage = nil
        }
    }
    
    private func parseAmount(_ text: String) -> Double? {
        let clean = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !clean.isEmpty else { return nil }
        return Double(clean)
    }
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save sessions:", error)
        }
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        
        do {
            sessions = try JSONDecoder().decode([GameSession].self, from: data)
        } catch {
            print("Failed to load sessions:", error)
        }
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
            ArchiveView(viewModel: viewModel)
        case .statistics:
            StatisticsView(viewModel: viewModel)
        case .rules:
            RulesView()
        }
    }
}

// MARK: - Setup Screen

struct SetupView: View {
    @ObservedObject var viewModel: PyramidDropViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text("PYRAMID\nDROP\nTRACKER")
                    .font(.system(size: 34, weight: .black))
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                
                NeonCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("PLATFORM", systemImage: "building.2.fill")
                            .foregroundColor(.white)
                            .font(.caption.bold())
                        
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
                        Label("NUMBER OF ROWS", systemImage: "number")
                            .foregroundColor(.white)
                            .font(.caption.bold())
                        
                        HStack {
                            Text("\(Int(viewModel.rowsValue))")
                                .foregroundColor(.white)
                                .font(.title2.bold())
                            
                            Slider(value: $viewModel.rowsValue, in: 8...16, step: 1)
                        }
                        
                        PyramidPreview(rows: Int(viewModel.rowsValue), risk: viewModel.risk)
                            .frame(height: 120)
                    }
                }
                
                NeonCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("RISK LVL", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.caption.bold())
                        
                        RiskSegmentedPicker(selection: $viewModel.risk)
                    }
                }
                
                NeonCard {
                    AmountInputRow(
                        title: "BET SIZE",
                        icon: "dollarsign.circle.fill",
                        text: $viewModel.betSizeText,
                        placeholder: "1"
                    )
                }
                
                NeonCard {
                    AmountInputRow(
                        title: "STOP-LOSS REQUIRED",
                        icon: "shield.fill",
                        text: $viewModel.stopLossText,
                        placeholder: "200"
                    )
                }
                
                NeonCard {
                    AmountInputRow(
                        title: "TAKE PROFIT OPTIONAL",
                        icon: "target",
                        text: $viewModel.takeProfitText,
                        placeholder: "100"
                    )
                }
                
                Button {
                    viewModel.startSession()
                } label: {
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text("START DROPPING")
                                .font(.headline.bold())
                            Text("Let's track your drops!")
                                .font(.subheadline)
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.pink, lineWidth: 2)
                    )
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
            Label(title, systemImage: icon)
                .foregroundColor(.white)
                .font(.caption.bold())
            
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

// MARK: - Live Board

struct LiveDropBoardView: View {
    @ObservedObject var viewModel: PyramidDropViewModel
    
    var body: some View {
        ZStack {
            if let session = viewModel.activeSession {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        LiveTopPanel(session: session, now: viewModel.now)
                        
                        TiltRadarPanel(
                            state: viewModel.tiltState,
                            dropsCount: session.dropsCount
                        )
                        
                        PyramidPreview(rows: session.config.rows, risk: session.config.risk)
                            .frame(height: 210)
                            .padding(.vertical, 8)
                        
                        MultiplierButtonsView(
                            values: viewModel.multipliersForCurrentSession()
                        ) { multiplier in
                            viewModel.recordDrop(multiplier: multiplier)
                        }
                        
                        Button {
                            viewModel.finishSession(reason: .manualExit)
                        } label: {
                            HStack {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.title)
                                VStack(alignment: .leading) {
                                    Text("CASH OUT!")
                                        .font(.headline.bold())
                                    Text("Lock in your profit")
                                        .font(.subheadline)
                                }
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink.opacity(0.7), .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                }
            } else {
                EmptyLiveView {
                    viewModel.selectedTab = .setup
                }
            }
            
            if viewModel.tiltState == .locked {
                LockedOverlay(seconds: viewModel.lockRemaining)
            }
        }
    }
}

struct LiveTopPanel: View {
    let session: GameSession
    let now: Date
    
    var body: some View {
        NeonCard {
            HStack(spacing: 10) {
                LiveMetricView(
                    title: "BALANCE",
                    value: session.currentBalance.moneyString,
                    subtitle: "Start: \(session.startBalance.noZero)$"
                )
                
                Divider()
                    .background(Color.blue)
                
                LiveMetricView(
                    title: "SESSION ROI",
                    value: session.roi.percentString,
                    subtitle: session.profit.moneyString
                )
                
                Divider()
                    .background(Color.blue)
                
                LiveMetricView(
                    title: "SESSION TIME",
                    value: session.duration(until: now).timeString,
                    subtitle: ""
                )
            }
        }
    }
}

struct LiveMetricView: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.white)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.35))
                .cornerRadius(12)
            
            Text(subtitle)
                .font(.caption.bold())
                .foregroundColor(.yellow)
                .frame(height: 16)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TiltRadarPanel: View {
    let state: TiltState
    let dropsCount: Int
    
    var body: some View {
        let color: Color = {
            switch state {
            case .normal: return .green
            case .warning: return .yellow
            case .locked: return .red
            }
        }()
        
        let message: String = {
            switch state {
            case .normal: return "All good! Keep it up!"
            case .warning: return "Take your time. Every step counts!"
            case .locked: return "Calm down. Interface locked."
            }
        }()
        
        HStack {
            Image(systemName: "target")
                .foregroundColor(color)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text("TILT RADAR")
                    .font(.headline.bold())
                    .foregroundColor(color)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .foregroundColor(.pink)
                Text("\(dropsCount)")
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.35))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color, lineWidth: 2)
        )
    }
}

struct MultiplierButtonsView: View {
    let values: [Double]
    let onTap: (Double) -> Void
    
    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(values.indices, id: \.self) { index in
                let value = values[index]
                
                Button {
                    onTap(value)
                } label: {
                    Text(value.multiplierString)
                        .font(.headline.bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(buttonColor(for: value))
                        .cornerRadius(8)
                }
            }
        }
    }
    
    private func buttonColor(for value: Double) -> Color {
        if value < 1 { return .green }
        if value <= 5 { return .yellow }
        if value <= 26 { return .orange }
        return .red
    }
}

struct LockedOverlay: View {
    let seconds: Int
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.86)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Calm down!")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(.red)
                
                Text("The flood of messages is draining your bankroll.\nTake a deep breath.")
                    .font(.title3.bold())
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                
                ZStack {
                    Circle()
                        .stroke(Color.purple.opacity(0.4), lineWidth: 12)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(seconds) / 15)
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                    
                    Text("\(seconds)")
                        .font(.system(size: 44, weight: .black))
                        .foregroundColor(.white)
                }
            }
            .padding()
        }
    }
}

struct EmptyLiveView: View {
    let startAction: () -> Void
    
    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            
            Text("NO ACTIVE SESSION")
                .font(.title.bold())
                .foregroundColor(.yellow)
            
            Text("Start a new session from setup screen.")
                .foregroundColor(.white.opacity(0.8))
            
            Button(action: startAction) {
                Text("START DROPPING")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.purple)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

// MARK: - Archive

struct ArchiveView: View {
    @ObservedObject var viewModel: PyramidDropViewModel
    
    var body: some View {
        VStack {
            Text("SESSION ARCHIVE")
                .font(.title2.bold())
                .foregroundColor(.yellow)
                .padding(.top, 36)
            
            if viewModel.sessions.isEmpty {
                Spacer()
                
                VStack(spacing: 20) {
                    Text("THIS FIELD IS EMPTY.\nSTART A NEW SESSION.")
                        .font(.title3.bold())
                        .foregroundColor(.purple.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    Image(systemName: "face.dashed")
                        .font(.system(size: 80))
                        .foregroundColor(.purple)
                    
                    Button {
                        viewModel.selectedTab = .setup
                    } label: {
                        Text("START DROPPING")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 40)
                }
                
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(viewModel.sessions) { session in
                            SessionArchiveCard(session: session)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct SessionArchiveCard: View {
    let session: GameSession
    
    var body: some View {
        NeonCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(session.startDate.shortDateTime, systemImage: "calendar")
                            .foregroundColor(.white)
                        
                        Label("\(session.config.rows) rows / \(session.config.risk.displayTitle)", systemImage: "gearshape.fill")
                            .foregroundColor(session.config.risk.color)
                    }
                    
                    Spacer()
                    
                    Text(session.profit.moneyString)
                        .font(.title2.bold())
                        .foregroundColor(session.profit >= 0 ? .green : .red)
                }
                
                HStack {
                    SmallInfoBadge(
                        title: "\(session.dropsCount)",
                        subtitle: "DROPS",
                        color: .purple
                    )
                    
                    SmallInfoBadge(
                        title: session.maxMultiplier.multiplierString,
                        subtitle: "MAX",
                        color: .orange
                    )
                    
                    SmallInfoBadge(
                        title: session.roi.percentString,
                        subtitle: "ROI",
                        color: .green
                    )
                }
                
                if let reason = session.endReason {
                    Text("Finished: \(reason.title)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

struct SmallInfoBadge: View {
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.headline.bold())
            Text(subtitle)
                .font(.caption2.bold())
        }
        .foregroundColor(.white)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.7))
        .cornerRadius(10)
    }
}

// MARK: - Statistics

struct StatisticsView: View {
    @ObservedObject var viewModel: PyramidDropViewModel
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text("STATISTICS")
                    .font(.title2.bold())
                    .foregroundColor(.yellow)
                    .padding(.top, 36)
                
                HStack {
                    MetricCard(
                        title: "TOTAL\nSESSIONS",
                        value: "\(viewModel.totalSessions)"
                    )
                    
                    MetricCard(
                        title: "OVERALL\nROI",
                        value: viewModel.overallROI.percentString
                    )
                    
                    MetricCard(
                        title: "DISCIPLINE\nRATE",
                        value: viewModel.disciplineRate.percentString
                    )
                    
                    MetricCard(
                        title: "AVG SESSION\nTIME",
                        value: viewModel.averageSessionTime.shortMinutesString
                    )
                }
                
                NeonCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("ROI BY RISK LEVEL")
                            .font(.headline.bold())
                            .foregroundColor(.yellow)
                        
                        RiskROIChart(values: RiskLevel.allCases.map {
                            ($0, viewModel.roiForRisk($0))
                        })
                        .frame(height: 190)
                    }
                }
                
                NeonCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("BANKROLL OVER TIME")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        
                        BankrollLineChart(points: viewModel.bankrollPoints)
                            .frame(height: 190)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption2.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.yellow)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.purple.opacity(0.35))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple, lineWidth: 1)
        )
    }
}

struct RiskROIChart: View {
    let values: [(RiskLevel, Double)]
    
    var body: some View {
        let maxAbs = max(values.map { abs($0.1) }.max() ?? 1, 1)
        
        HStack(alignment: .bottom, spacing: 22) {
            ForEach(values, id: \.0.id) { item in
                VStack(spacing: 8) {
                    Text(item.1.percentString)
                        .font(.caption.bold())
                        .foregroundColor(item.0.color)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(item.0.color)
                        .frame(height: max(8, CGFloat(abs(item.1) / maxAbs) * 110))
                    
                    Text(item.0.title)
                        .font(.caption2.bold())
                        .foregroundColor(item.0.color)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct BankrollLineChart: View {
    let points: [Double]
    
    var body: some View {
        GeometryReader { geometry in
            if points.count < 2 {
                Text("Not enough data")
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let minValue = points.min() ?? 0
                let maxValue = points.max() ?? 1
                let range = max(maxValue - minValue, 1)
                
                Path { path in
                    for index in points.indices {
                        let x = geometry.size.width * CGFloat(index) / CGFloat(points.count - 1)
                        let normalized = (points[index] - minValue) / range
                        let y = geometry.size.height - geometry.size.height * CGFloat(normalized)
                        
                        if index == points.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.yellow, lineWidth: 3)
                
                ForEach(points.indices, id: \.self) { index in
                    let x = geometry.size.width * CGFloat(index) / CGFloat(points.count - 1)
                    let normalized = (points[index] - minValue) / range
                    let y = geometry.size.height - geometry.size.height * CGFloat(normalized)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7, height: 7)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Rules

struct RulesView: View {
    @State private var index: Int = 0
    
    private let rules = RuleCardModel.samples
    
    var body: some View {
        VStack(spacing: 20) {
            Text("PYRAMID\nDROP\nTRACKER")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.yellow)
                .multilineTextAlignment(.center)
                .padding(.top, 34)
            
            Text("RESPONSIBLE RULES")
                .font(.headline.bold())
                .foregroundColor(.yellow)
            
            Spacer()
            
            RuleLargeCard(rule: rules[index])
            
            HStack(spacing: 24) {
                Button {
                    index = max(0, index - 1)
                } label: {
                    Label("BACK", systemImage: "chevron.left.2")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(index == 0 ? Color.gray : Color.red)
                        .cornerRadius(12)
                }
                .disabled(index == 0)
                
                Button {
                    index = min(rules.count - 1, index + 1)
                } label: {
                    Label("NEXT", systemImage: "chevron.right.2")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(index == rules.count - 1 ? Color.gray : Color.green)
                        .cornerRadius(12)
                }
                .disabled(index == rules.count - 1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 22)
    }
}

struct RuleLargeCard: View {
    let rule: RuleCardModel
    
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(rule.color.opacity(0.25))
                    .frame(width: 100, height: 100)
                
                Image(systemName: rule.icon)
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }
            
            Text("\(rule.number)")
                .font(.title.bold())
                .foregroundColor(.white)
                .padding(10)
                .background(rule.color)
                .clipShape(Circle())
            
            Text(rule.title)
                .font(.title3.bold())
                .foregroundColor(.white)
            
            Text(rule.text)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [rule.color.opacity(0.8), Color.black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(rule.color, lineWidth: 3)
        )
    }
}

// MARK: - Shared UI

struct BottomTabBar: View {
    @ObservedObject var viewModel: PyramidDropViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    if tab == .live && viewModel.activeSession == nil {
                        viewModel.selectedTab = .setup
                    } else {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.title2.bold())
                        .foregroundColor(isSelected(tab) ? .yellow : .purple)
                        .frame(width: isSelected(tab) ? 58 : 48, height: isSelected(tab) ? 58 : 48)
                        .background(isSelected(tab) ? Color.purple : Color.black.opacity(0.35))
                        .cornerRadius(16)
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
                            .frame(height: 8)
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
            .background(Color.blue.opacity(0.32))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.blue, lineWidth: 1.5)
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

// MARK: - Formatters

extension Double {
    var noZero: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        } else {
            return String(format: "%.2f", self)
        }
    }
    
    var moneyString: String {
        if self >= 0 {
            return "+\(String(format: "%.2f", self))$"
        } else {
            return "\(String(format: "%.2f", self))$"
        }
    }
    
    var percentString: String {
        if self >= 0 {
            return "+\(String(format: "%.2f", self))%"
        } else {
            return "\(String(format: "%.2f", self))%"
        }
    }
    
    var multiplierString: String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return "x\(Int(self))"
        } else {
            return "x\(String(format: "%.1f", self))"
        }
    }
}

extension TimeInterval {
    var timeString: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    var shortMinutesString: String {
        let minutes = Int(self / 60)
        let seconds = Int(self) % 60
        
        if minutes == 0 {
            return "\(seconds)s"
        }
        
        return "\(minutes)m \(seconds)s"
    }
}

extension Date {
    var shortDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy HH:mm"
        return formatter.string(from: self)
    }
}