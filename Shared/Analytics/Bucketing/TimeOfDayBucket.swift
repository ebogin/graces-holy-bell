import Foundation

/// Maps a timestamp to one of eight equal 3-hour `time_of_day_bucket` labels,
/// using the local calendar.
///
/// Equal-width buckets (not the conventional uneven morning/evening split)
/// because prayer timing is genuinely unknown and may land at any hour,
/// including overnight — so every part of the day gets equal resolution.
enum TimeOfDayBucket {

    static func label(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 0..<3:   return "late-night"
        case 3..<6:   return "early-morning"
        case 6..<9:   return "morning"
        case 9..<12:  return "late-morning"
        case 12..<15: return "midday"
        case 15..<18: return "afternoon"
        case 18..<21: return "evening"
        default:      return "night" // 21..<24
        }
    }
}
