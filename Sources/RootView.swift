import SwiftUI
import MapKit

struct RootView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Today", systemImage: "moon.stars") }
            HistoryView().tabItem { Label("History", systemImage: "calendar") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .onAppear { store.refreshTimes(); store.scheduleReminders() }
    }
}

struct TodayView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        NavigationView {
            List {
                if store.isTestData {
                    Section { Text("TEST DATA: synthetic city and times for a CI screenshot. Not live data.").foregroundColor(.red).font(.footnote) }
                }
                if !store.settings.isReady {
                    Section {
                        Text("Pick your city, calculation method and Asr rule in Settings to see times. Nothing is chosen for you.")
                    }
                }
                Section(header: Text(store.settings.place?.name ?? "No location")) {
                    ForEach(PrayerName.allCases) { p in row(p) }
                }
                if !store.fetchStatus.isEmpty { Section { Text(store.fetchStatus).font(.footnote).foregroundColor(.red) } }
                Section {
                    if store.settings.isReady {
                        Text(freshness()).font(.footnote)
                        Button("Update times now") { store.refreshTimes(force: true) }
                    }
                }
                Section { Text("Unmarked prayers stay Unconfirmed. They are never counted as missed.").font(.footnote) }
            }
            .navigationTitle("Today")
        }
    }

    func freshness() -> String {
        guard let d = store.lastUpdated else { return "Times not downloaded yet. Source: aladhan.com (calculated, not your mosque's iqamah)." }
        let f = RelativeDateTimeFormatter()
        return "Calculated times from aladhan.com, updated \(f.localizedString(for: d, relativeTo: Date()))\(store.isStale ? " (out of date, connect to refresh)" : ""). Mosque times you enter in Settings override these."
    }

    func timeText(_ p: PrayerName, _ day: Date) -> String {
        guard let t = store.time(for: p, on: day) else { return "Set up" }
        let f = DateFormatter(); f.timeStyle = .short; f.timeZone = store.calendar().timeZone
        return f.string(from: t)
    }

    @ViewBuilder func row(_ p: PrayerName) -> some View {
        let today = Date()
        let mark = store.log[store.dayKey(today)]?[p.rawValue]
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p.title).font(.headline)
                Spacer()
                Text(timeText(p, today)).monospacedDigit().foregroundColor(.secondary)
            }
            HStack {
                ForEach(Mark.allCases, id: \.self) { m in
                    Button(m.rawValue) { store.setMark(mark == m ? nil : m, prayer: p, date: today) }
                        .buttonStyle(.bordered)
                        .tint(mark == m ? .accentColor : .gray)
                }
            }
            Text(mark?.rawValue ?? "Unconfirmed").font(.caption).foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: Store
    var body: some View {
        NavigationView {
            List(store.log.keys.sorted(by: >), id: \.self) { k in
                VStack(alignment: .leading) {
                    Text(k).font(.headline)
                    Text(PrayerName.allCases.map { "\($0.title): \(store.log[k]?[$0.rawValue]?.rawValue ?? "Unconfirmed")" }.joined(separator: " · "))
                        .font(.footnote)
                }
            }
            .overlay { if store.log.isEmpty { Text("Nothing marked yet.").foregroundColor(.secondary) } }
            .navigationTitle("History")
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @State private var showSearch = false
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Location"), footer: Text("Choose any city. Location is never read automatically.")) {
                    Button(store.settings.place?.name ?? "Choose a city") { showSearch = true }
                    if let tz = store.settings.place?.timeZoneID { Text("Time zone: \(tz)").font(.footnote) }
                }
                Section(header: Text("Calculation"), footer: Text("Mosques and regions differ. Pick what your community follows.")) {
                    Picker("Method", selection: $store.settings.method) {
                        Text("Not chosen").tag(MethodChoice?.none)
                        ForEach(MethodChoice.allCases) { Text($0.title).tag(MethodChoice?.some($0)) }
                    }
                    Picker("Asr", selection: $store.settings.asr) {
                        Text("Not chosen").tag(AsrChoice?.none)
                        ForEach(AsrChoice.allCases) { Text($0.rawValue).tag(AsrChoice?.some($0)) }
                    }
                }
                Section(header: Text("Mosque times (optional)"), footer: Text("Enter your mosque's times (24-hour, like 05:25) to use them instead of calculated times. Leave blank to use calculation.")) {
                    ForEach(PrayerName.allCases) { p in
                        HStack {
                            Text(p.title)
                            TextField("HH:mm", text: Binding(
                                get: { store.settings.manualTimes[p.rawValue] ?? "" },
                                set: { v in
                                    if v.isEmpty { store.settings.manualTimes.removeValue(forKey: p.rawValue) }
                                    else { store.settings.manualTimes[p.rawValue] = v }
                                }))
                                .multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation)
                        }
                    }
                }
                Section(header: Text("Reminders"), footer: Text("Notifications are scheduled on this phone for the next 7 days and refresh when you open the app.")) {
                    Toggle("Remind me at prayer times", isOn: Binding(
                        get: { store.settings.remindersOn },
                        set: { on in if on { store.requestAndEnableReminders() } else { store.settings.remindersOn = false } }
                    )).disabled(!store.settings.isReady)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showSearch) { CitySearch { store.settings.place = $0 } }
        }
    }
}

struct CitySearch: View {
    var onPick: (Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    var body: some View {
        NavigationView {
            List(results, id: \.self) { item in
                Button {
                    let loc = item.placemark.coordinate
                                        let name = [item.placemark.locality ?? item.name, item.placemark.country].compactMap { $0 }.joined(separator: ", ")
                    onPick(Place(name: name, latitude: loc.latitude, longitude: loc.longitude, timeZoneID: item.placemark.timeZone?.identifier ?? ""))
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(item.name ?? "Unknown")
                        Text(item.placemark.title ?? "").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search city")
            .onSubmit(of: .search) { search() }
            .navigationTitle("Choose city")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func search() {
        let r = MKLocalSearch.Request(); r.naturalLanguageQuery = query; r.resultTypes = .address
        MKLocalSearch(request: r).start { resp, _ in results = resp?.mapItems ?? [] }
    }
}
