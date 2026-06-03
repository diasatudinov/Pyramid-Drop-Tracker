//
//  StatisticsView.swift
//  Pyramid Drop Tracker
//
//

import SwiftUI

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
                        icon: "statsIcon1",
                        title: "TOTAL\nSESSIONS",
                        value: "\(viewModel.totalSessions)"
                    )
                    
                    MetricCard(
                        icon: "statsIcon2",
                        title: "OVERALL\nROI",
                        value: viewModel.overallROI.percentString
                    )
                    
                    MetricCard(
                        icon: "statsIcon3",
                        title: "DISCIPLINE\nRATE",
                        value: viewModel.disciplineRate.percentString
                    )
                    
                    MetricCard(
                        icon: "statsIcon4",
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
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        NeonCard {
            VStack(spacing: 8) {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 36)
                
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(value)
                    .font(.headline.bold())
                    .foregroundColor(.yellow)
                
            }
            .padding(-16)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
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

#Preview {
    StatisticsView(viewModel: PyramidDropViewModel())
}
