import SwiftUI

@main
struct ViewerApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @State private var host = "192.168.1.100"
    @State private var port = "5055"
    @State private var receiver = PCFrameReceiver()
    @State private var image: UIImage?
    @State private var status = "Disconnected"
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            Text("PC CAMERA · transport test").font(.headline)
            HStack {
                TextField("Windows IPv4", text: $host).keyboardType(.decimalPad)
                TextField("Port", text: $port).keyboardType(.numberPad).frame(width: 65)
            }.textFieldStyle(.roundedBorder)
            HStack {
                Button("Connect") {
                    guard let value = UInt16(port), value > 0, !host.isEmpty else {
                        status = "Enter a host and valid port"
                        return
                    }
                    receiver.connect(host: host.trimmingCharacters(in: .whitespaces), port: value)
                }
                Button("Disconnect") { receiver.stop() }
            }.buttonStyle(.bordered)
            if let image = image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: .infinity)
            } else {
                Rectangle().fill(.black).overlay(Text("Waiting for JPEG frames").foregroundStyle(.white))
            }
            Text(status).font(.caption).monospacedDigit()
            Text("Viewer only · no camera substitution").font(.caption)
        }
        .padding()
        .onReceive(timer) { _ in
            let snapshot = receiver.latest()
            image = snapshot.image
            status = snapshot.status
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background { receiver.stop() }
        }
    }
}
