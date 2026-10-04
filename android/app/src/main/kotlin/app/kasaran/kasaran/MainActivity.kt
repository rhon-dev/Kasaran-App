package app.kasaran.kasaran

import android.app.KeyguardManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.kasaran/local_security")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasDeviceLock" -> {
                        val manager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        result.success(manager.isDeviceSecure)
                    }
                    "protectDirectory", "protectFile" -> {
                        val path = call.argument<String>("path")
                        if (path == null || !isPrivatePath(path) || !File(path).exists()) {
                            result.error("UNSAFE_PATH", "Local database path is not private", null)
                        } else {
                            // android:allowBackup=false excludes the whole app sandbox.
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isPrivatePath(path: String): Boolean {
        val canonical = File(path).canonicalFile
        val roots = listOf(filesDir.canonicalFile, noBackupFilesDir.canonicalFile)
        return roots.any { root -> canonical.path.startsWith(root.path + File.separator) || canonical == root }
    }
}
