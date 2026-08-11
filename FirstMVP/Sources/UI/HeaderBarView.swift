import SwiftUI
import PhotosUI

public struct HeaderBarView: View {
    @Bindable var viewModel: LiveScannerViewModel
    @Bindable var analyticsStore: AnalyticsStore
    @Binding var selectedPhotoPickerItem: PhotosPickerItem?

    public init(
        viewModel: LiveScannerViewModel,
        analyticsStore: AnalyticsStore,
        selectedPhotoPickerItem: Binding<PhotosPickerItem?>
    ) {
        self.viewModel = viewModel
        self.analyticsStore = analyticsStore
        self._selectedPhotoPickerItem = selectedPhotoPickerItem
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            headerTitleView
                .layoutPriority(0)

            Spacer(minLength: 4)

            actionButtonsView
                .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.65), .black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var headerTitleView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.selectedGalleryImage != nil ? "Gallery Analysis" : "EcoSort Multi-AI")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .shadow(radius: 4)

            Text(viewModel.selectedGalleryImage != nil ? "Static inspection" : "Multi-object tracking")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var actionButtonsView: some View {
        HStack(spacing: 6) {
            if viewModel.selectedGalleryImage != nil {
                liveCameraButton
            }
            analyticsButton
            voiceToggleButton
            galleryPickerButton
        }
    }

    private var liveCameraButton: some View {
        Button {
            viewModel.resumeLiveCamera()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "camera.fill")
                Text("Live").fontWeight(.bold)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(Capsule())
            .foregroundColor(.white)
        }
    }

    private var analyticsButton: some View {
        Button {
            viewModel.isAnalyticsSheetPresented = true
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "chart.bar.fill")
                Text("\(analyticsStore.totalCount)").fontWeight(.bold)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .foregroundColor(.green)
        }
    }

    private var voiceToggleButton: some View {
        Button {
            viewModel.isVoiceEnabled.toggle()
        } label: {
            Image(systemName: viewModel.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.caption)
                .padding(8)
                .background(.thinMaterial)
                .clipShape(Circle())
                .foregroundColor(viewModel.isVoiceEnabled ? .green : .white)
        }
    }

    private var galleryPickerButton: some View {
        PhotosPicker(selection: $selectedPhotoPickerItem, matching: .images) {
            Image(systemName: "photo.on.rectangle.fill")
                .font(.caption)
                .padding(8)
                .background(.thinMaterial)
                .clipShape(Circle())
                .foregroundColor(.white)
        }
        .onChange(of: selectedPhotoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    viewModel.processSelectedImage(uiImage)
                }
            }
        }
    }
}
