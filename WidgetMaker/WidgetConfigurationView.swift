//
//  WidgetConfigurationView.swift
//  WidgetMaker
//

import PhotosUI
import SwiftUI
import WidgetKit

struct WidgetConfigurationView: View {
    @State private var portfolio = SharedDataStore.loadPortfolio()
    @State private var designName = ""
    @State private var configuration = SharedWidgetConfiguration.default
    @State private var backgroundColor = Color(hex: SharedWidgetConfiguration.default.backgroundColorHex) ?? .green
    @State private var textColor = Color(hex: SharedWidgetConfiguration.default.textColorHex) ?? .black
    @State private var selectedFont: WidgetFontOption = .system
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var pendingImageData: Data?
    @State private var pendingRemoveImage = false
    @State private var isLiveActivityActive = LiveActivityController.isActivityInProgress
    @State private var isSaving = false
    @State private var isImportingPhoto = false
    @State private var showHelp = false
    @State private var showSavedBanner = false
    @State private var alertMessage: AlertMessage?
    @State private var pendingNavigation: PendingNavigation?
    @State private var showDeleteConfirmation = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasSeenAssignDesignTip") private var hasSeenAssignDesignTip = false
    @State private var showOnboarding = false
    @State private var showAssignDesignTip = false

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

    /// True when the editor differs from the last saved selected design.
    private var hasUnsavedChanges: Bool {
        if pendingImageData != nil || pendingRemoveImage { return true }
        if designName != portfolio.selectedDesign.name { return true }
        return draftConfiguration != portfolio.selectedDesign.configuration
    }

    var body: some View {
        NavigationStack {
            Form {
                portfolioSection
                previewSection
                contentVisibilitySection
                textSection
                styleSection
                imageSection
                progressSection
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
                    .disabled(isSaving || isImportingPhoto || !hasUnsavedChanges)
                    .accessibilityHint(Text("Saves your design and refreshes Home Screen widgets"))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showSavedBanner {
                    savedBanner
                } else if showAssignDesignTip {
                    assignDesignTipBanner
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
            .alert(
                Text("Unsaved Changes"),
                isPresented: Binding(
                    get: { pendingNavigation != nil },
                    set: { if !$0 { pendingNavigation = nil } }
                )
            ) {
                Button("Save") {
                    if saveConfigurationAndReturnSuccess(), let pendingNavigation {
                        performPendingNavigation(pendingNavigation)
                    }
                    pendingNavigation = nil
                }
                Button("Discard", role: .destructive) {
                    if let pendingNavigation {
                        discardEditorChanges()
                        performPendingNavigation(pendingNavigation)
                    }
                    pendingNavigation = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingNavigation = nil
                }
            } message: {
                Text("Save your edits first, or discard them to continue.")
            }
            .confirmationDialog(
                Text("Delete Design"),
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Design", role: .destructive) {
                    deleteCurrentDesign()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This design will be removed from your portfolio. This can’t be undone.")
            }
            .onAppear {
                loadPortfolioIntoEditor()
                isLiveActivityActive = LiveActivityController.isActivityInProgress
                if !hasSeenOnboarding {
                    showOnboarding = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: DeepLink.openEditorNotification)) { _ in
                openEditorFromDeepLink()
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task { await importSelectedPhoto(newItem) }
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
            .onChange(of: designName) { _, newValue in
                if newValue.count > WidgetDesign.nameLimit {
                    designName = String(newValue.prefix(WidgetDesign.nameLimit))
                }
            }
        }
    }

    // MARK: - Sections

    private var portfolioSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(portfolio.designs) { design in
                        portfolioCard(design)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            TextField("Design Name", text: $designName)
                .textInputAutocapitalization(.words)
                .accessibilityLabel(Text("Design Name"))

            HStack(spacing: 12) {
                Button {
                    createDesign(copying: false)
                } label: {
                    Label("New Design", systemImage: "plus.square.on.square")
                }
                .disabled(portfolio.designs.count >= WidgetPortfolio.maxDesigns)

                Button {
                    createDesign(copying: true)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                .disabled(portfolio.designs.count >= WidgetPortfolio.maxDesigns)
            }

            if portfolio.designs.count > 1 {
                Button("Delete Design", role: .destructive) {
                    requestDeleteDesign()
                }
            }
        } header: {
            Text("Portfolio")
        } footer: {
            Text("Save multiple looks, then pick one when you add a Home Screen widget.")
        }
    }

    private func portfolioCard(_ design: WidgetDesign) -> some View {
        let isSelected = design.id == portfolio.selectedDesignID
        let thumb = design.id == portfolio.selectedDesignID ? previewImage : loadThumb(for: design)

        return Button {
            selectDesign(design.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                WidgetPreviewContent(
                    configuration: design.id == portfolio.selectedDesignID ? draftConfiguration : design.configuration,
                    backgroundImage: thumb,
                    isCompact: true
                )
                .frame(width: 108, height: 108)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                }

                Text(design.id == portfolio.selectedDesignID ? (designName.isEmpty ? design.displayName : designName) : design.displayName)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .frame(width: 108, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(design.displayName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var previewSection: some View {
        Section {
            HStack(spacing: 16) {
                WidgetPreviewContent(
                    configuration: draftConfiguration,
                    backgroundImage: previewImage,
                    isCompact: true
                )
                .frame(width: 155, height: 155)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Live Preview")
                            .font(.headline)
                        if hasUnsavedChanges {
                            Text("Unsaved")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.orange.opacity(0.18)))
                                .foregroundStyle(.orange)
                                .accessibilityLabel(Text("Unsaved changes"))
                        }
                    }
                    Text(hasUnsavedChanges
                         ? String(localized: "You have unsaved edits. Tap Save to update Home Screen widgets.")
                         : String(localized: "Changes appear here instantly. Tap Save to update your Home Screen widget."))
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

    private var showsText: Bool {
        configuration.showsTitle || configuration.showsSubtitle || configuration.showsEmoji
    }

    private var showsTextBinding: Binding<Bool> {
        Binding(
            get: { showsText },
            set: { enabled in
                configuration.showsTitle = enabled
                configuration.showsSubtitle = enabled
                configuration.showsEmoji = enabled
            }
        )
    }

    private var contentVisibilitySection: some View {
        Section {
            Toggle("Show Text", isOn: showsTextBinding)
            Toggle("Show Progress", isOn: $configuration.showsProgress)
            Toggle("Show Time", isOn: $configuration.showsTimestamp)
        } header: {
            Text("Content")
        } footer: {
            Text("Turn off Show Text for a photo- or color-only widget with nothing overlaid on top.")
        }
    }

    @ViewBuilder
    private var textSection: some View {
        if showsText {
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
                Text(L10n.titleSubtitleLimits(
                    titleLimit: SharedWidgetConfiguration.titleLimit,
                    subtitleLimit: SharedWidgetConfiguration.subtitleLimit
                ))
            }
        }
    }

    private var styleSection: some View {
        Section("Style") {
            ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)

            if showsText || configuration.showsProgress || configuration.showsTimestamp {
                ColorPicker("Text", selection: $textColor, supportsOpacity: false)

                Picker("Font", selection: $selectedFont) {
                    ForEach(WidgetFontOption.allCases) { option in
                        Text(option.localizedName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(Text("Font style"))

                if showsText {
                    Text("The quick brown fox")
                        .font(selectedFont.font(size: 17))
                        .foregroundStyle(textColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(Text("Font preview"))
                }
            }
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

    @ViewBuilder
    private var progressSection: some View {
        if configuration.showsProgress {
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
            } header: {
                Text("Progress")
            }
        }
    }

    private var liveActivitySection: some View {
        Section {
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
            .disabled(isSaving || isImportingPhoto || !hasUnsavedChanges)
        } footer: {
            Text("After saving, long-press a Home Screen widget and choose Edit Widget to pick a design from your portfolio.")
        }
    }

    private var savedBanner: some View {
        VStack(spacing: 4) {
            Text("Saved — Home Screen widgets refreshed")
                .font(.subheadline.weight(.medium))
            if !hasSeenAssignDesignTip {
                Text("Tip: long-press a widget → Edit Widget to choose a design.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var assignDesignTipBanner: some View {
        Text("Tip: long-press a widget → Edit Widget to choose a design.")
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onTapGesture {
                withAnimation {
                    showAssignDesignTip = false
                    hasSeenAssignDesignTip = true
                }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Dismiss tip"))
    }

    // MARK: - Portfolio actions

    private func selectDesign(_ id: String) {
        guard id != portfolio.selectedDesignID else { return }
        if hasUnsavedChanges {
            pendingNavigation = .select(id)
            return
        }
        performSelectDesign(id)
    }

    private func createDesign(copying: Bool) {
        if hasUnsavedChanges {
            pendingNavigation = .create(copying: copying)
            return
        }
        performCreateDesign(copying: copying)
    }

    private func requestDeleteDesign() {
        if hasUnsavedChanges {
            pendingNavigation = .delete
            return
        }
        showDeleteConfirmation = true
    }

    private func performPendingNavigation(_ pending: PendingNavigation) {
        switch pending {
        case .select(let id):
            performSelectDesign(id)
        case .create(let copying):
            performCreateDesign(copying: copying)
        case .delete:
            showDeleteConfirmation = true
        }
    }

    private func performSelectDesign(_ id: String) {
        portfolio.select(id)
        applySelectedDesignToEditor()
        clearPendingImageState()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func performCreateDesign(copying: Bool) {
        let created = copying ? portfolio.duplicateSelected() : portfolio.addDesign()
        guard created != nil else {
            alertMessage = AlertMessage(
                title: String(localized: "Portfolio Full"),
                message: L10n.portfolioFull
            )
            return
        }
        applySelectedDesignToEditor()
        clearPendingImageState()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func deleteCurrentDesign() {
        let removedImage = portfolio.selectedDesign.configuration.backgroundImageFileName
        guard portfolio.deleteSelected() else { return }
        if let removedImage,
           !portfolio.designs.contains(where: { $0.configuration.backgroundImageFileName == removedImage }) {
            SharedImageStore.deleteImage(fileName: removedImage)
        }
        applySelectedDesignToEditor()
        clearPendingImageState()
        _ = SharedDataStore.savePortfolio(portfolio)
        WidgetCenter.shared.reloadAllTimelines()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func discardEditorChanges() {
        applySelectedDesignToEditor()
        clearPendingImageState()
    }

    private func clearPendingImageState() {
        pendingImageData = nil
        pendingRemoveImage = false
        selectedPhotoItem = nil
    }

    private func applySelectedDesignToEditor() {
        let design = portfolio.selectedDesign
        designName = design.name
        configuration = design.configuration
        backgroundColor = Color(hex: design.configuration.backgroundColorHex) ?? .green
        textColor = Color(hex: design.configuration.textColorHex) ?? .black
        selectedFont = WidgetFontOption(rawValue: design.configuration.fontName) ?? .system
        if let fileName = design.configuration.backgroundImageFileName,
           let data = SharedImageStore.loadImageData(fileName: fileName),
           let image = UIImage(data: data) {
            previewImage = image
        } else {
            previewImage = nil
        }
    }

    private func loadThumb(for design: WidgetDesign) -> UIImage? {
        guard
            let fileName = design.configuration.backgroundImageFileName,
            let data = SharedImageStore.loadImageData(fileName: fileName)
        else {
            return nil
        }
        return UIImage(data: data)
    }

    // MARK: - Persistence

    private func openEditorFromDeepLink() {
        hasSeenOnboarding = true
        showOnboarding = false
        showHelp = false
        isLiveActivityActive = LiveActivityController.isActivityInProgress
        loadPortfolioIntoEditor()
    }

    private func loadPortfolioIntoEditor() {
        portfolio = SharedDataStore.loadPortfolio()
        applySelectedDesignToEditor()
        clearPendingImageState()
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
        let previousFileName = portfolio.selectedDesign.configuration.backgroundImageFileName

        if pendingRemoveImage {
            if let previousFileName,
               !portfolio.designs.contains(where: {
                   $0.id != portfolio.selectedDesignID && $0.configuration.backgroundImageFileName == previousFileName
               }) {
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
                if let previousFileName,
                   previousFileName != fileName,
                   !portfolio.designs.contains(where: {
                       $0.id != portfolio.selectedDesignID && $0.configuration.backgroundImageFileName == previousFileName
                   }) {
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
        _ = saveConfigurationAndReturnSuccess()
    }

    @discardableResult
    private func saveConfigurationAndReturnSuccess() -> Bool {
        isSaving = true
        defer { isSaving = false }

        var draft = draftConfiguration
        guard commitPendingImageChanges(into: &draft) else { return false }

        configuration = draft
        portfolio.updateSelected(draft, name: designName)

        guard SharedDataStore.savePortfolio(portfolio) else {
            alertMessage = AlertMessage(
                title: String(localized: "Couldn't Save"),
                message: L10n.sharedStorageUnavailable
            )
            return false
        }

        portfolio = SharedDataStore.loadPortfolio()
        applySelectedDesignToEditor()
        clearPendingImageState()

        WidgetCenter.shared.reloadAllTimelines()

        if isLiveActivityActive {
            Task {
                await LiveActivityController.update(from: draft)
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation(.easeOut(duration: 0.25)) {
            showAssignDesignTip = false
            showSavedBanner = true
        }
        Task {
            try? await Task.sleep(for: .seconds(hasSeenAssignDesignTip ? 2.2 : 3.4))
            withAnimation(.easeIn(duration: 0.2)) {
                showSavedBanner = false
            }
            if !hasSeenAssignDesignTip {
                hasSeenAssignDesignTip = true
            }
        }
        return true
    }

    private func persistDraftForLiveActivity() -> SharedWidgetConfiguration? {
        var draft = draftConfiguration
        guard commitPendingImageChanges(into: &draft) else { return nil }
        configuration = draft
        portfolio.updateSelected(draft, name: designName)
        guard SharedDataStore.savePortfolio(portfolio) else {
            alertMessage = AlertMessage(
                title: String(localized: "Couldn't Save"),
                message: L10n.sharedStorageUnavailable
            )
            return nil
        }
        portfolio = SharedDataStore.loadPortfolio()
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

private enum PendingNavigation: Equatable {
    case select(String)
    case create(copying: Bool)
    case delete
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
                        icon: "square.stack.3d.up.fill",
                        title: String(localized: "Build a portfolio"),
                        detail: String(localized: "Save many looks and pick one for each Home Screen widget.")
                    )
                    onboardingRow(
                        icon: "paintbrush.fill",
                        title: String(localized: "Customize"),
                        detail: String(localized: "Pick colors, fonts, emoji, and a photo background.")
                    )
                    onboardingRow(
                        icon: "switch.2",
                        title: String(localized: "Keep it minimal"),
                        detail: String(localized: "Hide title, subtitle, emoji, progress, or time anytime.")
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
                    labeledStep(number: 1, text: String(localized: "Create designs in your portfolio, then tap Save."))
                    labeledStep(number: 2, text: String(localized: "On your Home Screen, touch and hold an empty area until the apps jiggle."))
                    labeledStep(number: 3, text: String(localized: "Tap Edit in the corner, then Add Widget."))
                    labeledStep(number: 4, text: String(localized: "Search for “Buggy Widget”, choose Small or Medium, and tap Add."))
                    labeledStep(number: 5, text: String(localized: "Long-press the widget, tap Edit Widget, and pick a design from your portfolio."))
                } header: {
                    Text("Home Screen widget")
                }

                Section {
                    Text("Use Start Live Activity to show your current design on Dynamic Island and the Lock Screen.")
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
