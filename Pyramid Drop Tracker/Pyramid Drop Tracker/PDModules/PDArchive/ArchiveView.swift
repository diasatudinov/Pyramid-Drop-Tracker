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
