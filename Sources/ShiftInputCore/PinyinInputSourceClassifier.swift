public enum PinyinInputSourceClassifier {
    /// Matches Apple's standard Simplified and Traditional Pinyin modes while
    /// deliberately excluding Zhuyin and other Chinese input modes.
    public static func isApplePinyin(id: String, localizedName: String) -> Bool {
        let normalizedID = id.lowercased()
        let normalizedName = localizedName.lowercased()
        return normalizedID.contains(".pinyin")
            || normalizedID == "com.apple.inputmethod.scim.itabc"
            || normalizedName.contains("pinyin")
            || normalizedName.contains("拼音")
    }
}
