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
    @State private var saveMessage: String?
    @State private var isLiveActivityActive = LiveActivityController.isActivityInProgress

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextField("Title", text: $configuration.title)
                    TextField("Subtitle", text: $configuration.subtitle)
                    TextField("Emoji", text: $configuration.emoji)
                }

                Section("Colors") {
                    ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)
                    ColorPicker("Text", selection: $textColor, supportsOpacity: false)
                }

                Section("Font") {
                    Picker("Style", selection: $selectedFont) {
                        ForEach(WidgetFontOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Preview")
                        .font(selectedFont.font(size: 17))
                        .foregroundStyle(textColor)
                }

                Section("Background Image") {
                    if let previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            configuration.backgroundImageFileName == nil ? "Choose Image" : "Replace Image",
                            systemImage: "photo.on.rectangle"
                        )
                    }

                    if configuration.backgroundImageFileName != nil {
                        Button("Remove Image", role: .destructive) {
                            removeBackgroundImage()
                        }
                    }
                }

                Section("Live Activity") {
                    Text(isLiveActivityActive ? "Dynamic Island is active." : "Push utility data to Dynamic Island.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isLiveActivityActive {
                        Button("Update Live Activity") {
                            updateLiveActivity()
                        }

                        Button("End Live Activity", role: .destructive) {
                            endLiveActivity()
                        }
                    } else {
                        Button("Start Live Activity") {
                            startLiveActivity()
                        }
                    }
                }

                Section {
                    Button("Save Widget") {
                        saveConfiguration()
                    }
                    .frame(maxWidth: .infinity)

                    if let saveMessage {
                        Text(saveMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Widget Editor")
            .onAppear {
                loadExistingConfiguration()
                isLiveActivityActive = LiveActivityController.isActivityInProgress
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await importSelectedPhoto(newItem)
                }
            }
        }
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

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            saveMessage = "Could not load the selected image."
            return
        }

        if let oldFileName = configuration.backgroundImageFileName {
            SharedImageStore.deleteImage(fileName: oldFileName)
        }

        do {
            let fileName = try SharedImageStore.saveImageData(data)
            configuration.backgroundImageFileName = fileName
            previewImage = UIImage(data: data)
            saveMessage = "Image saved to shared container."
        } catch {
            saveMessage = "Failed to save image."
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
        applyEditorStateToConfiguration()
        SharedDataStore.save(configuration)
        WidgetCenter.shared.reloadAllTimelines()

        if isLiveActivityActive {
            Task {
                await LiveActivityController.update(from: configuration)
            }
        }

        saveMessage = "Widget configuration saved."
    }

    private func applyEditorStateToConfiguration() {
        configuration.backgroundColorHex = backgroundColor.toHex()
        configuration.textColorHex = textColor.toHex()
        configuration.fontName = selectedFont.rawValue
    }

    private func startLiveActivity() {
        applyEditorStateToConfiguration()
        SharedDataStore.save(configuration)

        do {
            _ = try LiveActivityController.start(from: configuration)
            isLiveActivityActive = true
            saveMessage = "Live Activity started on Dynamic Island."
        } catch {
            saveMessage = error.localizedDescription
        }
    }

    private func updateLiveActivity() {
        applyEditorStateToConfiguration()
        SharedDataStore.save(configuration)

        Task {
            await LiveActivityController.update(from: configuration)
            isLiveActivityActive = LiveActivityController.isActivityInProgress
            saveMessage = "Live Activity updated."
        }
    }

    private func endLiveActivity() {
        Task {
            await LiveActivityController.endAll()
            isLiveActivityActive = false
            saveMessage = "Live Activity ended."
        }
    }
}

#Preview {
    WidgetConfigurationView()
}
