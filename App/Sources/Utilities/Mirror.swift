import AVFoundation
import SwiftUI

/// A quick look at yourself before a call. The camera runs only while the
/// Mirror tool is on screen.
@MainActor
final class CameraService: ObservableObject {
    @Published private(set) var access: AccessState
    @Published private(set) var hasCamera = true

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "app.macbooknotch.camera")
    private var configured = false
    private var viewers = 0

    init() {
        access = Self.currentAccess()
    }

    func beginViewing() {
        viewers += 1
        guard viewers == 1 else { return }
        access = Self.currentAccess()
        switch access {
        case .granted:
            startSession()
        case .notAsked:
            Task {
                _ = await AVCaptureDevice.requestAccess(for: .video)
                self.access = Self.currentAccess()
                if self.access == .granted, self.viewers > 0 {
                    self.startSession()
                }
            }
        case .denied:
            break
        }
    }

    func endViewing() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        let session = self.session
        queue.async { session.stopRunning() }
    }

    private func startSession() {
        if !configured {
            configured = true
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
                ?? AVCaptureDevice.default(for: .video)
            guard let device, let input = try? AVCaptureDeviceInput(device: device) else {
                hasCamera = false
                return
            }
            session.beginConfiguration()
            session.sessionPreset = .medium
            if session.canAddInput(input) { session.addInput(input) }
            session.commitConfiguration()
        }
        let session = self.session
        queue.async { session.startRunning() }
    }

    private static func currentAccess() -> AccessState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .notDetermined: return .notAsked
        default: return .denied
        }
    }
}

struct MirrorPanel: View {
    @ObservedObject var camera: CameraService

    var body: some View {
        Group {
            switch camera.access {
            case .granted where camera.hasCamera:
                CameraPreview(session: camera.session)
                    .clipShape(RoundedRectangle(cornerRadius: NotchStyle.Card.radius + 4, style: .continuous))
                    .accessibilityLabel("Camera preview")
            case .granted:
                EmptyToolState(symbol: "video.slash", title: "No camera found", message: "Connect a camera, or close another app that's using it.")
            case .notAsked:
                EmptyToolState(symbol: "web.camera", title: "Checking your camera…", message: "macOS will ask for permission once.")
            case .denied:
                PermissionPrompt(
                    symbol: "video.slash",
                    title: "Camera access is off",
                    message: "Turn on MacbookNotch in Privacy & Security › Camera.",
                    buttonTitle: "Open System Settings",
                    action: { SystemSettingsLink.open("Privacy_Camera") }
                )
            }
        }
        .onAppear { camera.beginViewing() }
        .onDisappear { camera.endViewing() }
    }
}

/// AVFoundation's live preview layer, mirrored like a real mirror.
private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        if let connection = layer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        let view = NSView()
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
