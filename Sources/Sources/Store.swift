import Foundation
import UserNotifications

enum PrayerName: String, CaseIterable, Codable, Identifiable {
    case fajr, dhuhr, asr, maghrib, isha
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum Mark: String, Codable, CaseIterable {
    case onTime = "On time", late = "Late", missed = "Missed"
}

struct Place: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneID: String
}

// Method ids are Aladhan API ids. Nothing is chosen for the user.
enum MethodChoice: Int, Codable, CaseIterable, Identifiable {
    case karachi = 1, northAmerica = 2, muslimWorldLeague = 3, ummAlQura = 4, egyptian = 5, singapore = 11, turkey = 13, dubai = 16
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .karachi: return "University of Islamic Sciences, Karachi"
        case .northAmerica: return "ISNA (North America)"
        case .muslimWorldLeague: return "Muslim World League"
        case .ummAlQura: return "Umm al-Qura, Makkah"
        case .egyptian: return "Egyptian General Authority of Survey"
        case .singapore: return "Singapore"
        case .turkey: return "Diyanet (Turkey)"
        case .dubai: return "Dubai"
        }
    }
}

enum AsrChoice: String, Codable, CaseIterable, Identifiable {
    case standard = "Shafi'i, Maliki, Hanbali (earlier Asr)"
    case hanafi = "Hanafi (later Asr)"
    var school: Int { self == .hanafi ? 1 : 0 }
    var id: String { rawValue }
}

struct Settings: Codable, Equatable {
    var place: Place?
    var method: MethodChoice?
    var asr: AsrChoice?
    var manualTimes: [String: String] = [:]   // prayer id -> "HH:mm" local to place; overrides calculation
    var remindersOn = false
    var isReady: Bool { place != nil && method != nil && asr != nil }
}

final class Store: ObservableObject {
    @Published var settings: Settings { didSet { save(); refreshTimes(); scheduleReminders() } }
    @Published var log: [String: [String: Mark]] { didSet { save() } }   // yyyy-MM-dd -> prayer -> mark

    private let key = "prayer.state.v1"
    private struct Persisted: Codable { var settings: Settings; var log: [String: [String: Mark]] }

    init() {
        if let d = UserDefaults.standard.data(forKey: key), let p = try? JSONDecoder().decode(Persisted.self, from: d) {
            settings = p.settings; log = p.log
        } else { settings = Settings(); log = [:] }
        if let d = UserDefaults.standard.data(forKey: "prayer.caches.v1"), let c = try? JSONDecoder().decode([String: MonthCache].self, from: d) { caches = c }
    }

    private func save() {
        if let d = try? JSONEncoder().encode(Persisted(settings: settings, log: log)) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    func calendar() -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: settings.place?.timeZoneID ?? "") ?? .current
        return c
    }

    func dayKey(_ date: Date) -> String {
        let f = DateFormatter(); f.calendar = calendar(); f.timeZone = calendar().timeZone
        f.dateFormat = "yyyy-MM-dd"; return f.string(from: date)
    }

    /// Time for a prayer on a given date. A manual time wins over calculation.
    func time(for prayer: PrayerName, on date: Date) -> Date? {
        let cal = calendar()
        if let hhmm = settings.manualTimes[prayer.rawValue] {
            let parts = hhmm.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                return cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date)
            }
        }
        guard let day = cachedMonth(for: date)?.days[dayKey(date)] else { return nil }
        return day[prayer.rawValue].flatMap { hhmm in
            let parts = hhmm.split(separator: ":").compactMap { Int($0) }
            return parts.count == 2 ? cal.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date) : nil
        }
    }

    // MARK: Automatic times from the Aladhan public API (https://aladhan.com)
    struct MonthCache: Codable { var key: String; var fetchedAt: Date; var days: [String: [String: String]] }
    @Published var caches: [String: MonthCache] = [:]
    @Published var fetchStatus = ""

    private func cacheKey(_ date: Date) -> String? {
        guard let p = settings.place, let m = settings.method, let a = settings.asr else { return nil }
        let c = calendar().dateComponents([.year, .month], from: date)
        return "\(p.latitude),\(p.longitude)|\(p.timeZoneID)|m\(m.rawValue)|s\(a.school)|\(c.year!)-\(c.month!)"
    }
    func cachedMonth(for date: Date) -> MonthCache? { cacheKey(date).flatMap { caches[$0] } }
    var lastUpdated: Date? { caches.values.map(\.fetchedAt).max() }
    var isStale: Bool { (lastUpdated.map { Date().timeIntervalSince($0) > 7 * 86400 } ?? true) }

    /// Fetches this month and next for the chosen place/method/Asr rule. Safe to call often: skips fresh caches.
    func refreshTimes(force: Bool = false) {
        guard let p = settings.place, let m = settings.method, let a = settings.asr else { return }
        let cal = calendar()
        for offset in 0...1 {
            guard let d = cal.date(byAdding: .month, value: offset, to: Date()), let key = cacheKey(d) else { continue }
            if !force, let c = caches[key], Date().timeIntervalSince(c.fetchedAt) < 86400 { continue }
            let c = cal.dateComponents([.year, .month], from: d)
            var comps = URLComponents(string: "https://api.aladhan.com/v1/calendar/\(c.year!)/\(c.month!)")!
            comps.queryItems = [
                .init(name: "latitude", value: String(p.latitude)), .init(name: "longitude", value: String(p.longitude)),
                .init(name: "method", value: String(m.rawValue)), .init(name: "school", value: String(a.school)),
                .init(name: "timezonestring", value: p.timeZoneID)]
            guard let url = comps.url else { continue }
            URLSession.shared.dataTask(with: url) { data, resp, err in
                DispatchQueue.main.async {
                    guard let data, (resp as? HTTPURLResponse)?.statusCode == 200, let days = Self.parse(data, tz: p.timeZoneID) else {
                        self.fetchStatus = "Could not update times. Showing the last saved times if any."
                        return
                    }
                    self.caches[key] = MonthCache(key: key, fetchedAt: Date(), days: days)
                    self.fetchStatus = ""
                    self.saveCaches()
                    self.scheduleReminders()
                }
            }.resume()
        }
    }

    private static func parse(_ data: Data, tz: String) -> [String: [String: String]]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["data"] as? [[String: Any]] else { return nil }
        var out: [String: [String: String]] = [:]
        for item in arr {
            guard let timings = item["timings"] as? [String: String],
                  let date = (item["date"] as? [String: Any])?["gregorian"] as? [String: Any],
                  let ds = date["date"] as? String else { continue }   // DD-MM-YYYY
            let p = ds.split(separator: "-"); guard p.count == 3 else { continue }
            func hm(_ k: String) -> String? { timings[k].map { String($0.prefix(5)) } }
            out["\(p[2])-\(p[1])-\(p[0])"] = ["fajr": hm("Fajr") ?? "", "dhuhr": hm("Dhuhr") ?? "", "asr": hm("Asr") ?? "",
                                                 "maghrib": hm("Maghrib") ?? "", "isha": hm("Isha") ?? ""]
        }
        return out.isEmpty ? nil : out
    }
    private func saveCaches() {
        if let d = try? JSONEncoder().encode(caches) { UserDefaults.standard.set(d, forKey: "prayer.caches.v1") }
    }

    func setMark(_ mark: Mark?, prayer: PrayerName, date: Date) {
        let k = dayKey(date)
        var day = log[k] ?? [:]
        if let mark { day[prayer.rawValue] = mark } else { day.removeValue(forKey: prayer.rawValue) }
        log[k] = day
    }

    // MARK: Notifications (local, on this device)
    func requestAndEnableReminders() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.settings.remindersOn = granted }
        }
    }

    func scheduleReminders() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard settings.remindersOn, settings.isReady else { return }
        let cal = calendar()
        let now = Date()
        for dayOffset in 0..<7 {   // 35 requests, under the 64 pending limit
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for p in PrayerName.allCases {
                guard let t = time(for: p, on: day), t > now else { continue }
                let content = UNMutableNotificationContent()
                content.title = "\(p.title) time"
                content.body = "Open the app to mark it."
                content.sound = .default
                let comps = cal.dateComponents(in: cal.timeZone, from: t)
                var trig = DateComponents(); trig.year = comps.year; trig.month = comps.month; trig.day = comps.day
                trig.hour = comps.hour; trig.minute = comps.minute; trig.timeZone = cal.timeZone
                let req = UNNotificationRequest(identifier: "\(dayKey(day))-\(p.rawValue)", content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: trig, repeats: false))
                center.add(req)
            }
        }
    }
}
