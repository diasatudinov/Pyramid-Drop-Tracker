//
//  Formatter + ext.swift
//  Pyramid Drop Tracker
//
//

import SwiftUI

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
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: self)
    }
    
    var shortTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
}
