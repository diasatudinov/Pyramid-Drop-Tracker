//
//  ArchiveView.swift
//  Pyramid Drop Tracker
//
//

import SwiftUI

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
                
                VStack(spacing: 24) {
                    Image(.emptyArch)
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 20)
                    
                    Button {
                        viewModel.selectedTab = .setup
                    } label: {
                        Image(.startBtn)
                            .resizable()
                            .scaledToFit()
                    }
                    .padding(.horizontal, 20)
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
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Image(.archIcon1)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 36)
                            
                            VStack(alignment: .leading) {
                                Text(session.startDate.shortDate)
                                    .bold()
                                    .foregroundColor(.white)
                                Text(session.startDate.shortTime)
                                    .bold()
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        
                        HStack {
                            Image(.archIcon2)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 36)
                            
                            VStack(alignment: .leading) {
                                Text("\(session.config.rows) rows")
                                    .bold()
                                    .foregroundColor(.white)
                                Text("\(session.config.risk.displayTitle)")
                                    .bold()
                                    .foregroundColor(session.config.risk.color)
                            }
                        }
                    }
                    
                    Spacer()
                    VStack {
                        Text(session.profit.moneyString)
                            .font(.title2.bold())
                            .foregroundColor(session.profit >= 0 ? .green : .red)
                        
                        if let reason = session.endReason {
                            Image(reason.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                        }
                    }
                }
                
                HStack(spacing: 5) {
                    SmallInfoBadge(
                        icon: "archIcon3",
                        title: "\(session.dropsCount)",
                        subtitle: "DROPS",
                        color: .purple
                    )
                    
                    SmallInfoBadge(
                        icon: "archIcon4",
                        title: session.maxMultiplier.multiplierString,
                        subtitle: "MAX",
                        color: .orange
                    )
                    
                    SmallInfoBadge(
                        icon: "archIcon5",
                        title: session.roi.percentString,
                        subtitle: "ROI",
                        color: .green
                    )
                }
            }
        }
    }
}

struct SmallInfoBadge: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        NeonDarkCard {
            HStack {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(-16)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
        }.clipShape(RoundedRectangle(cornerRadius: 10))
        
    }
}

#Preview {
    ArchiveView(viewModel: PyramidDropViewModel())
}
