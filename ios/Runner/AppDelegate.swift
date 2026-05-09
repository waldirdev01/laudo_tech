import Flutter
import UIKit
import PDFKit
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentInteractionControllerDelegate {
  private let PDF_CHANNEL = "laudo_tech/pdf"
  private let PHOTO_BACKUP_CHANNEL = "laudo_tech/photo_backup"
  private let FILE_OPEN_CHANNEL = "laudo_tech/file_open"
  private var documentInteractionController: UIDocumentInteractionController?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Configurar MethodChannel para extração de PDF
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    let channel = FlutterMethodChannel(
      name: PDF_CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "extractText" else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(
          code: "ARG_ERROR",
          message: "arguments required",
          details: nil
        ))
        return
      }
      
      // Suportar extração por path OU por bytes
      if let path = args["path"] as? String {
        self?.extractTextFromPDF(path: path, result: result)
      } else if let bytes = args["bytes"] as? FlutterStandardTypedData {
        self?.extractTextFromPDFBytes(bytes: bytes.data, result: result)
      } else {
        result(FlutterError(
          code: "ARG_ERROR",
          message: "path or bytes is required",
          details: nil
        ))
      }
    }

    let photoBackupChannel = FlutterMethodChannel(
      name: PHOTO_BACKUP_CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )

    photoBackupChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "saveToGallery" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(
          code: "ARG_ERROR",
          message: "path is required",
          details: nil
        ))
        return
      }

      self?.saveImageToGallery(path: path, result: result)
    }

    let fileOpenChannel = FlutterMethodChannel(
      name: FILE_OPEN_CHANNEL,
      binaryMessenger: controller.binaryMessenger
    )

    fileOpenChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "openFile" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(
          code: "ARG_ERROR",
          message: "path is required",
          details: nil
        ))
        return
      }

      DispatchQueue.main.async {
        result(self?.openFile(path: path) ?? false)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func extractTextFromPDF(path: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: path)
    
    // Verificar se o arquivo existe
    guard FileManager.default.fileExists(atPath: path) else {
      result(FlutterError(
        code: "NOT_FOUND",
        message: "File not found: \(path)",
        details: nil
      ))
      return
    }
    
    // Usar PDFKit para extrair texto
    guard let pdfDocument = PDFDocument(url: fileURL) else {
      result(FlutterError(
        code: "LOAD_ERROR",
        message: "Failed to load PDF from: \(path)",
        details: nil
      ))
      return
    }
    
    extractTextFromPDFDocument(pdfDocument: pdfDocument, result: result)
  }
  
  private func extractTextFromPDFBytes(bytes: Data, result: @escaping FlutterResult) {
    // Usar PDFKit para extrair texto a partir de bytes
    guard let pdfDocument = PDFDocument(data: bytes) else {
      result(FlutterError(
        code: "LOAD_ERROR",
        message: "Failed to load PDF from bytes",
        details: nil
      ))
      return
    }
    
    extractTextFromPDFDocument(pdfDocument: pdfDocument, result: result)
  }
  
  private func extractTextFromPDFDocument(pdfDocument: PDFDocument, result: @escaping FlutterResult) {
    var fullText = ""
    
    // Extrair texto de todas as páginas
    for pageIndex in 0..<pdfDocument.pageCount {
      if let page = pdfDocument.page(at: pageIndex),
         let pageText = page.string {
        fullText += pageText + "\n"
      }
    }
    
    if fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      result(FlutterError(
        code: "EMPTY_TEXT",
        message: "No text found in PDF",
        details: nil
      ))
      return
    }
    
    result(fullText)
  }

  private func saveImageToGallery(path: String, result: @escaping FlutterResult) {
    let fileURL = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: path) else {
      result(FlutterError(
        code: "NOT_FOUND",
        message: "File not found: \(path)",
        details: nil
      ))
      return
    }

    let save: () -> Void = {
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: fileURL)
      }) { success, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(
              code: "SAVE_ERROR",
              message: error.localizedDescription,
              details: nil
            ))
          } else {
            result(success)
          }
        }
      }
    }

    if #available(iOS 14, *) {
      PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        guard status == .authorized || status == .limited else {
          DispatchQueue.main.async { result(false) }
          return
        }
        save()
      }
    } else {
      PHPhotoLibrary.requestAuthorization { status in
        guard status == .authorized else {
          DispatchQueue.main.async { result(false) }
          return
        }
        save()
      }
    }
  }

  private func openFile(path: String) -> Bool {
    guard FileManager.default.fileExists(atPath: path) else {
      return false
    }

    guard let presenter = topViewController() else {
      return false
    }

    let fileURL = URL(fileURLWithPath: path)
    let controller = UIDocumentInteractionController(url: fileURL)
    controller.delegate = self
    controller.name = fileURL.lastPathComponent
    documentInteractionController = controller

    if controller.presentPreview(animated: true) {
      return true
    }

    let rect = presenter.view.bounds.insetBy(dx: presenter.view.bounds.midX, dy: presenter.view.bounds.midY)
    return controller.presentOptionsMenu(from: rect, in: presenter.view, animated: true)
  }

  private func topViewController(base: UIViewController? = nil) -> UIViewController? {
    let root = base ?? window?.rootViewController

    if let nav = root as? UINavigationController {
      return topViewController(base: nav.visibleViewController)
    }

    if let tab = root as? UITabBarController,
       let selected = tab.selectedViewController {
      return topViewController(base: selected)
    }

    if let presented = root?.presentedViewController {
      return topViewController(base: presented)
    }

    return root
  }

  func documentInteractionControllerViewControllerForPreview(
    _ controller: UIDocumentInteractionController
  ) -> UIViewController {
    topViewController() ?? window!.rootViewController!
  }
}
