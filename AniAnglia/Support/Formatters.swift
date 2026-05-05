import Foundation

extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

extension Double {
    var gradeText: String {
        String(format: "%.1f", self)
    }
}

extension Int {
    var compactText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension URL {
    static func web(_ string: String?) -> URL? {
        guard let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty else {
            return nil
        }
        if string.hasPrefix("//") {
            return URL(string: "https:\(string)")
        }
        if string.hasPrefix("http://") || string.hasPrefix("https://") {
            return URL(string: string)
        }
        return URL(string: "https://\(string)")
    }
}
