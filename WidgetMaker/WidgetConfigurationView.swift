//
//  WidgetConfigurationView.swift
//  WidgetMaker
//

import PhotosUI
import SwiftUI
import WidgetKit

struct WidgetConfigurationView: View {
    @State private var configuration = SharedDataStore.load() ?? .default
    @State private var backgroundColor = Color(hex: SharedWidgetConfiguration.default.backgroundColorHex) ?? .green
    @State private var textColor = Color(hex: SharedWidgetConfiguration.default.textColorHex) ?? .black
    @State private var selectedFont: WidgetFontOption = .system
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isLiveActivityActive = LiveActivityController.isActivityInProgress
    @State private var isSaving = false
    @State private var isImportingPhoto = false
    @State private var showHelp = false
    @State private var showSavedBanner = false
    @State private var alertMessage: AlertMessage?
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    private var draftConfiguration: SharedWidgetConfiguration {
        var draft = configuration
        draft.backgroundColorHex = backgroundColor.toHex()
        draft.textColorHex = textColor.toHex()
        draft.fontName = selectedFont.rawValue
        draft.sanitize()
        return draft
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                textSection
                styleSection
                imageSection
                liveActivitySection
                homeScreenSection
            }
            .navigationTitle("Buggy Widget")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHelp = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .accessibilityLabel("How to use")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveConfiguration()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || isImportingPhoto)
                    .accessibilityHint("Saves your design and refreshes Home Screen widgets")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showSavedBanner {
                    savedBanner
                }
            }
            .sheet(isPresented: $showHelp) {
                HelpSheet()
            }
            .sheet(isPresented: $showOnboarding) {
                OnboardingSheet {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
            }
            .alert(item: $alertMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                loadExistingConfiguration()
                isLiveActivityActive = LiveActivityController.isActivityInProgress
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await importSelectedPhoto(newItem)
                }
            }
            .onChange(of: configuration.title) { _, newValue in
                if newValue.count > SharedWidgetConfiguration.titleLimit {
                    configuration.title = String(newValue.prefix(SharedWidgetConfiguration.titleLimit))
                }
            }
            .onChange(of: configuration.subtitle) { _, newValue in
                if newValue.count > SharedWidgetConfiguration.subtitleLimit {
                    configuration.subtitle = String(newValue.prefix(SharedWidgetConfiguration.subtitleLimit))
                }
            }
            .onChange(of: configuration.emoji) { _, newValue in
                if newValue.count > SharedWidgetConfiguration.emojiLimit {
                    configuration.emoji = String(newValue.prefix(SharedWidgetConfiguration.emojiLimit))
                }
            }
        }
    }

    private var previewSection: some View {
        Section {
            HStack(spacing: 16) {
                WidgetPreviewContent(
                    configuration: draftConfiguration,
                    backgroundImage: previewImage,
                    showsTimestamp: true,
                    isCompact: true
                )
                .frame(width: 155, height: 155)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Preview")
                        .font(.headline)
                    Text("Changes appear here instantly. Tap Save to update your Home Screen widget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private var textSection: some View {
        Section {
            TextField("Title", text: $configuration.title)
                .textInputAutocapitalization(.sentences)
                .accessibilityLabel("Widget title")

            TextField("Subtitle", text: $configuration.subtitle)
                .textInputAutocapitalization(.sentences)
                .accessibilityLabel("Widget subtitle")

            TextField("Emoji", text: $configuration.emoji)
                .accessibilityLabel("Widget emoji")
                .accessibilityHint("Paste or type an emoji")
        } header: {
            Text("Text")
        } footer: {
            Text("Title up to \(SharedWidgetConfiguration.titleLimit) characters. Subtitle up to \(SharedWidgetConfiguration.subtitleLimit).")
        }
    }

    private var styleSection: some View {
        Section("Style") {
            ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
            ColorPicker("Text", selection: $textColor, supportsOpacity: false)

            Picker("Font", selection: $selectedFont) {
                ForEach(WidgetFontOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Font style")

            Text("The quick brown fox")
                .font(selectedFont.font(size: 17))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Font preview")
        }
    }

    private var imageSection: some View {
        Section {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel("Selected background image")
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Label(
                        configuration.backgroundImageFileName == nil ? "Choose Image" : "Replace Image",
                        systemImage: "photo.on.rectangle"
                    )
                    Spacer()
                    if isImportingPhoto {
                        ProgressView()
                    }
                }
            }
            .disabled(isImportingPhoto)

            if configuration.backgroundImageFileName != nil {
                Button("Remove Image", role: .destructive) {
                    removeBackgroundImage()
                }
            }
        } header: {
            Text("Background Image")
        } footer: {
            Text("Photos are resized for widgets and stored only on your device.")
        }
    }

    private var liveActivitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text("\(Int(configuration.progress * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $configuration.progress, in: 0...1, step: 0.01)
                    .accessibilityLabel("Live Activity progress")
                    .accessibilityValue("\(Int(configuration.progress * 100)) percent")
            }

            Text(isLiveActivityActive
                 ? "Dynamic Island and Lock Screen are showing your widget."
                 : "Mirror your design on Dynamic Island and the Lock Screen.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if isLiveActivityActive {
                Button("Update Live Activity") {
                    Task { await updateLiveActivity() }
                }
                Button("End Live Activity", role: .destructive) {
                    Task { await endLiveActivity() }
                }
            } else {
                Button("Start Live Activity") {
                    Task { await startLiveActivity() }
                }
            }
        } header: {
            Text("Live Activity")
        }
    }

    private var homeScreenSection: some View {
        Section {
            Button {
                showHelp = true
            } label: {
                Label("How to add to Home Screen", systemImage: "plus.rectangle.on.rectangle")
            }

            Button {
                saveConfiguration()
            } label: {
                Label("Save & Refresh Widgets", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(isSaving || isImportingPhoto)
        } footer: {
            Text("After saving, your Home Screen widget updates automatically.")
        }
    }

    private var savedBanner: some View {
        Text("Saved — Home Screen widgets refreshed")
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.updatesFrequently)
    }

    private func loadExistingConfiguration() {
        guard let saved = SharedDataStore.load() else { return }
        configuration = saved
        backgroundColor = Color(hex: saved.backgroundColorHex) ?? .green
        textColor = Color(hex: saved.textColorHex) ?? .black
        selectedFont = WidgetFontOption(rawValue: saved.fontName) ?? .system

        if let fileName = saved.backgroundImageFileName,
           let data = SharedImageStore.loadImageData(fileName: fileName),
           let image = UIImage(data: data) {
            previewImage = image
        }
    }

    private func importSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isImportingPhoto = true
        defer { isImportingPhoto = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            alertMessage = AlertMessage(
                title: "Couldn't Load Photo",
                message: "Try choosing a different image from your library."
            )
            return
        }

        if let oldFileName = configuration.backgroundImageFileName {
            SharedImageStore.deleteImage(fileName: oldFileName)
        }

        do {
            let fileName = try SharedImageStore.saveImageData(data)
            configuration.backgroundImageFileName = fileName
            if let stored = SharedImageStore.loadImageData(fileName: fileName) {
                previewImage = UIImage(data: stored)
            } else {
                previewImage = UIImage(data: data)
            }
        } catch {
            alertMessage = AlertMessage(
                title: "Couldn't Save Photo",
                message: error.localizedDescription
            )
        }
    }

    private func removeBackgroundImage() {
        if let fileName = configuration.backgroundImageFileName {
            SharedImageStore.deleteImage(fileName: fileName)
        }
        configuration.backgroundImageFileName = nil
        previewImage = nil
        selectedPhotoItem = nil
    }

    private func saveConfiguration() {
        isSaving = true
        defer { isSaving = false }

        let draft = draftConfiguration
        configuration = draft

        guard SharedDataStore.save(draft) else {
            alertMessage = AlertMessage(
                title: "Couldn't Save",
                message: "Shared storage is unavailable. Make sure App Groups are enabled for this app."
            )
            return
        }

        WidgetCenter.shared.reloadAllTimelines()

        if isLiveActivityActive {
            Task {
                await LiveActivityController.update(from: draft)
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.25)) {
            showSavedBanner = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeIn(duration: 0.2)) {
                showSavedBanner = false
            }
        }
    }

    private func startLiveActivity() async {
        let draft = draftConfiguration
        configuration = draft
        _ = SharedDataStore.save(draft)

        do {
            _ = try await LiveActivityController.start(from: draft)
            isLiveActivityActive = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            alertMessage = AlertMessage(
                title: "Couldn't Start Live Activity",
                message: error.localizedDescription
            )
        }
    }

    private func updateLiveActivity() async {
        let draft = draftConfiguration
        configuration = draft
        _ = SharedDataStore.save(draft)

        await LiveActivityController.update(from: draft)
        isLiveActivityActive = LiveActivityController.isActivityInProgress
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func endLiveActivity() async {
        await LiveActivityController.endAll()
        isLiveActivityActive = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

private struct AlertMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct OnboardingSheet: View {
    let onContinue: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 8)

                Text("🐛")
                    .font(.system(size: 56))
                    .frame(maxWidth: .infinity)

                Text("Design once. See it everywhere.")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 16) {
                    onboardingRow(
                        icon: "paintbrush.fill",
                        title: "Customize",
                        detail: "Pick colors, fonts, emoji, and a photo background."
                    )
                    onboardingRow(
                        icon: "square.grid.2x2.fill",
                        title: "Add the widget",
                        detail: "Long-press your Home Screen, tap Edit, then Add Widget."
                    )
                    onboardingRow(
                        icon: "lock.iphone",
                        title: "Dynamic Island",
                        detail: "Start a Live Activity anytime to pin your design to the Lock Screen."
                    )
                }

                Spacer()

                Button(action: onContinue) {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onContinue)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func onboardingRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Home Screen widget") {
                    labeledStep(number: 1, text: "Customize your design in this app, then tap Save.")
                    labeledStep(number: 2, text: "On your Home Screen, touch and hold an empty area until the apps jiggle.")
                    labeledStep(number: 3, text: "Tap Edit in the corner, then Add Widget.")
                    labeledStep(number: 4, text: "Search for “Buggy Widget”, choose Small or Medium, and tap Add.")
                }

                Section("Live Activity") {
                    Text("Use Start Live Activity to show your design on Dynamic Island and the Lock Screen. Update anytime after you change progress or text.")
                }

                Section("Privacy") {
                    Text("Your photos and widget settings stay on this device in a private App Group container. Nothing is uploaded.")
                }
            }
            .navigationTitle("How to Use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func labeledStep(number: Int, text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Step \(number). \(text)")
    }
}

#Preview {
    WidgetConfigurationView()
}
