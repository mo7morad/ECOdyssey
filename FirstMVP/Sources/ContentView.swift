import SwiftUI
import PhotosUI
import AVFoundation

@Observable
class LiveScannerViewModel {
    var trackedObjects: [TrackedObject] = []
    var currentResult: AnalysisResult?
    var selectedGalleryImage: UIImage? = nil
    var isVoiceEnabled: Bool = true
    var isProcessing: Bool = false
    var photosPickerItem: PhotosPickerItem?
    var showAnalyticsSheet: Bool = false
    
    private let classifier = TrashClassifierEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private let analyticsStore = AnalyticsStore.shared
    private var lastSpokenCategory: AnalysisResult.BinCategory?
    private var lastSpokenTime = Date.distantPast
    
    func processFrame(pixelBuffer: CVPixelBuffer) {
        // Pause live camera processing if a gallery image is selected or already processing
        guard selectedGalleryImage == nil, !isProcessing else { return }
        isProcessing = true
        
        Task {
            do {
                // Multi-object instance segmentation & tracking analysis
                let detected = try await classifier.analyzeMultiObjects(pixelBuffer: pixelBuffer)
                
                await MainActor.run {
                    guard self.selectedGalleryImage == nil else {
                        self.isProcessing = false
                        return
                    }
                    self.trackedObjects = detected
                    if let first = detected.first {
                        let res = AnalysisResult(
                            detectedObject: first.label,
                            material: first.material,
                            binCategory: first.binCategory,
                            confidence: first.confidence,
                            rawDetails: "Multi-Object Tracked"
                        )
                        self.currentResult = res
                        self.speakIfNeeded(result: res)
                        
                        // Automatically log into analytics database
                        self.analyticsStore.logItem(objectName: first.label, material: first.material, binCategory: first.binCategory)
                    }
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                }
            }
        }
    }
    
    func processImage(_ image: UIImage) {
        // Pause live detection and isolate selected gallery image
        self.selectedGalleryImage = image
        self.trackedObjects = [] // Clear bounding boxes for live view
        self.currentResult = nil
        self.isProcessing = true
        
        Task {
            do {
                let result = try await classifier.analyze(image: image)
                await MainActor.run {
                    self.currentResult = result
                    self.isProcessing = false
                    self.analyticsStore.logItem(objectName: result.detectedObject, material: result.material, binCategory: result.binCategory)
                    self.speak(text: "\(result.detectedObject). \(result.binCategory.spokenText)")
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                }
                print("Image analysis failed: \(error)")
            }
        }
    }
    
    func resumeLiveCamera() {
        self.selectedGalleryImage = nil
        self.currentResult = nil
        self.trackedObjects = []
    }
    
    private func speakIfNeeded(result: AnalysisResult) {
        guard isVoiceEnabled else { return }
        let now = Date()
        
        if result.binCategory != lastSpokenCategory || now.timeIntervalSince(lastSpokenTime) > 4.0 {
            lastSpokenCategory = result.binCategory
            lastSpokenTime = now
            let message = "\(result.detectedObject). \(result.binCategory.spokenText)"
            speak(text: message)
        }
    }
    
    private func speak(text: String) {
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
    }
}

struct ContentView: View {
    @State private var viewModel = LiveScannerViewModel()
    @Bindable private var analyticsStore = AnalyticsStore.shared
    @State private var photosPickerItem: PhotosPickerItem?
    
    var body: some View {
        ZStack {
            // 1. Live Camera Stream or Selected Gallery Photo Display
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
                    viewModel.processFrame(pixelBuffer: pixelBuffer)
                }
                .ignoresSafeArea()
            }
            
            // 2. Bounding Box & Multi-Object Segmentation Overlay (Live Mode Only)
            if viewModel.selectedGalleryImage == nil {
                GeometryReader { geo in
                    ForEach(viewModel.trackedObjects) { obj in
                        let rect = CGRect(
                            x: obj.boundingBox.minX * geo.size.width,
                            y: (1 - obj.boundingBox.maxY) * geo.size.height,
                            width: obj.boundingBox.width * geo.size.width,
                            height: obj.boundingBox.height * geo.size.height
                        )
                        
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(binColor(for: obj.binCategory), lineWidth: 3)
                                .background(binColor(for: obj.binCategory).opacity(0.12).cornerRadius(12))
                            
                            Text("\(obj.label) • \(obj.material)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(binColor(for: obj.binCategory))
                                .cornerRadius(6)
                                .offset(y: -24)
                        }
                        .frame(width: max(rect.width, 100), height: max(rect.height, 80))
                        .position(x: rect.midX, y: rect.midY)
                        .animation(.spring(), value: obj.boundingBox)
                    }
                }
            }
            
            // 3. UI Controls & Header Bar
            VStack {
                // Header Bar
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.selectedGalleryImage != nil ? "Gallery Photo Analysis" : "EcoSort Multi-AI")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                        Text(viewModel.selectedGalleryImage != nil ? "Static image inspection" : "Multi-object segmenting & tracking")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // Resume Live Camera Button (Shown when Gallery Photo is active)
                    if viewModel.selectedGalleryImage != nil {
                        Button {
                            viewModel.resumeLiveCamera()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                Text("Live Camera")
                                    .fontWeight(.bold)
                            }
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(Capsule())
                            .foregroundColor(.white)
                        }
                    }
                    
                    // Analytics Button with Badge
                    Button {
                        viewModel.showAnalyticsSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.fill")
                            Text("\(analyticsStore.totalCount)")
                                .fontWeight(.bold)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                        .foregroundColor(.green)
                    }
                    
                    // Voice Mute/Unmute Toggle
                    Button {
                        viewModel.isVoiceEnabled.toggle()
                    } label: {
                        Image(systemName: viewModel.isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.title3)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                            .foregroundColor(viewModel.isVoiceEnabled ? .green : .white)
                    }
                    
                    // Gallery Picker
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle.fill")
                            .font(.title3)
                            .padding(10)
                            .background(.thinMaterial)
                            .clipShape(Circle())
                            .foregroundColor(.white)
                    }
                    .onChange(of: photosPickerItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                viewModel.processImage(uiImage)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
                
                Spacer()
                
                // 4. Real-Time Dynamic Result Card
                if viewModel.isProcessing {
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
                    .padding(.bottom, 30)
                } else if let result = viewModel.currentResult {
                    VStack(alignment: .leading, spacing: 12) {
                        // Bin Banner
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SORT INTO")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(result.binCategory.title)
                                    .font(.headline)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            
                            if viewModel.isVoiceEnabled {
                                Image(systemName: "waveform")
                                    .symbolEffect(.variableColor.iterative)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(binColor(for: result.binCategory))
                        .cornerRadius(12)
                        
                        // Object & Material Info
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("DETECTED ITEM")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Text(result.detectedObject)
                                    .font(.body)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("MATERIAL")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                                Text(result.material)
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text(result.binCategory.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAnalyticsSheet) {
            AnalyticsView()
        }
    }
    
    private func binColor(for category: AnalysisResult.BinCategory) -> Color {
        switch category {
        case .organic: return .green
        case .nonOrganicRecyclable: return .blue
        case .residual: return .gray
        }
    }
}

#Preview {
    ContentView()
}
