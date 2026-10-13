import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ModelCatalog

// Only Lab Voice's own preference domain is written.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }
}

actor CatalogWorker {
    func installed(app: URL?, downloaded: URL?) throws -> [ModelAssessment] {
        try ModelCatalog.discoverInstalled(appBundle: app, downloadedModels: downloaded)
    }
    func independent(root: URL, manifest: String) throws -> [ModelAssessment] {
        let provider = try ModelCatalog.loadIndependentManifest(root: root, relativeFile: manifest)
        return try ModelCatalog.validate(provider, root: root)
    }
}

@MainActor final class CatalogModel: ObservableObject {
    @Published var appBundle: URL?
    @Published var downloaded: URL?
    @Published var independentRoot: URL?
    @Published var manifest: String?
    @Published var busy = false
    @Published var error: String?
    @Published var assessments: [ModelAssessment] = []
    @Published var resultSource = ""
    private let worker = CatalogWorker()
    func clearResults() { assessments = []; resultSource = ""; error = nil }
    func validateInstalled() async {
        guard !busy, appBundle != nil || downloaded != nil else { return }
        busy = true; clearResults(); defer { busy = false }
        do {
            assessments = try await worker.installed(app: appBundle, downloaded: downloaded)
            resultSource = "Installed-provider validation"
        } catch { self.error = "Cannot validate selected locations: \(error)" }
    }
    func validateIndependent() async {
        guard !busy, let root = independentRoot, let manifest else { return }
        busy = true; clearResults(); defer { busy = false }
        do {
            assessments = try await worker.independent(root: root, manifest: manifest)
            resultSource = "Independent-provider validation"
        } catch { self.error = "Cannot validate independent manifest: \(error)" }
    }
    func selectIndependentRoot(_ root: URL) { independentRoot = root; manifest = nil; clearResults() }
    func selectManifest(_ file: URL) {
        guard let root = independentRoot else { return }
        let rootPath = root.standardizedFileURL.path
        let prefix = rootPath == "/" ? "/" : rootPath + "/"
        let path = file.standardizedFileURL.path
        guard path.hasPrefix(prefix) else {
            error = "Choose a manifest inside the selected model directory."
            return
        }
        manifest = String(path.dropFirst(prefix.count)); clearResults()
    }
}

struct AppSettingsView: View {
    @ObservedObject var catalog: CatalogModel
    @ObservedObject private var widget = FloatingWidgetController.shared
    var showDone = false
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @Environment(\.dismiss) private var dismiss
    private func chooseDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
    private func chooseInstalledApp() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false; panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
    private func chooseManifest() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.directoryURL = catalog.independentRoot
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { catalog.selectManifest(url) }
    }
    private func status(_ state: AssetIntegrity) -> String {
        switch state {
        case .verified: return "SHA256 verified"
        case .hashUnverified: return "Detected; reference hash unknown"
        case .hashMismatch: return "SHA256 mismatch"
        case .missing: return "Missing"
        case .invalidPath: return "Invalid path or digest"
        case .unreadable: return "Unreadable or blocked path"
        case .notRegularFile: return "Not a regular file"
        case .changedDuringRead: return "File changed during validation"
        }
    }
    private func selectedPath(_ url: URL?) -> some View {
        Text(url?.path ?? "No location selected")
            .font(.caption).foregroundColor(.secondary).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings").font(.title2)
                Spacer()
                if showDone { Button("Done") { dismiss() } }
            }
            TabView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("App").font(.headline)
                    Text("Appearance")
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { option in Text(option.title).tag(option) }
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 300)
                    Text("System follows this Mac's appearance. Your choice is saved for Lab Voice.")
                        .font(.caption).foregroundColor(.secondary)
                    Toggle("Show widget", isOn: Binding(get: { widget.isVisible }, set: widget.setVisible))
                    Text("A floating panel shows this app's audio and recording state. Closing it hides the panel; audio continues until Stop.")
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20).tabItem { Text("App") }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Local model assets").font(.headline)
                    Text("Validation only. Inference backend unavailable. No model is enabled for processing.")
                        .foregroundColor(.secondary)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Installed provider").font(.headline)
                            HStack {
                                Button("Choose installed app…") {
                                    if let url = chooseInstalledApp() { catalog.appBundle = url; catalog.clearResults() }
                                }
                                Button("Choose downloaded-model directory…") {
                                    if let url = chooseDirectory() { catalog.downloaded = url; catalog.clearResults() }
                                }
                                Button("Clear") { catalog.appBundle = nil; catalog.downloaded = nil; catalog.clearResults() }
                            }.disabled(catalog.busy)
                            selectedPath(catalog.appBundle)
                            selectedPath(catalog.downloaded)
                            Text("Checks expected filenames in the selected app and dedicated models folder. Assets are read for hashing and are never copied or decoded.")
                                .font(.caption).foregroundColor(.secondary)
                            Button("Validate installed assets") { Task { await catalog.validateInstalled() } }
                                .disabled(catalog.busy || (catalog.appBundle == nil && catalog.downloaded == nil))
                            Divider()
                            Text("Independent provider").font(.headline)
                            HStack {
                                Button("Choose model directory…") {
                                    if let root = chooseDirectory() { catalog.selectIndependentRoot(root) }
                                }
                                Button("Choose manifest…") { chooseManifest() }
                                    .disabled(catalog.independentRoot == nil)
                                Button("Clear") { catalog.independentRoot = nil; catalog.manifest = nil; catalog.clearResults() }
                            }.disabled(catalog.busy)
                            selectedPath(catalog.independentRoot)
                            Text(catalog.manifest ?? "No manifest selected").font(.caption).foregroundColor(.secondary)
                            Text("The manifest must be inside the selected directory and declare model IDs, features, relative files, SHA256 digests, and license metadata.")
                                .font(.caption).foregroundColor(.secondary)
                            Button("Validate independent assets") { Task { await catalog.validateIndependent() } }
                                .disabled(catalog.busy || catalog.manifest == nil)
                            if catalog.busy {
                                HStack { ProgressView().controlSize(.small); Text("Reading and hashing selected assets…") }
                            }
                            if let error = catalog.error { Text(error).foregroundColor(.red).textSelection(.enabled) }
                            if !catalog.resultSource.isEmpty {
                                Divider()
                                Text(catalog.resultSource).font(.headline)
                                Text("\(catalog.assessments.filter { $0.detected }.count) detected across \(catalog.assessments.count) expected-location checks. Inference unavailable.")
                                ForEach(Array(catalog.assessments.enumerated()), id: \.offset) { _, report in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(report.asset.id).font(.headline)
                                        Text("\(report.location) · \(status(report.integrity))")
                                        Text("Feature: " + report.asset.feature).font(.caption)
                                        Text(report.asset.localFile).font(.caption).textSelection(.enabled)
                                        if let digest = report.observedSHA256 {
                                            Text("SHA256: " + digest).font(.caption.monospaced()).textSelection(.enabled)
                                        }
                                        Text(report.unknownLicense ? "License or redistribution rights unknown" :
                                            "Manifest license: \(report.asset.license.identifier ?? "") · Redistribution: \(report.asset.license.redistribution.rawValue)")
                                            .font(.caption).foregroundColor(.secondary)
                                        Text("Backend unavailable").font(.caption).foregroundColor(.secondary)
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
                                        .background(Color.secondary.opacity(0.07)).cornerRadius(6)
                                }
                                Text("License metadata is a manifest declaration. It does not establish permission to distribute weights.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                    }
                }.padding(12).tabItem { Text("Models") }
            }
        }.padding(16).frame(width: 720, height: 620)
        .preferredColorScheme(appearance.colorScheme)
    }
}
