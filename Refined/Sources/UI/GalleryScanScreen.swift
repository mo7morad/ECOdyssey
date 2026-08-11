import PhotosUI
import SwiftUI

/// Runs a picture from the photo library through the station's own perception and
/// ruleset, for checking a decision away from the bin.
struct GalleryScanScreen: View {
    let scanner: StillImageScanner

    @Environment(\.dismiss) private var dismiss
    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedImage: CGImage?
    @State private var loadFailure: Error?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview
                DecisionCard(decision: scanner.decision, isPerceiving: scanner.isPerceiving)
                failureNotice
                Spacer()
                picker
            }
            .padding()
            .navigationTitle("Read a photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                Task { await read(item) }
            }
        }
    }

    /// The title is read into a local before the picker's label closure captures it:
    /// that closure is `Sendable`, so touching main-actor state from inside it is a data
    /// race the compiler is right to complain about.
    private var picker: some View {
        let title = pickedImage == nil ? "Choose a photo" : "Choose another photo"

        return PhotosPicker(selection: $pickedItem, matching: .images) {
            Label(title, systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
    }

    @ViewBuilder
    private var preview: some View {
        if let pickedImage {
            Image(decorative: pickedImage, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            ContentUnavailableView(
                "No photo chosen",
                systemImage: "photo",
                description: Text(
                    """
                    Pick a picture of a single item to see which bin it belongs in. \
                    Photos read here are not counted in analytics.
                    """
                )
            )
        }
    }

    @ViewBuilder
    private var failureNotice: some View {
        if let failure = loadFailure ?? scanner.failure {
            Text("Could not read this photo: \(String(describing: failure))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func read(_ item: PhotosPickerItem) async {
        loadFailure = nil
        do {
            guard let encoded = try await item.loadTransferable(type: Data.self) else {
                throw GalleryImageError.itemCarriedNoImage
            }
            // The same decode the live station applies to the photograph it takes, so a
            // picked photo and a held-up item reach the model in identical shape.
            let image = try UprightImageDecoder.decode(encoded)
            pickedImage = image
            await scanner.scan(image)
        } catch {
            loadFailure = error
        }
    }
}

private enum GalleryImageError: Error {
    case itemCarriedNoImage
}
