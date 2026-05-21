import Foundation

/// Languages available for on-device translation.
/// Only languages supported by Apple's Translation framework with
/// downloadable on-device models are listed here.
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case russian = "ru"
    case hindi = "hi"
    case vietnamese = "vi"
    case tagalog = "tl"
    case polish = "pl"
    case ukrainian = "uk"
    case turkish = "tr"
    case thai = "th"
    case indonesian = "id"
    case dutch = "nl"

    var id: String { rawValue }

    var displayName: String {
        let locale = Locale(identifier: rawValue)
        return Locale.current.localizedString(forIdentifier: locale.identifier)
            ?? rawValue.uppercased()
    }

    /// BCP-47 locale used by Apple frameworks
    var locale: Locale {
        Locale(identifier: rawValue)
    }
}
