package com.example.common_com

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
	private val CHANNEL = "common_com/file_saver"
	private val CREATE_FILE_REQUEST_CODE = 1001

	private var pendingResult: MethodChannel.Result? = null
	private var pendingBase64: String? = null
	private var pendingMime: String? = null
	private var pendingFileName: String? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "saveFile") {
				val fileName = call.argument<String>("fileName")
				val bytes = call.argument<String>("bytes")
				val mime = call.argument<String>("mimeType") ?: "*/*"

				if (fileName == null || bytes == null) {
					result.error("INVALID_ARGS", "fileName or bytes missing", null)
					return@setMethodCallHandler
				}

				pendingResult = result
				pendingBase64 = bytes
				pendingMime = mime
				pendingFileName = fileName

				val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
					addCategory(Intent.CATEGORY_OPENABLE)
					type = mime
					putExtra(Intent.EXTRA_TITLE, fileName)
				}

				startActivityForResult(intent, CREATE_FILE_REQUEST_CODE)
			} else {
				result.notImplemented()
			}
		}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode == CREATE_FILE_REQUEST_CODE) {
			val result = pendingResult
			val base64 = pendingBase64
			pendingResult = null
			pendingBase64 = null

			if (resultCode == Activity.RESULT_OK && data != null && data.data != null) {
				val uri = data.data
				try {
					val out: OutputStream? = contentResolver.openOutputStream(uri!!)
					val decoded = Base64.decode(base64, Base64.DEFAULT)
					out?.write(decoded)
					out?.flush()
					out?.close()
					result?.success(uri.toString())
				} catch (e: Exception) {
					result?.error("SAVE_ERROR", e.localizedMessage, null)
				}
			} else {
				// User cancelled
				result?.success(null)
			}
		}
	}
}
