import SwiftUI

@main
struct ViewerApp: App {
    init() { VCInstallHook() }
    var body: some Scene { WindowGroup { ContentView() } }
}
struct ContentView: View {
    @AppStorage("pcHost") private var host = "172.20.10.4"
    @State private var receiver = PCFrameReceiver()
    @State private var camera = CameraModel()
    @State private var mode = 0
    @State private var freeze = false
    @State private var image: UIImage?
    @State private var networkStatus = "Disconnected"
    @State private var cameraStatus = ""
    @State private var hookStatus = ""
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 10) {
            Text("Camera substitution test · v0.2").font(.headline)
            HStack {
                TextField("Windows IPv4", text: $host).keyboardType(.decimalPad).textFieldStyle(.roundedBorder)
                Button("Connect") { receiver.connect(host: host.trimmingCharacters(in: .whitespaces), port: 5055) }
                Button("Disconnect") { receiver.stop() }
            }
            Picker("Mode", selection: $mode) {
                Text("PC viewer").tag(0)
                Text("Real camera").tag(1)
                Text("Hook test").tag(2)
            }.pickerStyle(.segmented)
            Toggle("Freeze PC image when disconnected", isOn: $freeze).font(.caption)
            if let image = image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: .infinity)
            } else { Rectangle().fill(.black).overlay(Text("Waiting for frames").foregroundStyle(.white)) }
            Text(networkStatus).font(.caption)
            if mode != 0 {
                Text(cameraStatus).font(.caption2)
                Text(hookStatus).font(.caption2)
            }
            Text(mode == 0 ? "Direct viewer — not hook proof" : "Same camera callback renderer · portrait 720×1280 BGRA").font(.caption2)
        }.padding()
        .onChange(of: mode) { _ in applyMode() }
        .onChange(of: freeze) { VCSetFreeze($0) }
        .onReceive(timer) { _ in
            let snapshot = receiver.latest()
            networkStatus = snapshot.status
            if mode == 0 { image = snapshot.image }
            else {
                let snapshot = camera.latest()
                image = snapshot.0; cameraStatus = snapshot.1; hookStatus = VCStatus()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { camera.stop(); receiver.stop(); VCSetEnabled(false) }
            if phase == .active { applyMode() }
        }
    }
    private func applyMode() {
        image = nil
        VCSetEnabled(mode == 2)
        if mode == 0 { camera.stop() } else { camera.start() }
    }
}
