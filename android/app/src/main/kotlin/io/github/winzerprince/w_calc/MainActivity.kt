package io.github.winzerprince.w_calc

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Key-press vibration through the Vibrator service. Flutter's haptic call
/// asks for "touch feedback", which many phones ignore when that system
/// setting is off; a calculator key should always buzz when the app's own
/// vibration setting is on.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wcalc/haptics")
            .setMethodCallHandler { call, result ->
                if (call.method == "tick") {
                    result.success(tick())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)
                ?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }

    private fun tick(): Boolean {
        val v = vibrator() ?: return false
        if (!v.hasVibrator()) return false
        return try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                    v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ->
                    v.vibrate(VibrationEffect.createOneShot(18, VibrationEffect.DEFAULT_AMPLITUDE))
                else -> {
                    @Suppress("DEPRECATION")
                    v.vibrate(18)
                }
            }
            true
        } catch (e: SecurityException) {
            false
        }
    }
}
