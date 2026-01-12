package com.waldirdev01.laudo_tech

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  private val CHANNEL = "laudo_tech/pdf"

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // Habilitar Edge-to-Edge para compatibilidade com Android 15+
    WindowCompat.setDecorFitsSystemWindows(window, false)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Inicializar PDFBox (necessário para carregar recursos internos)
    PDFBoxResourceLoader.init(applicationContext)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
      .setMethodCallHandler { call, result ->
        if (call.method != "extractText") {
          result.notImplemented()
          return@setMethodCallHandler
        }

        try {
          val args = call.arguments as? Map<*, *>
          val bytes = args?.get("bytes") as? ByteArray
          val path = args?.get("path") as? String

          val text = when {
            bytes != null -> extractTextFromBytes(bytes)
            !path.isNullOrBlank() -> extractTextFromPath(path)
            else -> null
          }

          if (text.isNullOrBlank()) {
            result.error("EMPTY_TEXT", "No text found in PDF", null)
          } else {
            result.success(text)
          }
        } catch (e: Exception) {
          result.error("EXTRACT_ERROR", e.message, null)
        }
      }
  }

  private fun extractTextFromPath(path: String): String? {
    val file = File(path)
    if (!file.exists()) return null
    PDDocument.load(file).use { doc ->
      val stripper = PDFTextStripper()
      return stripper.getText(doc)
    }
  }

  private fun extractTextFromBytes(bytes: ByteArray): String? {
    PDDocument.load(bytes).use { doc ->
      val stripper = PDFTextStripper()
      return stripper.getText(doc)
    }
  }
}
