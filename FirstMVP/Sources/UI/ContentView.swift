import SwiftUI
import PhotosUI

public struct ContentView: View {
    @State private var viewModel = LiveScannerViewModel()
    @Bindable private var analyticsStore = AnalyticsStore.shared
    @State private var selectedPhotoPickerItem: PhotosPickerItem?

    public init() {}

    public var body: some View {
        ZStack {
            backgroundMediaView
            if viewModel.selectedGalleryImage == nil {
                boundingBoxOverlayView
            }
            foregroundControlsView
        }
        .sheet(isPresented: $viewModel.isAnalyticsSheetPresented) {
            AnalyticsView()
        }
    }

    private var backgroundMediaView: some View {
        Group {
            if let galleryImage = viewModel.selectedGalleryImage {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: galleryImage)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                }
            } else {
                LiveCameraScannerView { pixelBuffer in
                    viewModel.processFrameBuffer(pixelBuffer)
                }
                .ignoresSafeArea()
            }
        }
    }

    private var boundingBoxOverlayView: some View {
        GeometryReader { geo in
            ForEach(viewModel.trackedItems) { item in
                let bin = Bin.resolve(item.assignedBinID)
                let rect = calculateRect(for: item.boundingBox, in: geo.size)
                let isNearTop = rect.minY < 35

                ZStack(alignment: isNearTop ? .topLeading : .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(binColor(for: bin.colorName), lineWidth: 3)
                        .background(binColor(for: bin.colorName).opacity(0.12).cornerRadius(12))

                    Text("\(item.perception.classificationLabel) • \(item.perception.materialName)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(binColor(for: bin.colorName))
                        .cornerRadius(6)
                        .offset(y: isNearTop ? 4 : -24)
                }
                .frame(width: max(rect.width, 100), height: max(rect.height, 80))
                .position(x: rect.midX, y: rect.midY)
                .animation(.spring(), value: item.boundingBox)
            }
        }
    }

    private var foregroundControlsView: some View {
        VStack(spacing: 0) {
            HeaderBarView(
                viewModel: viewModel,
                analyticsStore: analyticsStore,
                selectedPhotoPickerItem: $selectedPhotoPickerItem
            )
            Spacer(minLength: 12)
            if viewModel.isProcessing {
                processingCardView
            } else if let bin = viewModel.activeBin, let perception = viewModel.activePerception {
                resultCardView(bin: bin, perception: perception)
            }
        }
        .padding(.bottom, 16)
    }

    private var processingCardView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)
            Text("Analyzing photo...")
                .font(.subheadline)
                .foregroundColor(.white)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func resultCardView(bin: Bin, perception: ItemPerception) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            resultBannerView(bin: bin)
            detectedItemDetailsView(perception: perception)
            Text(bin.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func resultBannerView(bin: Bin) -> some View {
        let isVoice = viewModel.isVoiceEnabled
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SORT INTO").font(.caption2).fontWeight(.bold).foregroundColor(.white.opacity(0.8))
                Text(bin.displayName).font(.headline).fontWeight(.heavy).foregroundColor(.white)
                    .lineLimit(1).minimumScaleFactor(0.85)
            }
            Spacer()
            if isVoice {
                Image(systemName: "waveform").symbolEffect(.variableColor.iterative).foregroundColor(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(binColor(for: bin.colorName))
        .cornerRadius(12)
    }

    private func detectedItemDetailsView(perception: ItemPerception) -> some View {
        HStack(spacing: 12) {
            itemColumn(title: "DETECTED ITEM", value: perception.classificationLabel, color: .primary)
            Spacer(minLength: 4)
            itemColumn(title: "MATERIAL", value: perception.materialName, color: .blue)
        }
    }

    private func itemColumn(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
            Text(value).font(.subheadline).fontWeight(.bold).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func calculateRect(for boundingBox: CGRect, in containerSize: CGSize) -> CGRect {
        let minX = max(0, min(1, boundingBox.minX))
        let minY = max(0, min(1, boundingBox.minY))
        let width = max(0.05, min(1 - minX, boundingBox.width))
        let height = max(0.05, min(1 - minY, boundingBox.height))

        return CGRect(
            x: minX * containerSize.width,
            y: (1 - (minY + height)) * containerSize.height,
            width: width * containerSize.width,
            height: height * containerSize.height
        )
    }

    private func binColor(for name: String) -> Color {
        switch name {
        case "green": return .green
        case "blue": return .blue
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
}
