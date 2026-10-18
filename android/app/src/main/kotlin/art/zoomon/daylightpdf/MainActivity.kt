package art.zoomon.daylightpdf

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 다른 앱이 PDF를 이 앱으로 열거나(VIEW) 공유하면(SEND) 그 파일을 앱 캐시로 복사해 Dart에 경로를 알려 준다.
 * 시작할 때 들어온 파일은 `initialFile`로, 앱이 떠 있을 때 들어온 파일은 `fileOpened` 호출로 넘긴다.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "art.zoomon.daylightpdf/incoming")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialFile" -> result.success(consume(intent))
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consume(intent)?.let { channel?.invokeMethod("fileOpened", it) }
    }

    /** [intent]에 PDF가 들어 있으면 캐시로 복사해 경로를 돌려준다. 같은 intent를 두 번 처리하지 않게 표시해 둔다. */
    private fun consume(intent: Intent?): String? {
        if (intent == null || intent.getBooleanExtra(HANDLED, false)) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return null
        intent.putExtra(HANDLED, true)
        return try {
            copyToCache(uri)
        } catch (e: Exception) {
            null
        }
    }

    private fun copyToCache(uri: Uri): String {
        val name = displayName(uri)
        val folder = File(cacheDir, "incoming/${System.currentTimeMillis()}").apply { mkdirs() }
        val target = File(folder, name)
        contentResolver.openInputStream(uri)!!.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        }
        return target.absolutePath
    }

    private fun displayName(uri: Uri): String {
        var name: String? = null
        if (uri.scheme == "content") {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst()) name = c.getString(0)
            }
        }
        val raw = (name ?: uri.lastPathSegment ?: "document.pdf").substringAfterLast('/')
        val safe = raw.replace(Regex("[\\\\:*?\"<>|]"), "_")
        return if (safe.lowercase().endsWith(".pdf")) safe else "$safe.pdf"
    }

    companion object {
        private const val HANDLED = "art.zoomon.daylightpdf.handled"
    }
}
