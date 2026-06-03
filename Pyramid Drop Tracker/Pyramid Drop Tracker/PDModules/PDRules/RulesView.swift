//
//  RulesView.swift
//  Pyramid Drop Tracker
//
//

import SwiftUI

// MARK: - Rules

struct RulesView: View {
    @State private var index: Int = 0
    
    private let rules = RuleCardModel.samples
    
    var body: some View {
        VStack(spacing: 20) {
            Image(.ruleText)
                .resizable()
                .scaledToFit()
                .frame(height: 130)
            
            RuleLargeCard(rule: rules[index])
                .padding(.bottom, 40)
            
            HStack(spacing: 30) {
                Button {
                    index = max(0, index - 1)
                } label: {
                    Image(index == 0 ? .backOffBtn : .backBtn)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 53)
                }
                .disabled(index == 0)
                
                Button {
                    index = min(rules.count - 1, index + 1)
                } label: {
                    Image(index == rules.count - 1 ? .nextOffBtn : .nextBtn)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 53)
                }
                .disabled(index == rules.count - 1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 22)
        .background(
            Image(.rulesBg)
                .resizable()
                .ignoresSafeArea()
        )
    }
}

struct RuleLargeCard: View {
    let rule: RuleCardModel
    
    var body: some View {
        VStack(spacing: 18) {
            Image(rule.icon)
                .resizable()
                .scaledToFit()
        }
        .padding(24)
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

#Preview {
    RulesView()
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
            icon: "rule1",
            title: "Illusion of Control",
            text: "You can’t control where the ball goes. It’s pure RNG. Every drop is independent.",
            color: .purple
        ),
        .init(
            number: 2,
            icon: "rule2",
            title: "Magnetic Center",
            text: "On 16 rows, the ball often lands in central zones. Build your bankroll around that.",
            color: .red
        ),
        .init(
            number: 3,
            icon: "rule3",
            title: "100-Drop Rule",
            text: "If the multiplier doesn’t hit in 100 drops, don’t increase your bet. The algorithm has no memory.",
            color: .blue
        ),
        .init(
            number: 4,
            icon: "rule4",
            title: "Spam Protection",
            text: "Don’t drop 10 balls at once. It leads to loss of control. Track each drop.",
            color: .orange
        ),
        .init(
            number: 5,
            icon: "rule5",
            title: "Stop-Breath Rule",
            text: "After 3 losses in a row, take a 1-minute break. Adrenaline distorts risk assessment.",
            color: .green
        )
    ]
}
