import Flutter
import UIKit
import PDFKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let CHANNEL = "laudo_tech/pdf"
  
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
      name: CHANNEL,
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
}
