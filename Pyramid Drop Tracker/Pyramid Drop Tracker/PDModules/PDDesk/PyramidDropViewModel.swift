//
//  PyramidDropViewModel.swift
//  Pyramid Drop Tracker
//
//

import SwiftUI

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
