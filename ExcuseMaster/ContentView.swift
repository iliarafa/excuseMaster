import SwiftUI

// MARK: - Models

/// The situation category for the excuse.
enum Category: String, CaseIterable, Identifiable {
    case work = "Work"
    case social = "Social"
    case family = "Family"
    case health = "Health"
    case chores = "Chores"
    case other = "Other"

    var id: String { rawValue }
}

/// The desired tone for the generated excuse.
enum Tone: String, CaseIterable, Identifiable {
    case funny = "Funny"
    case professional = "Believable/Professional"
    case dramatic = "Dramatic"
    case shortAndSweet = "Short & Sweet"

    var id: String { rawValue }
}

/// A generated excuse with metadata.
struct Excuse: Identifiable, Codable {
    var id: UUID = UUID()
    var text: String
    var reason: String
    var mechanics: [Int]
    var date: Date = Date()
}

/// Available AI models for the x.ai API.
enum AIModel: String, CaseIterable, Identifiable {
    case grok3Mini = "grok-3-mini"
    case grok4Fast = "grok-4-1-fast-reasoning"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grok3Mini: return "Grok 3 Mini"
        case .grok4Fast: return "Grok 4.1 Fast Reasoning"
        }
    }
}

// MARK: - Excuse Row View

/// Reusable row for displaying a single excuse in lists.
struct ExcuseRowView: View {
    let excuse: Excuse
    var showDate: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(excuse.text)
                .font(.body)
                .fontWeight(.medium)

            if !excuse.reason.isEmpty {
                Label(excuse.reason, systemImage: "lightbulb")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !excuse.mechanics.isEmpty {
                Label(
                    "Mechanics: \(excuse.mechanics.map(String.init).joined(separator: ", "))",
                    systemImage: "gearshape.2"
                )
                .font(.caption)
                .foregroundStyle(.blue)
            }

            if showDate {
                Label(excuse.date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Content View

struct ContentView: View {
    // MARK: Persisted Settings
    @AppStorage("apiKey") private var apiKey = ""
    @AppStorage("selectedModel") private var selectedModel = AIModel.grok3Mini.rawValue

    // MARK: Generate Tab State
    @State private var situation = ""
    @State private var category: Category = .work
    @State private var tone: Tone = .professional
    @State private var details = ""
    @State private var excuses: [Excuse] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    // MARK: History State
    @State private var history: [Excuse] = []
    @State private var searchText = ""

    // MARK: Settings State
    @State private var isTesting = false
    @State private var testResult: TestResult?

    /// Result of a connection test.
    private enum TestResult {
        case success
        case failure(String)
    }

    /// Creates a fresh service instance using current settings.
    private var service: ExcuseGeneratorService {
        ExcuseGeneratorService(apiKey: apiKey, model: selectedModel)
    }

    /// Filtered history based on search query.
    private var filteredHistory: [Excuse] {
        guard !searchText.isEmpty else { return history }
        return history.filter {
            $0.text.localizedCaseInsensitiveContains(searchText) ||
            $0.reason.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Body

    var body: some View {
        TabView {
            generateTab
                .tabItem { Label("Generate", systemImage: "lightbulb") }

            historyTab
                .tabItem { Label("History", systemImage: "clock") }

            settingsTab
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .onAppear { loadHistory() }
    }

    // MARK: - Generate Tab

    private var generateTab: some View {
        NavigationView {
            Form {
                // API key warning
                if apiKey.isEmpty {
                    Section {
                        Label("Set your API key in the Settings tab to get started.",
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                // Input fields
                Section("Situation") {
                    TextField("e.g. team meeting, dinner party...", text: $situation)
                        .autocorrectionDisabled()
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Tone") {
                    Picker("Tone", selection: $tone) {
                        ForEach(Tone.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Additional Details") {
                    TextField("Any extra context (optional)", text: $details)
                }

                // Actions
                Section {
                    // Generate button
                    Button {
                        generateExcuses()
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Excuse")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(situation.isEmpty || isLoading || apiKey.isEmpty)

                    // Clear form button
                    if !situation.isEmpty || !details.isEmpty || !excuses.isEmpty {
                        Button(role: .destructive) {
                            clearForm()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Clear Form")
                                Spacer()
                            }
                        }
                    }
                }

                // Error display
                if let errorMessage {
                    Section("Error") {
                        Label(errorMessage, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                }

                // Results
                Section("Results") {
                    if excuses.isEmpty {
                        Label("Tap Generate to create excuses", systemImage: "text.bubble")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(excuses) { excuse in
                            ExcuseRowView(excuse: excuse)
                                .swipeActions(edge: .trailing) {
                                    Button("Copy") {
                                        UIPasteboard.general.string = excuse.text
                                    }
                                    .tint(.blue)

                                    Button("Share") {
                                        share(excuse.text)
                                    }
                                    .tint(.green)
                                }
                        }
                    }
                }
            }
            .navigationTitle("ExcuseMaster")
        }
    }

    // MARK: - History Tab

    private var historyTab: some View {
        NavigationView {
            List {
                if filteredHistory.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No History" : "No Results",
                        systemImage: searchText.isEmpty ? "clock" : "magnifyingglass",
                        description: Text(
                            searchText.isEmpty
                                ? "Generated excuses will appear here."
                                : "No excuses match \"\(searchText)\"."
                        )
                    )
                } else {
                    ForEach(filteredHistory) { excuse in
                        ExcuseRowView(excuse: excuse, showDate: true)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteExcuse(excuse)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("Copy") {
                                    UIPasteboard.general.string = excuse.text
                                }
                                .tint(.blue)

                                Button("Share") {
                                    share(excuse.text)
                                }
                                .tint(.green)
                            }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search excuses...")
            .navigationTitle("History")
            .toolbar {
                if !history.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear All", role: .destructive) {
                            history.removeAll()
                            saveHistory()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        NavigationView {
            Form {
                Section {
                    SecureField("Enter your x.ai API key", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Stored locally on this device. Never sent anywhere except x.ai.")
                }

                Section("Model") {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(AIModel.allCases) { model in
                            Text(model.displayName).tag(model.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Connection") {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Spacer()
                            if isTesting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Testing...")
                                    .foregroundStyle(.secondary)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                Text("Test Connection")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(apiKey.isEmpty || isTesting)

                    // Test result feedback
                    if let testResult {
                        switch testResult {
                        case .success:
                            Label("Connection successful!", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        case .failure(let message):
                            Label(message, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.subheadline)
                        }
                    }
                }

                // Status
                Section("Status") {
                    if apiKey.isEmpty {
                        Label("API key required", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Label("Settings saved automatically", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Actions

    /// Calls the API and populates the excuses list.
    private func generateExcuses() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                excuses = try await service.generateExcuses(
                    for: situation,
                    category: category.rawValue,
                    tone: tone.rawValue,
                    details: details
                )
                // Save to history
                history.insert(contentsOf: excuses, at: 0)
                saveHistory()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    /// Resets all form fields and results.
    private func clearForm() {
        situation = ""
        category = .work
        tone = .professional
        details = ""
        excuses = []
        errorMessage = nil
    }

    /// Tests the API connection with a minimal request.
    private func testConnection() {
        Task {
            isTesting = true
            testResult = nil
            do {
                _ = try await service.testConnection()
                testResult = .success
            } catch {
                testResult = .failure(error.localizedDescription)
            }
            isTesting = false
        }
    }

    /// Removes a single excuse from history.
    private func deleteExcuse(_ excuse: Excuse) {
        history.removeAll { $0.id == excuse.id }
        saveHistory()
    }

    /// Presents the system share sheet for the given text.
    private func share(_ text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = windowScene.keyWindow?.rootViewController else { return }

        if let presented = root.presentedViewController {
            presented.dismiss(animated: false) { root.present(activityVC, animated: true) }
        } else {
            root.present(activityVC, animated: true)
        }
    }

    // MARK: - Persistence

    /// Loads excuse history from UserDefaults.
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "excuseHistory"),
              let saved = try? JSONDecoder().decode([Excuse].self, from: data) else { return }
        history = saved
    }

    /// Saves excuse history to UserDefaults.
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "excuseHistory")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
