import SwiftUI
import Flutter
import AVFoundation
import MLKit
import MLKitPoseDetection
import MLKitVision
import UIKit

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    lazy var flutterEngine = FlutterEngine(name: "my flutter engine")
    var flutterChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Runs the default Dart entrypoint with a default Flutter route.
        flutterEngine.run()
        
        // Use the FlutterViewController as the root view controller
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = flutterViewController
        window?.makeKeyAndVisible()
        
        // Set up the method channel
        flutterChannel = FlutterMethodChannel(name: "camera_channel", binaryMessenger: flutterViewController.binaryMessenger)
        flutterChannel?.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "openCamera" {
                self?.openCamera(result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self.flutterEngine)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // private func openCamera(result: @escaping FlutterResult) {
    //     DispatchQueue.main.async {
    //         let cameraView = CameraView(resultHandler: result)
    //         let hostingController = UIHostingController(rootView: cameraView)
    //         self.window?.rootViewController?.present(hostingController, animated: true, completion: nil)
    //     }
    // }

    private func openCamera(result: @escaping FlutterResult) {
      DispatchQueue.main.async {
          let cameraView = CameraView(resultHandler: result)
          let hostingController = UIHostingController(rootView: cameraView)
          hostingController.modalPresentationStyle = .fullScreen
          self.window?.rootViewController?.present(hostingController, animated: true, completion: nil)
      }
  }
}

struct ContentView: View {
    var body: some View {
        Text("Flutter Integration")
    }
}

struct CameraView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showingInitialView = true
    var resultHandler: FlutterResult?
    
    var body: some View {
        NavigationView {
            ZStack {
                if showingInitialView {
                    VStack {
                        Button("Open Camera") {
                            showingInitialView = false
                        }
                        .padding()
                        
                        Button("Return to Flutter") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .padding()
                    }
                } else if 1 == 1 {
                    CameraPreview()
                        .edgesIgnoringSafeArea(.all)
                    VStack {
                        HStack {
                            Button(action: {
                                showingInitialView = true
                            }) {
                                Image(systemName: "arrow.left")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                } else {
                    Text("Setting up camera...")
                }
            }
            .navigationBarTitle("Camera", displayMode: .inline)
            .navigationBarItems(leading: Button("Close") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .edgesIgnoringSafeArea(.all)
        .onDisappear {
            
        }
    }
}


struct CameraPreview: UIViewControllerRepresentable {
//    let session: AVCaptureSession
//    
//    func makeUIView(context: Context) -> UIView {
//        let view = UIView(frame: UIScreen.main.bounds)
//        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
//        previewLayer.frame = view.bounds
//        previewLayer.videoGravity = .resizeAspectFill
//        view.layer.addSublayer(previewLayer)
//        return view
//    }
//    
//    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeUIViewController(context: Context) -> UINavigationController {
        let cameraViewController = CameraViewController()
        return UINavigationController(rootViewController: cameraViewController)
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}


@objc(CameraViewController)
class CameraViewController: UIViewController {
    private let detectors: [Detector] = [.pose, .poseAccurate]
    private var currentDetector: Detector = .poseAccurate
    private var isUsingFrontCamera = true
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var captureSession = AVCaptureSession()
    private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
    private var lastFrame: CMSampleBuffer?

    private var cameraView: UIView!
    private var previewOverlayView: UIImageView!
    private var annotationOverlayView: UIView!
    
    private var poseDetector: PoseDetector?
    private var lastDetector: Detector?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        setUpCaptureSessionOutput()
        setUpCaptureSessionInput()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = cameraView.bounds
    }

    private func setupViews() {
        // Set up cameraView
        cameraView = UIView()
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraView)
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Set up previewOverlayView
        previewOverlayView = UIImageView()
        previewOverlayView.contentMode = .scaleAspectFit
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            previewOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            previewOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor)
        ])

        // Set up annotationOverlayView
        annotationOverlayView = UIView()
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor)
        ])

        // Add buttons programmatically
        let detectorsButton = UIButton(type: .system)
        detectorsButton.setTitle("Select Detector", for: .normal)
        detectorsButton.addTarget(self, action: #selector(selectDetector), for: .touchUpInside)
        
        let switchCameraButton = UIButton(type: .system)
        switchCameraButton.setTitle("Switch Camera", for: .normal)
        switchCameraButton.addTarget(self, action: #selector(switchCamera), for: .touchUpInside)
        
        let buttonStackView = UIStackView(arrangedSubviews: [detectorsButton, switchCameraButton])
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .equalSpacing
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(buttonStackView)
        NSLayoutConstraint.activate([
            buttonStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    @objc private func selectDetector() {
        presentDetectorsAlertController()
    }

    @objc private func switchCamera() {
        isUsingFrontCamera = !isUsingFrontCamera
        removeDetectionAnnotations()
        setUpCaptureSessionInput()
    }

  // MARK: On-Device Detections

  private func detectPose(in image: MLImage, width: CGFloat, height: CGFloat) {
    if let poseDetector = self.poseDetector {
      var poses: [Pose] = []
      var detectionError: Error?
      do {
        poses = try poseDetector.results(in: image)
      } catch let error {
        detectionError = error
      }
      weak var weakSelf = self
      DispatchQueue.main.sync {
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.updatePreviewOverlayViewWithLastFrame()
        if let detectionError = detectionError {
          print("Failed to detect poses with error: \(detectionError.localizedDescription).")
          return
        }
        guard !poses.isEmpty else {
          print("Pose detector returned no results.")
          return
        }

        // Pose detected. Currently, only single person detection is supported.
        poses.forEach { pose in
          let poseOverlayView = UIUtilities.createPoseOverlayView(
            forPose: pose,
            inViewWithBounds: strongSelf.annotationOverlayView.bounds,
            lineWidth: Constant.lineWidth,
            dotRadius: Constant.smallDotRadius,
            positionTransformationClosure: { (position) -> CGPoint in
              return strongSelf.normalizedPoint(
                fromVisionPoint: position, width: width, height: height)
            }
          )
          strongSelf.annotationOverlayView.addSubview(poseOverlayView)
        }
      }
    }
  }

  // MARK: - Private

  private func setUpCaptureSessionOutput() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      strongSelf.captureSession.beginConfiguration()
      // When performing latency tests to determine ideal capture settings,
      // run the app in 'release' mode to get accurate performance metrics
      strongSelf.captureSession.sessionPreset = AVCaptureSession.Preset.medium

      let output = AVCaptureVideoDataOutput()
      output.videoSettings = [
        (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
      ]
      output.alwaysDiscardsLateVideoFrames = true
      let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
      output.setSampleBufferDelegate(strongSelf, queue: outputQueue)
      guard strongSelf.captureSession.canAddOutput(output) else {
        print("Failed to add capture session output.")
        return
      }
      strongSelf.captureSession.addOutput(output)
      strongSelf.captureSession.commitConfiguration()
    }
  }

  private func setUpCaptureSessionInput() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      let cameraPosition: AVCaptureDevice.Position = strongSelf.isUsingFrontCamera ? .front : .back
      guard let device = strongSelf.captureDevice(forPosition: cameraPosition) else {
        print("Failed to get capture device for camera position: \(cameraPosition)")
        return
      }
      do {
        strongSelf.captureSession.beginConfiguration()
        let currentInputs = strongSelf.captureSession.inputs
        for input in currentInputs {
          strongSelf.captureSession.removeInput(input)
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard strongSelf.captureSession.canAddInput(input) else {
          print("Failed to add capture session input.")
          return
        }
        strongSelf.captureSession.addInput(input)
        strongSelf.captureSession.commitConfiguration()
      } catch {
        print("Failed to create capture device input: \(error.localizedDescription)")
      }
    }
  }

  private func startSession() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      strongSelf.captureSession.startRunning()
    }
  }

  private func stopSession() {
    weak var weakSelf = self
    sessionQueue.async {
      guard let strongSelf = weakSelf else {
        print("Self is nil!")
        return
      }
      strongSelf.captureSession.stopRunning()
    }
  }

    private func setUpPreviewOverlayView() {
        previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.addSubview(previewOverlayView)
        NSLayoutConstraint.activate([
            previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
            previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            previewOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            previewOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor)
        ])
    }

    private func setUpAnnotationOverlayView() {
        annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        cameraView.addSubview(annotationOverlayView)
        NSLayoutConstraint.activate([
            annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
            annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
            annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
            annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
        ])
    }

  private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if #available(iOS 10.0, *) {
      let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera],
        mediaType: .video,
        position: .unspecified
      )
      return discoverySession.devices.first { $0.position == position }
    }
    return nil
  }

  private func presentDetectorsAlertController() {
    let alertController = UIAlertController(
      title: Constant.alertControllerTitle,
      message: Constant.alertControllerMessage,
      preferredStyle: .alert
    )
    weak var weakSelf = self
    detectors.forEach { detectorType in
      let action = UIAlertAction(title: detectorType.rawValue, style: .default) {
        [unowned self] (action) in
        guard let value = action.title else { return }
        guard let detector = Detector(rawValue: value) else { return }
        guard let strongSelf = weakSelf else {
          print("Self is nil!")
          return
        }
        strongSelf.currentDetector = detector
        strongSelf.removeDetectionAnnotations()
      }
      if detectorType.rawValue == self.currentDetector.rawValue { action.isEnabled = false }
      alertController.addAction(action)
    }
    alertController.addAction(UIAlertAction(title: Constant.cancelActionTitleText, style: .cancel))
    present(alertController, animated: true)
  }

  private func removeDetectionAnnotations() {
    for annotationView in annotationOverlayView.subviews {
      annotationView.removeFromSuperview()
    }
  }

  private func updatePreviewOverlayViewWithLastFrame() {
    guard let lastFrame = lastFrame,
      let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
    else {
      return
    }
    self.updatePreviewOverlayViewWithImageBuffer(imageBuffer)
    self.removeDetectionAnnotations()
  }

  private func updatePreviewOverlayViewWithImageBuffer(_ imageBuffer: CVImageBuffer?) {
    guard let imageBuffer = imageBuffer else {
      return
    }
    let orientation: UIImage.Orientation = isUsingFrontCamera ? .leftMirrored : .right
    let image = UIUtilities.createUIImage(from: imageBuffer, orientation: orientation)
    previewOverlayView.image = image
  }

  private func convertedPoints(
    from points: [NSValue]?,
    width: CGFloat,
    height: CGFloat
  ) -> [NSValue]? {
    return points?.map {
      let cgPointValue = $0.cgPointValue
      let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
      let cgPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
      let value = NSValue(cgPoint: cgPoint)
      return value
    }
  }

  private func normalizedPoint(
    fromVisionPoint point: VisionPoint,
    width: CGFloat,
    height: CGFloat
  ) -> CGPoint {
    let cgPoint = CGPoint(x: point.x, y: point.y)
    var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
    normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
    return normalizedPoint
  }

  /// Resets any detector instances which use a conventional lifecycle paradigm. This method is
  /// expected to be invoked on the AVCaptureOutput queue - the same queue on which detection is
  /// run.
  private func resetManagedLifecycleDetectors(activeDetector: Detector) {
    if activeDetector == self.lastDetector {
      // Same row as before, no need to reset any detectors.
      return
    }
    // Clear the old detector, if applicable.
    switch self.lastDetector {
    case .pose, .poseAccurate:
      self.poseDetector = nil
      break
    default:
      break
    }
    // Initialize the new detector, if applicable.
    switch activeDetector {
    case .pose, .poseAccurate:
      // The `options.detectorMode` defaults to `.stream`
      let options = activeDetector == .pose ? PoseDetectorOptions() : AccuratePoseDetectorOptions()
      self.poseDetector = PoseDetector.poseDetector(options: options)
      break
    default:
      break
    }
    self.lastDetector = activeDetector
  }

  private func rotate(_ view: UIView, orientation: UIImage.Orientation) {
    var degree: CGFloat = 0.0
    switch orientation {
    case .up, .upMirrored:
      degree = 90.0
    case .rightMirrored, .left:
      degree = 180.0
    case .down, .downMirrored:
      degree = 270.0
    case .leftMirrored, .right:
      degree = 0.0
    }
    view.transform = CGAffineTransform.init(rotationAngle: degree * 3.141592654 / 180)
  }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Failed to get image buffer from sample buffer.")
      return
    }
    // Evaluate `self.currentDetector` once to ensure consistency throughout this method since it
    // can be concurrently modified from the main thread.
    let activeDetector = self.currentDetector
    resetManagedLifecycleDetectors(activeDetector: activeDetector)

    lastFrame = sampleBuffer
    let visionImage = VisionImage(buffer: sampleBuffer)
    let orientation = UIUtilities.imageOrientation(
      fromDevicePosition: isUsingFrontCamera ? .front : .back
    )
    visionImage.orientation = orientation

    guard let inputImage = MLImage(sampleBuffer: sampleBuffer) else {
      print("Failed to create MLImage from sample buffer.")
      return
    }
    inputImage.orientation = orientation

    let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
    let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
    var shouldEnableClassification = false
    var shouldEnableMultipleObjects = false
    switch activeDetector {
    default:
      break
    }
    switch activeDetector {
    default:
      break
    }

    switch activeDetector {
    case .pose, .poseAccurate:
      detectPose(in: inputImage, width: imageWidth, height: imageHeight)
    }
  }
}

// MARK: - Constants

public enum Detector: String {
  case pose = "Pose Detection"
  case poseAccurate = "Pose Detection, accurate"
}

private enum Constant {
  static let alertControllerTitle = "Vision Detectors"
  static let alertControllerMessage = "Select a detector"
  static let cancelActionTitleText = "Cancel"
  static let videoDataOutputQueueLabel = "com.google.mlkit.visiondetector.VideoDataOutputQueue"
  static let sessionQueueLabel = "com.google.mlkit.visiondetector.SessionQueue"
  static let noResultsMessage = "No Results"
  static let localModelFile = (name: "bird", type: "tflite")
  static let labelConfidenceThreshold = 0.75
  static let smallDotRadius: CGFloat = 4.0
  static let lineWidth: CGFloat = 3.0
  static let originalScale: CGFloat = 1.0
  static let padding: CGFloat = 10.0
  static let resultsLabelHeight: CGFloat = 200.0
  static let resultsLabelLines = 5
  static let imageLabelResultFrameX = 0.4
  static let imageLabelResultFrameY = 0.1
  static let imageLabelResultFrameWidth = 0.5
  static let imageLabelResultFrameHeight = 0.8
  static let segmentationMaskAlpha: CGFloat = 0.5
}

public class UIUtilities {

  // MARK: - Public

  public static func addCircle(
    atPoint point: CGPoint,
    to view: UIView,
    color: UIColor,
    radius: CGFloat
  ) {
    let divisor: CGFloat = 2.0
    let xCoord = point.x - radius / divisor
    let yCoord = point.y - radius / divisor
    let circleRect = CGRect(x: xCoord, y: yCoord, width: radius, height: radius)
    guard circleRect.isValid() else { return }
    let circleView = UIView(frame: circleRect)
    circleView.layer.cornerRadius = radius / divisor
    circleView.alpha = Constants.circleViewAlpha
    circleView.backgroundColor = color
    circleView.isAccessibilityElement = true
    circleView.accessibilityIdentifier = Constants.circleViewIdentifier
    view.addSubview(circleView)
  }

  public static func addLineSegment(
    fromPoint: CGPoint, toPoint: CGPoint, inView: UIView, color: UIColor, width: CGFloat
  ) {
    let path = UIBezierPath()
    path.move(to: fromPoint)
    path.addLine(to: toPoint)
    let lineLayer = CAShapeLayer()
    lineLayer.path = path.cgPath
    lineLayer.strokeColor = color.cgColor
    lineLayer.fillColor = nil
    lineLayer.opacity = 1.0
    lineLayer.lineWidth = width
    let lineView = UIView()
    lineView.layer.addSublayer(lineLayer)
    lineView.isAccessibilityElement = true
    lineView.accessibilityIdentifier = Constants.lineViewIdentifier
    inView.addSubview(lineView)
  }

  public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor) {
    guard rectangle.isValid() else { return }
    let rectangleView = UIView(frame: rectangle)
    rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
    rectangleView.alpha = Constants.rectangleViewAlpha
    rectangleView.backgroundColor = color
    rectangleView.isAccessibilityElement = true
    rectangleView.accessibilityIdentifier = Constants.rectangleViewIdentifier
    view.addSubview(rectangleView)
  }

  public static func addShape(withPoints points: [NSValue]?, to view: UIView, color: UIColor) {
    guard let points = points else { return }
    let path = UIBezierPath()
    for (index, value) in points.enumerated() {
      let point = value.cgPointValue
      if index == 0 {
        path.move(to: point)
      } else {
        path.addLine(to: point)
      }
      if index == points.count - 1 {
        path.close()
      }
    }
    let shapeLayer = CAShapeLayer()
    shapeLayer.path = path.cgPath
    shapeLayer.fillColor = color.cgColor
    let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
    let shapeView = UIView(frame: rect)
    shapeView.alpha = Constants.shapeViewAlpha
    shapeView.layer.addSublayer(shapeLayer)
    view.addSubview(shapeView)
  }

  public static func imageOrientation(
    fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
  ) -> UIImage.Orientation {
    var deviceOrientation = UIDevice.current.orientation
    if deviceOrientation == .faceDown || deviceOrientation == .faceUp
      || deviceOrientation
        == .unknown
    {
      deviceOrientation = currentUIOrientation()
    }
    switch deviceOrientation {
    case .portrait:
      return devicePosition == .front ? .leftMirrored : .right
    case .landscapeLeft:
      return devicePosition == .front ? .downMirrored : .up
    case .portraitUpsideDown:
      return devicePosition == .front ? .rightMirrored : .left
    case .landscapeRight:
      return devicePosition == .front ? .upMirrored : .down
    case .faceDown, .faceUp, .unknown:
      return .up
    @unknown default:
      fatalError()
    }
  }

  /// Applies a segmentation mask to an image buffer by replacing colors in the segmented regions.
  ///
  /// @param The mask output from a segmentation operation.
  /// @param imageBuffer The image buffer on which segmentation was performed. Must have pixel
  ///     format type `kCVPixelFormatType_32BGRA`.
  /// @param backgroundColor Optional color to render into the background region (i.e. outside of
  ///    the segmented region of interest).
  /// @param foregroundColor Optional color to render into the foreground region (i.e. inside the
  ///     segmented region of interest).

  /// Converts an image buffer to a `UIImage`.
  ///
  /// @param imageBuffer The image buffer which should be converted.
  /// @param orientation The orientation already applied to the image.
  /// @return A new `UIImage` instance.
  public static func createUIImage(
    from imageBuffer: CVImageBuffer,
    orientation: UIImage.Orientation
  ) -> UIImage? {
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return UIImage(cgImage: cgImage, scale: Constants.originalScale, orientation: orientation)
  }

  /// Converts a `UIImage` to an image buffer.
  ///
  /// @param image The `UIImage` which should be converted.
  /// @return The image buffer. Callers own the returned buffer and are responsible for releasing it
  ///     when it is no longer needed. Additionally, the image orientation will not be accounted for
  ///     in the returned buffer, so callers must keep track of the orientation separately.
  public static func createImageBuffer(from image: UIImage) -> CVImageBuffer? {
    guard let cgImage = image.cgImage else { return nil }
    let width = cgImage.width
    let height = cgImage.height

    var buffer: CVPixelBuffer? = nil
    CVPixelBufferCreate(
      kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil,
      &buffer)
    guard let imageBuffer = buffer else { return nil }

    let flags = CVPixelBufferLockFlags(rawValue: 0)
    CVPixelBufferLockBaseAddress(imageBuffer, flags)
    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    let context = CGContext(
      data: baseAddress, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: bytesPerRow, space: colorSpace,
      bitmapInfo: (CGImageAlphaInfo.premultipliedFirst.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue))

    if let context = context {
      let rect = CGRect.init(x: 0, y: 0, width: width, height: height)
      context.draw(cgImage, in: rect)
      CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
      return imageBuffer
    } else {
      CVPixelBufferUnlockBaseAddress(imageBuffer, flags)
      return nil
    }
  }

  /// Creates a pose overlay view for visualizing a given `pose`.
  ///
  /// - Parameters:
  ///   - pose: The pose which will be visualized.
  ///   - bounds: The bounds of the view to which this overlay will be added. The overlay view's
  ///         bounds will match this value.
  ///   - lineWidth: The width of the lines connecting the landmark dots.
  ///   - dotRadius: The radius of the landmark dots.
  ///   - positionTransformationClosure: Closure which transforms a landmark `position` to the
  ///         `UIView` `CGPoint` coordinate where it should be shown on-screen.
  /// - Returns: The pose overlay view.
  public static func createPoseOverlayView(
    forPose pose: Pose, inViewWithBounds bounds: CGRect, lineWidth: CGFloat, dotRadius: CGFloat,
    positionTransformationClosure: (VisionPoint) -> CGPoint
  ) -> UIView {
    let overlayView = UIView(frame: bounds)

    let lowerBodyHeight: CGFloat =
      UIUtilities.distance(
        fromPoint: pose.landmark(ofType: PoseLandmarkType.leftAnkle).position,
        toPoint: pose.landmark(ofType: PoseLandmarkType.leftKnee).position)
      + UIUtilities.distance(
        fromPoint: pose.landmark(ofType: PoseLandmarkType.leftKnee).position,
        toPoint: pose.landmark(ofType: PoseLandmarkType.leftHip).position)

    // Pick arbitrary z extents to form a range of z values mapped to our colors. Red = close, blue
    // = far. Assume that the z values will roughly follow physical extents of the human body, but
    // apply an adjustment ratio to increase this color-coded z-range because this is not always the
    // case.
    let adjustmentRatio: CGFloat = 1.2
    let nearZExtent: CGFloat = -lowerBodyHeight * adjustmentRatio
    let farZExtent: CGFloat = lowerBodyHeight * adjustmentRatio
    let zColorRange: CGFloat = farZExtent - nearZExtent
    let nearZColor = UIColor.red
    let farZColor = UIColor.blue

    for (startLandmarkType, endLandmarkTypesArray) in UIUtilities.poseConnections() {
      let startLandmark = pose.landmark(ofType: startLandmarkType)
      for endLandmarkType in endLandmarkTypesArray {
        let endLandmark = pose.landmark(ofType: endLandmarkType)
        let startLandmarkPoint = positionTransformationClosure(startLandmark.position)
        let endLandmarkPoint = positionTransformationClosure(endLandmark.position)

        let landmarkZRatio = (startLandmark.position.z - nearZExtent) / zColorRange
        let connectedLandmarkZRatio = (endLandmark.position.z - nearZExtent) / zColorRange

        let startColor = UIUtilities.interpolatedColor(
          fromColor: nearZColor, toColor: farZColor, ratio: landmarkZRatio)
        let endColor = UIUtilities.interpolatedColor(
          fromColor: nearZColor, toColor: farZColor, ratio: connectedLandmarkZRatio)

        UIUtilities.addLineSegment(
          fromPoint: startLandmarkPoint,
          toPoint: endLandmarkPoint,
          inView: overlayView,
          colors: [startColor, endColor],
          width: lineWidth)
      }
    }
    for landmark in pose.landmarks {
      let landmarkPoint = positionTransformationClosure(landmark.position)
      UIUtilities.addCircle(
        atPoint: landmarkPoint,
        to: overlayView,
        color: UIColor.blue,
        radius: dotRadius
      )
    }
    return overlayView
  }

  /// Adds a gradient-colored line segment subview in a given `view`.
  ///
  /// - Parameters:
  ///   - fromPoint: The starting point of the line, in the view's coordinate space.
  ///   - toPoint: The end point of the line, in the view's coordinate space.
  ///   - inView: The view to which the line should be added as a subview.
  ///   - colors: The colors that the gradient should traverse over. Must be non-empty.
  ///   - width: The width of the line segment.
  private static func addLineSegment(
    fromPoint: CGPoint, toPoint: CGPoint, inView: UIView, colors: [UIColor], width: CGFloat
  ) {
    let viewWidth = inView.bounds.width
    let viewHeight = inView.bounds.height
    if viewWidth == 0.0 || viewHeight == 0.0 {
      return
    }
    let path = UIBezierPath()
    path.move(to: fromPoint)
    path.addLine(to: toPoint)
    let lineMaskLayer = CAShapeLayer()
    lineMaskLayer.path = path.cgPath
    lineMaskLayer.strokeColor = UIColor.black.cgColor
    lineMaskLayer.fillColor = nil
    lineMaskLayer.opacity = 1.0
    lineMaskLayer.lineWidth = width

    let gradientLayer = CAGradientLayer()
    gradientLayer.startPoint = CGPoint(x: fromPoint.x / viewWidth, y: fromPoint.y / viewHeight)
    gradientLayer.endPoint = CGPoint(x: toPoint.x / viewWidth, y: toPoint.y / viewHeight)
    gradientLayer.frame = inView.bounds
    var CGColors = [CGColor]()
    for color in colors {
      CGColors.append(color.cgColor)
    }
    if CGColors.count == 1 {
      // Single-colored lines must still supply a start and end color for the gradient layer to
      // render anything. Just add the single color to the colors list again to fulfill this
      // requirement.
      CGColors.append(colors[0].cgColor)
    }
    gradientLayer.colors = CGColors
    gradientLayer.mask = lineMaskLayer

    let lineView = UIView(frame: inView.bounds)
    lineView.layer.addSublayer(gradientLayer)
    lineView.isAccessibilityElement = true
    lineView.accessibilityIdentifier = Constants.lineViewIdentifier
    inView.addSubview(lineView)
  }

  /// Returns a color interpolated between to other colors.
  ///
  /// - Parameters:
  ///   - fromColor: The start color of the interpolation.
  ///   - toColor: The end color of the interpolation.
  ///   - ratio: The ratio in range [0, 1] by which the colors should be interpolated. Passing 0
  ///         results in `fromColor` and passing 1 results in `toColor`, whereas passing 0.5 results
  ///         in a color that is half-way between `fromColor` and `startColor`. Values are clamped
  ///         between 0 and 1.
  /// - Returns: The interpolated color.
  private static func interpolatedColor(
    fromColor: UIColor, toColor: UIColor, ratio: CGFloat
  ) -> UIColor {
    var fromR: CGFloat = 0
    var fromG: CGFloat = 0
    var fromB: CGFloat = 0
    var fromA: CGFloat = 0
    fromColor.getRed(&fromR, green: &fromG, blue: &fromB, alpha: &fromA)

    var toR: CGFloat = 0
    var toG: CGFloat = 0
    var toB: CGFloat = 0
    var toA: CGFloat = 0
    toColor.getRed(&toR, green: &toG, blue: &toB, alpha: &toA)

    let clampedRatio = max(0.0, min(ratio, 1.0))

    let interpolatedR = fromR + (toR - fromR) * clampedRatio
    let interpolatedG = fromG + (toG - fromG) * clampedRatio
    let interpolatedB = fromB + (toB - fromB) * clampedRatio
    let interpolatedA = fromA + (toA - fromA) * clampedRatio

    return UIColor(
      red: interpolatedR, green: interpolatedG, blue: interpolatedB, alpha: interpolatedA)
  }

  /// Returns the distance between two 3D points.
  ///
  /// - Parameters:
  ///   - fromPoint: The starting point.
  ///   - toPoint: The end point.
  /// - Returns: The distance.
  private static func distance(fromPoint: Vision3DPoint, toPoint: Vision3DPoint) -> CGFloat {
    let xDiff = fromPoint.x - toPoint.x
    let yDiff = fromPoint.y - toPoint.y
    let zDiff = fromPoint.z - toPoint.z
    return CGFloat(sqrt(xDiff * xDiff + yDiff * yDiff + zDiff * zDiff))
  }

  // MARK: - Private

  /// Returns the minimum subset of all connected pose landmarks. Each key represents a start
  /// landmark, and each value in the key's value array represents an end landmark which is
  /// connected to the start landmark. These connections may be used for visualizing the landmark
  /// positions on a pose object.
  private static func poseConnections() -> [PoseLandmarkType: [PoseLandmarkType]] {
    struct PoseConnectionsHolder {
      static var connections: [PoseLandmarkType: [PoseLandmarkType]] = [
        PoseLandmarkType.leftEar: [PoseLandmarkType.leftEyeOuter],
        PoseLandmarkType.leftEyeOuter: [PoseLandmarkType.leftEye],
        PoseLandmarkType.leftEye: [PoseLandmarkType.leftEyeInner],
        PoseLandmarkType.leftEyeInner: [PoseLandmarkType.nose],
        PoseLandmarkType.nose: [PoseLandmarkType.rightEyeInner],
        PoseLandmarkType.rightEyeInner: [PoseLandmarkType.rightEye],
        PoseLandmarkType.rightEye: [PoseLandmarkType.rightEyeOuter],
        PoseLandmarkType.rightEyeOuter: [PoseLandmarkType.rightEar],
        PoseLandmarkType.mouthLeft: [PoseLandmarkType.mouthRight],
        PoseLandmarkType.leftShoulder: [
          PoseLandmarkType.rightShoulder,
          PoseLandmarkType.leftHip,
        ],
        PoseLandmarkType.rightShoulder: [
          PoseLandmarkType.rightHip,
          PoseLandmarkType.rightElbow,
        ],
        PoseLandmarkType.rightWrist: [
          PoseLandmarkType.rightElbow,
          PoseLandmarkType.rightThumb,
          PoseLandmarkType.rightIndexFinger,
          PoseLandmarkType.rightPinkyFinger,
        ],
        PoseLandmarkType.leftHip: [PoseLandmarkType.rightHip, PoseLandmarkType.leftKnee],
        PoseLandmarkType.rightHip: [PoseLandmarkType.rightKnee],
        PoseLandmarkType.rightKnee: [PoseLandmarkType.rightAnkle],
        PoseLandmarkType.leftKnee: [PoseLandmarkType.leftAnkle],
        PoseLandmarkType.leftElbow: [PoseLandmarkType.leftShoulder],
        PoseLandmarkType.leftWrist: [
          PoseLandmarkType.leftElbow, PoseLandmarkType.leftThumb,
          PoseLandmarkType.leftIndexFinger,
          PoseLandmarkType.leftPinkyFinger,
        ],
        PoseLandmarkType.leftAnkle: [PoseLandmarkType.leftHeel, PoseLandmarkType.leftToe],
        PoseLandmarkType.rightAnkle: [PoseLandmarkType.rightHeel, PoseLandmarkType.rightToe],
        PoseLandmarkType.rightHeel: [PoseLandmarkType.rightToe],
        PoseLandmarkType.leftHeel: [PoseLandmarkType.leftToe],
        PoseLandmarkType.rightIndexFinger: [PoseLandmarkType.rightPinkyFinger],
        PoseLandmarkType.leftIndexFinger: [PoseLandmarkType.leftPinkyFinger],
      ]
    }
    return PoseConnectionsHolder.connections
  }

  private static func currentUIOrientation() -> UIDeviceOrientation {
    let deviceOrientation = { () -> UIDeviceOrientation in
      switch UIApplication.shared.statusBarOrientation {
      case .landscapeLeft:
        return .landscapeRight
      case .landscapeRight:
        return .landscapeLeft
      case .portraitUpsideDown:
        return .portraitUpsideDown
      case .portrait, .unknown:
        return .portrait
      @unknown default:
        fatalError()
      }
    }
    guard Thread.isMainThread else {
      var currentOrientation: UIDeviceOrientation = .portrait
      DispatchQueue.main.sync {
        currentOrientation = deviceOrientation()
      }
      return currentOrientation
    }
    return deviceOrientation()
  }
}

// MARK: - Constants

private enum Constants {
  static let circleViewAlpha: CGFloat = 0.7
  static let rectangleViewAlpha: CGFloat = 0.3
  static let shapeViewAlpha: CGFloat = 0.3
  static let rectangleViewCornerRadius: CGFloat = 10.0
  static let maxColorComponentValue: CGFloat = 255.0
  static let originalScale: CGFloat = 1.0
  static let bgraBytesPerPixel = 4
  static let circleViewIdentifier = "MLKit Circle View"
  static let lineViewIdentifier = "MLKit Line View"
  static let rectangleViewIdentifier = "MLKit Rectangle View"
}

// MARK: - Extension

extension CGRect {
  /// Returns a `Bool` indicating whether the rectangle's values are valid`.
  func isValid() -> Bool {
    return
      !(origin.x.isNaN || origin.y.isNaN || width.isNaN || height.isNaN || width < 0 || height < 0)
  }
}
