import Foundation

extension String {
    /// Trimmed, or nil if empty after trimming — the "empty field → null" rule
    /// used across the forms (mirrors the RN `.trim() || null` pattern).
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
