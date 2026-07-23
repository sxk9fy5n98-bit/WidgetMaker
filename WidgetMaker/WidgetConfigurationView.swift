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
    @State private var backgroundColor = Color(hex: SharedWidgetConfiguration.default.backgroundColorHex) ?? .indigo
    @State private var textColor = Color(hex: SharedWidgetConfiguration.default.textColorHex) ?? .white
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

    private static let backgroundPresets = ["#5E5CE6", "#0A84FF", "#34C759", "#FF9F0A", "#FF375F", "#1C1C1E"]
    private static let textPresets = ["#FFFFFF", "#000000"]

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
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    portfolioCardSection
                    contentCard
                    if showsText {
                        textCard
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }
                    styleCard
                    imageCard
                    if configuration.showsProgress {
                        progressCard
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }
                    liveActivityCard
                    helpCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showsText)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: configuration.showsProgress)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
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
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
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

    // MARK: - Hero

    private var heroCard: some View {
        VStack(spacing: 16) {
            WidgetPreviewContent(
                configuration: draftConfiguration,
                backgroundImage: previewImage,
                isCompact: true
            )
            .frame(width: 170, height: 170)
            .shadow(color: backgroundColor.opacity(0.35), radius: 18, y: 10)

            VStack(spacing: 8) {
                TextField("Design Name", text: $designName)
                    .textInputAutocapitalization(.words)
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 18)
                    .background(Capsule().fill(Color(.secondarySystemGroupedBackground).opacity(0.9)))
                    .frame(maxWidth: 250)
                    .accessibilityLabel(Text("Design Name"))

                if hasUnsavedChanges {
                    Text("Unsaved")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundStyle(.orange)
                        .accessibilityLabel(Text("Unsaved changes"))
                        .transition(.opacity)
                } else {
                    Text("Changes appear here instantly. Tap Save to update your Home Screen widget.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [backgroundColor.opacity(0.30), backgroundColor.opacity(0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: hasUnsavedChanges)
    }

    // MARK: - Portfolio

    private var portfolioCardSection: some View {
        sectionCard {
            HStack(spacing: 10) {
                IconBadge(systemName: "square.stack.3d.up.fill")
                Text("Portfolio")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Text(verbatim: "\(portfolio.designs.count)/\(WidgetPortfolio.maxDesigns)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()

                Menu {
                    Button {
                        createDesign(copying: true)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .disabled(portfolio.designs.count >= WidgetPortfolio.maxDesigns)

                    if portfolio.designs.count > 1 {
                        Button(role: .destructive) {
                            requestDeleteDesign()
                        } label: {
                            Label("Delete Design", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.tint)
                }
                .accessibilityLabel(Text("Design actions"))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(portfolio.designs) { design in
                        portfolioCard(design)
                    }
                    newDesignCard
                }
                .padding(6)
            }
            .padding(-6)

            Text("Save multiple looks, then pick one when you add a Home Screen widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func portfolioCard(_ design: WidgetDesign) -> some View {
        let isSelected = design.id == portfolio.selectedDesignID
        let thumb = isSelected ? previewImage : loadThumb(for: design)
        let miniature = WidgetPreviewContent(
            configuration: isSelected ? draftConfiguration : design.configuration,
            backgroundImage: thumb,
            isCompact: true
        )
        // Render at full widget size and scale down for a faithful miniature.
        .frame(width: 155, height: 155)
        .scaleEffect(92 / 155)
        .frame(width: 92, height: 92)

        return Button {
            selectDesign(design.id)
        } label: {
            VStack(spacing: 7) {
                miniature
                    .overlay {
                        if isSelected {
                            // Ring sits outside the thumb with a gap, so it reads on any color.
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                .padding(-5)
                        }
                    }

                Text(isSelected ? (designName.isEmpty ? design.displayName : designName) : design.displayName)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .lineLimit(1)
                    .frame(width: 92)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isSelected {
                Button {
                    createDesign(copying: true)
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }
                if portfolio.designs.count > 1 {
                    Button(role: .destructive) {
                        requestDeleteDesign()
                    } label: {
                        Label("Delete Design", systemImage: "trash")
                    }
                }
            }
        }
        .accessibilityLabel(Text(design.displayName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var newDesignCard: some View {
        Button {
            createDesign(copying: false)
        } label: {
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(.tertiary)
                    .frame(width: 92, height: 92)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tint)
                    }

                Text("New Design")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 92)
            }
        }
        .buttonStyle(.plain)
        .disabled(portfolio.designs.count >= WidgetPortfolio.maxDesigns)
        .opacity(portfolio.designs.count >= WidgetPortfolio.maxDesigns ? 0.4 : 1)
    }

    // MARK: - Content

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

    private var contentCard: some View {
        sectionCard {
            cardHeader(Text("Content"), systemImage: "switch.2")

            toggleRow(Text("Show Text"), icon: "textformat", isOn: showsTextBinding)
            Divider()
            toggleRow(Text("Show Progress"), icon: "chart.bar.fill", isOn: $configuration.showsProgress)
            Divider()
            toggleRow(Text("Show Time"), icon: "clock.fill", isOn: $configuration.showsTimestamp)

            Text("Turn off Show Text for a photo- or color-only widget with nothing overlaid on top.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleRow(_ title: Text, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 22)
                title
            }
        }
    }

    // MARK: - Text

    private var textCard: some View {
        sectionCard {
            cardHeader(Text("Text"), systemImage: "character.cursor.ibeam")

            fieldRow {
                TextField("Title", text: $configuration.title)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel(Text("Widget title"))
            }

            fieldRow {
                TextField("Subtitle", text: $configuration.subtitle)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel(Text("Widget subtitle"))
            }

            fieldRow {
                TextField("Emoji", text: $configuration.emoji)
                    .accessibilityLabel(Text("Widget emoji"))
                    .accessibilityHint(Text("Paste or type an emoji"))
            }

            Text(L10n.titleSubtitleLimits(
                titleLimit: SharedWidgetConfiguration.titleLimit,
                subtitleLimit: SharedWidgetConfiguration.subtitleLimit
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func fieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
            )
    }

    // MARK: - Style

    private var styleCard: some View {
        sectionCard {
            cardHeader(Text("Style"), systemImage: "paintpalette.fill")

            VStack(alignment: .leading, spacing: 10) {
                Text("Background")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 12) {
                    ForEach(Self.backgroundPresets, id: \.self) { hex in
                        colorSwatch(hex: hex, selection: $backgroundColor)
                    }
                    ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }

            if showsText || configuration.showsProgress || configuration.showsTimestamp {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        ForEach(Self.textPresets, id: \.self) { hex in
                            colorSwatch(hex: hex, selection: $textColor)
                        }
                        ColorPicker("Text", selection: $textColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Font")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Picker("Font", selection: $selectedFont) {
                        ForEach(WidgetFontOption.allCases) { option in
                            Text(option.localizedName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text("Font style"))

                    if showsText {
                        Text("The quick brown fox")
                            .font(selectedFont.font(size: 17, weight: .medium))
                            .foregroundStyle(textColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                backgroundColor.adjustedBrightness(0.10),
                                                backgroundColor.adjustedBrightness(-0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                            .accessibilityLabel(Text("Font preview"))
                    }
                }
            }
        }
    }

    private func colorSwatch(hex: String, selection: Binding<Color>) -> some View {
        let swatchColor = Color(hex: hex) ?? .gray
        let isSelected = selection.wrappedValue.toHex().caseInsensitiveCompare(hex) == .orderedSame
        let lightSwatch = Self.isLightColor(hex: hex)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selection.wrappedValue = swatchColor
            }
        } label: {
            Circle()
                .fill(swatchColor)
                .frame(width: 33, height: 33)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(lightSwatch ? Color.black : Color.white)
                            .shadow(color: .black.opacity(lightSwatch ? 0 : 0.45), radius: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: hex))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func isLightColor(hex: String) -> Bool {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else { return false }
        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        return (0.299 * red + 0.587 * green + 0.114 * blue) > 0.65
    }

    // MARK: - Background image

    private var imageCard: some View {
        sectionCard {
            cardHeader(Text("Background Image"), systemImage: "photo.fill")

            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(Text("Selected background image"))

                HStack(spacing: 10) {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 6) {
                            if isImportingPhoto {
                                ProgressView()
                            } else {
                                Image(systemName: "photo.on.rectangle")
                            }
                            Text("Replace Image")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isImportingPhoto)

                    Button(role: .destructive) {
                        removeBackgroundImage()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Remove Image")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    VStack(spacing: 8) {
                        if isImportingPhoto {
                            ProgressView()
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        Text("Choose Image")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.tint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(.tertiary)
                    )
                }
                .disabled(isImportingPhoto)
            }

            Text("Photos stay on your device. Tap Save to apply image changes to your Home Screen widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Progress

    private var progressCard: some View {
        sectionCard {
            cardHeader(Text("Progress"), systemImage: "slider.horizontal.3")

            HStack {
                Slider(value: $configuration.progress, in: 0...1, step: 0.01)
                    .accessibilityLabel(Text("Widget progress"))
                    .accessibilityValue(L10n.accessibilityPercent(configuration.progress))

                Text(LocaleFormatting.percent(configuration.progress))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
        }
    }

    // MARK: - Live Activity

    private var liveActivityCard: some View {
        sectionCard {
            cardHeader(Text("Live Activity"), systemImage: "bolt.fill")

            HStack(spacing: 8) {
                Circle()
                    .fill(isLiveActivityActive ? Color.green : Color(.systemGray3))
                    .frame(width: 8, height: 8)
                Text(isLiveActivityActive
                     ? String(localized: "Dynamic Island and Lock Screen are showing your widget.")
                     : String(localized: "Mirror your design on Dynamic Island and the Lock Screen."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isLiveActivityActive {
                HStack(spacing: 10) {
                    Button {
                        Task { await updateLiveActivity() }
                    } label: {
                        Text("Update Live Activity")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        Task { await endLiveActivity() }
                    } label: {
                        Text("End Live Activity")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    Task { await startLiveActivity() }
                } label: {
                    Text("Start Live Activity")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Help

    private var helpCard: some View {
        sectionCard {
            Button {
                showHelp = true
            } label: {
                HStack(spacing: 10) {
                    IconBadge(systemName: "plus.rectangle.on.rectangle")
                    Text("How to add to Home Screen")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            Text("After saving, long-press a Home Screen widget and choose Edit Widget to pick a design from your portfolio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        Group {
            if showSavedBanner {
                savedBanner
            } else if hasUnsavedChanges {
                saveBar
            } else if showAssignDesignTip {
                assignDesignTipBanner
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: hasUnsavedChanges)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSavedBanner)
    }

    private var saveBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Unsaved")
                    .font(.subheadline.weight(.semibold))
                Text("You have unsaved edits. Tap Save to update Home Screen widgets.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)

            Button {
                saveConfiguration()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(isSaving || isImportingPhoto)
            .accessibilityHint(Text("Saves your design and refreshes Home Screen widgets"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var savedBanner: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Saved — Home Screen widgets refreshed")
                    .font(.subheadline.weight(.medium))
            }
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var assignDesignTipBanner: some View {
        Text("Tip: long-press a widget → Edit Widget to choose a design.")
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
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

    // MARK: - Card scaffolding

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private func cardHeader(_ title: Text, systemImage: String) -> some View {
        HStack(spacing: 10) {
            IconBadge(systemName: systemImage)
            title
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
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
        backgroundColor = Color(hex: design.configuration.backgroundColorHex) ?? .indigo
        textColor = Color(hex: design.configuration.textColorHex) ?? .white
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

// MARK: - Small components

private struct IconBadge: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.gradient)
            )
            .accessibilityHidden(true)
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
                    .font(.system(size: 52))
                    .padding(22)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.14))
                    )
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
                .buttonBorderShape(.roundedRectangle(radius: 16))
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.accentColor.gradient)
                )
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
