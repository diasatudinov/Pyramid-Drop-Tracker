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