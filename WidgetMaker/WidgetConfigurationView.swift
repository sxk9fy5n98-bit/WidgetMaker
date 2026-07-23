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
    /// Image bytes chosen in the editor but not yet written on Save.
    @State private var pendingImageData: Data?
    /// When true, Save will clear the persisted background image.
    @State private var pendingRemoveImage = false
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
        if pendingRemoveImage {
            draft.backgroundImageFileName = nil
        }
        draft.sanitize()
        return draft
    }

    private var hasBackgroundImageInDraft: Bool {
        if pendingRemoveImage { return false }
        if pendingImageData != nil || previewImage != nil { return true }
        return configuration.backgroundImageFileName != nil
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
                    .accessibilityLabel(Text("How to use"))
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
                    .accessibilityHint(Text("Saves your design and refreshes Home Screen widgets"))
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
            .onReceive(NotificationCenter.default.publisher(for: DeepLink.openEditorNotification)) { _ in
                openEditorFromDeepLink()
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
                    showsProgress: true,
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
                .accessibilityLabel(Text("Widget title"))

            TextField("Subtitle", text: $configuration.subtitle)
                .textInputAutocapitalization(.sentences)
                .accessibilityLabel(Text("Widget subtitle"))

            TextField("Emoji", text: $configuration.emoji)
                .accessibilityLabel(Text("Widget emoji"))
                .accessibilityHint(Text("Paste or type an emoji"))
        } header: {
            Text("Text")
        } footer: {
            Text(L10n.titleSubtitleLimits(titleLimit: SharedWidgetConfiguration.titleLimit, subtitleLimit: SharedWidgetConfiguration.subtitleLimit))
        }
    }

    private var styleSection: some View {
        Section("Style") {
            ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
            ColorPicker("Text", selection: $textColor, supportsOpacity: false)

            Picker("Font", selection: $selectedFont) {
                ForEach(WidgetFontOption.allCases) { option in
                    Text(option.localizedName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(Text("Font style"))

            Text("The quick brown fox")
                .font(selectedFont.font(size: 17))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text("Font preview"))
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
                    .accessibilityLabel(Text("Selected background image"))
            }

            PhotosPicker(
                selection: $selectedPhotoItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack {
                    Label {
                        Text(hasBackgroundImageInDraft ? "Replace Image" : "Choose Image")
                    } icon: {
                        Image(systemName: "photo.on.rectangle")
                    }
                    Spacer()
                    if isImportingPhoto {
                        ProgressView()
                    }
                }
            }
            .disabled(isImportingPhoto)

            if hasBackgroundImageInDraft {
                Button("Remove Image", role: .destructive) {
                    removeBackgroundImage()
                }
            }
        } header: {
            Text("Background Image")
        } footer: {
            Text("Photos stay on your device. Tap Save to apply image changes to your Home Screen widget.")
        }
    }

    private var liveActivitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text(LocaleFormatting.percent(configuration.progress))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $configuration.progress, in: 0...1, step: 0.01)
                    .accessibilityLabel(Text("Widget progress"))
                    .accessibilityValue(L10n.accessibilityPercent(configuration.progress))
            }

            Text(isLiveActivityActive
                 ? String(localized: "Dynamic Island and Lock Screen are showing your widget.")
                 : String(localized: "Mirror your design on Dynamic Island and the Lock Screen."))
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

    private func openEditorFromDeepLink() {
        hasSeenOnboarding = true
        showOnboarding = false
        showHelp = false
        isLiveActivityActive = LiveActivityController.isActivityInProgress
        loadExistingConfiguration()
    }

    private func loadExistingConfiguration() {
        guard let saved = SharedDataStore.load() else { return }
        configuration = saved
        backgroundColor = Color(hex: saved.backgroundColorHex) ?? .green
        textColor = Color(hex: saved.textColorHex) ?? .black
        selectedFont = WidgetFontOption(rawValue: saved.fontName) ?? .system
        pendingImageData = nil
        pendingRemoveImage = false
        selectedPhotoItem = nil

        if let fileName = saved.backgroundImageFileName,
           let data = SharedImageStore.loadImageData(fileName: fileName),
           let image = UIImage(data: data) {
            previewImage = image
        } else {
            previewImage = nil
        }
    }

    private func importSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        isImportingPhoto = true
        defer { isImportingPhoto = false }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            alertMessage = AlertMessage(
                title: String(localized: "Couldn't Load Photo"),
                message: String(localized: "Try choosing a different image from your library.")
            )
            return
        }

        // Keep the photo in memory until Save so quitting without Save leaves disk untouched.
        pendingImageData = data
        pendingRemoveImage = false
        previewImage = UIImage(data: data)
    }

    private func removeBackgroundImage() {
        pendingImageData = nil
        pendingRemoveImage = true
        previewImage = nil
        selectedPhotoItem = nil
    }

    private func commitPendingImageChanges(into draft: inout SharedWidgetConfiguration) -> Bool {
        let previousFileName = SharedDataStore.load()?.backgroundImageFileName

        if pendingRemoveImage {
            if let previousFileName {
                SharedImageStore.deleteImage(fileName: previousFileName)
            }
            draft.backgroundImageFileName = nil
            pendingRemoveImage = false
            pendingImageData = nil
            return true
        }

        if let pendingImageData {
            do {
                let fileName = try SharedImageStore.saveImageData(pendingImageData)
                if let previousFileName, previousFileName != fileName {
                    SharedImageStore.deleteImage(fileName: previousFileName)
                }
                draft.backgroundImageFileName = fileName
                if let stored = SharedImageStore.loadImageData(fileName: fileName) {
                    previewImage = UIImage(data: stored)
                }
                self.pendingImageData = nil
                return true
            } catch {
                alertMessage = AlertMessage(
                    title: String(localized: "Couldn't Save Photo"),
                    message: error.localizedDescription
                )
                return false
            }
        }

        return true
    }

    private func saveConfiguration() {
        isSaving = true
        defer { isSaving = false }

        var draft = draftConfiguration
        guard commitPendingImageChanges(into: &draft) else { return }

        configuration = draft

        guard SharedDataStore.save(draft) else {
            alertMessage = AlertMessage(
                title: String(localized: "Couldn't Save"),
                message: L10n.sharedStorageUnavailable
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

    private func persistDraftForLiveActivity() -> SharedWidgetConfiguration? {
        var draft = draftConfiguration
        guard commitPendingImageChanges(into: &draft) else { return nil }
        configuration = draft
        guard SharedDataStore.save(draft) else {
            alertMessage = AlertMessage(
                title: String(localized: "Couldn't Save"),
                message: L10n.sharedStorageUnavailable
            )
            return nil
        }
        return draft
    }

    private func startLiveActivity() async {
        guard let draft = persistDraftForLiveActivity() else { return }

        do {
            _ = try await LiveActivityController.start(from: draft)
            isLiveActivityActive = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            alertMessage = AlertMessage(
                title: String(localized: "Couldn't Start Live Activity"),
                message: error.localizedDescription
            )
        }
    }

    private func updateLiveActivity() async {
        guard let draft = persistDraftForLiveActivity() else { return }

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
                        title: String(localized: "Customize"),
                        detail: String(localized: "Pick colors, fonts, emoji, and a photo background.")
                    )
                    onboardingRow(
                        icon: "square.grid.2x2.fill",
                        title: String(localized: "Add the widget"),
                        detail: String(localized: "Long-press your Home Screen, tap Edit, then Add Widget.")
                    )
                    onboardingRow(
                        icon: "lock.iphone",
                        title: String(localized: "Dynamic Island"),
                        detail: String(localized: "Start a Live Activity anytime to pin your design to the Lock Screen.")
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
                Section {
                    labeledStep(number: 1, text: String(localized: "Customize your design in this app, then tap Save."))
                    labeledStep(number: 2, text: String(localized: "On your Home Screen, touch and hold an empty area until the apps jiggle."))
                    labeledStep(number: 3, text: String(localized: "Tap Edit in the corner, then Add Widget."))
                    labeledStep(number: 4, text: String(localized: "Search for “Buggy Widget”, choose Small or Medium, and tap Add."))
                } header: {
                    Text("Home Screen widget")
                }

                Section {
                    Text("Use Start Live Activity to show your design on Dynamic Island and the Lock Screen. Update anytime after you change progress or text.")
                } header: {
                    Text("Live Activity")
                }

                Section {
                    Text("Your photos and widget settings stay on this device in a private App Group container. Nothing is uploaded.")
                } header: {
                    Text("Privacy")
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
        .accessibilityLabel(L10n.accessibilityStep(number: number, text: text))
    }
}

#Preview {
    WidgetConfigurationView()
}
