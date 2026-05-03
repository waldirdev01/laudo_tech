package com.waldirdev01.laudo_tech

import android.content.ContentValues
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import androidx.core.view.WindowCompat
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
  private val PDF_CHANNEL = "laudo_tech/pdf"
  private val PHOTO_BACKUP_CHANNEL = "laudo_tech/photo_backup"

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    // Habilitar Edge-to-Edge para compatibilidade com Android 15+
    WindowCompat.setDecorFitsSystemWindows(window, false)
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Inicializar PDFBox (necessário para carregar recursos internos)
    PDFBoxResourceLoader.init(applicationContext)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PDF_CHANNEL)
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

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHOTO_BACKUP_CHANNEL)
      .setMethodCallHandler { call, result ->
        if (call.method != "saveToGallery") {
          result.notImplemented()
          return@setMethodCallHandler
        }

        try {
          val args = call.arguments as? Map<*, *>
          val path = args?.get("path") as? String
          if (path.isNullOrBlank()) {
            result.error("ARG_ERROR", "path is required", null)
            return@setMethodCallHandler
          }

          result.success(saveImageToGallery(path))
        } catch (e: Exception) {
          result.error("SAVE_ERROR", e.message, null)
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

  private fun saveImageToGallery(path: String): Boolean {
    val source = File(path)
    if (!source.exists()) return false

    val extension = source.extension.lowercase().ifBlank { "jpg" }
    val mimeType = when (extension) {
      "png" -> "image/png"
      "heic" -> "image/heic"
      "heif" -> "image/heif"
      "webp" -> "image/webp"
      else -> "image/jpeg"
    }
    val displayName = "LaudoTech_${System.currentTimeMillis()}.$extension"

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val values = ContentValues().apply {
        put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
        put(MediaStore.Images.Media.MIME_TYPE, mimeType)
        put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Laudo Tech")
        put(MediaStore.Images.Media.IS_PENDING, 1)
      }

      val resolver = applicationContext.contentResolver
      val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        ?: return false

      resolver.openOutputStream(uri)?.use { output ->
        FileInputStream(source).use { input -> input.copyTo(output) }
      } ?: return false

      values.clear()
      values.put(MediaStore.Images.Media.IS_PENDING, 0)
      resolver.update(uri, values, null, null)
      return true
    }

    @Suppress("DEPRECATION")
    val picturesDir = Environment.getExternalStoragePublicDirectory(
      Environment.DIRECTORY_PICTURES
    )
    val backupDir = File(picturesDir, "Laudo Tech")
    if (!backupDir.exists()) backupDir.mkdirs()
    val destination = File(backupDir, displayName)
    FileInputStream(source).use { input ->
      FileOutputStream(destination).use { output -> input.copyTo(output) }
    }
    return true
  }
}
