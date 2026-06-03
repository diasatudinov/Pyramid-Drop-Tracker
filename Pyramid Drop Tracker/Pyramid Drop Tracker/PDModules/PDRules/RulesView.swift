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
