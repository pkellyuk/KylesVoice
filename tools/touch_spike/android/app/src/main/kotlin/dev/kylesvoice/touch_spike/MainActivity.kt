package dev.kylesvoice.touch_spike

import android.os.Build
import android.util.DisplayMetrics
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity for the touch-geometry spike.
 *
 * Exposes the display's true physical DPI to Dart. Flutter's devicePixelRatio
 * on Android is derived from the bucketed density (densityDpi / 160) rather
 * than the panel's actual pixel pitch, so it cannot be used to convert a
 * reported contact radius into millimetres. DisplayMetrics.xdpi / ydpi can.
 */
class MainActivity : FlutterActivity()
{
    companion object
    {
        private const val TAG = "touch_spike_native"
        private const val CHANNEL = "dev.kylesvoice.touch_spike/display"
        private const val METHOD_GET_METRICS = "getDisplayMetrics"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine)
    {
        Log.d(TAG, "ENTER configureFlutterEngine")

        super.configureFlutterEngine(flutterEngine)

        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val channel = MethodChannel(messenger, CHANNEL)

        // NOTE: the trailing lambda's brace must stay on this line. Kotlin parses
        // a brace on the following line as a property access, not a lambda, so
        // Allman bracing is not expressible here.
        channel.setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            handleMethodCall(call, result)
        }

        Log.d(TAG, "EXIT configureFlutterEngine | channel=$CHANNEL registered")
    }

    private fun handleMethodCall(call: MethodCall?, result: MethodChannel.Result?)
    {
        Log.d(TAG, "ENTER handleMethodCall | method=${call?.method}")

        if (result == null)
        {
            Log.w(TAG, "EXIT handleMethodCall | null result, nothing to reply to")
            return
        }

        if (call == null)
        {
            Log.w(TAG, "EXIT handleMethodCall | null call")
            result.error("null_call", "Method call was null", null)
            return
        }

        if (call.method != METHOD_GET_METRICS)
        {
            Log.w(TAG, "EXIT handleMethodCall | unimplemented method=${call.method}")
            result.notImplemented()
            return
        }

        val metrics = readDisplayMetrics()

        if (metrics == null)
        {
            Log.e(TAG, "EXIT handleMethodCall | could not read display metrics")
            result.error("no_metrics", "DisplayMetrics unavailable", null)
            return
        }

        val payload = mapOf(
            "xdpi" to metrics.xdpi,
            "ydpi" to metrics.ydpi,
            "densityDpi" to metrics.densityDpi,
            "density" to metrics.density,
            "widthPixels" to metrics.widthPixels,
            "heightPixels" to metrics.heightPixels,
            "model" to Build.MODEL,
            "manufacturer" to Build.MANUFACTURER,
            "sdkInt" to Build.VERSION.SDK_INT
        )

        Log.d(
            TAG,
            "STEP handleMethodCall | xdpi=${metrics.xdpi} ydpi=${metrics.ydpi} " +
                "densityDpi=${metrics.densityDpi} density=${metrics.density} " +
                "pixels=${metrics.widthPixels}x${metrics.heightPixels} " +
                "device=${Build.MANUFACTURER} ${Build.MODEL} sdk=${Build.VERSION.SDK_INT}"
        )

        result.success(payload)

        Log.d(TAG, "EXIT handleMethodCall | replied with ${payload.size} fields")
    }

    /**
     * Reads display metrics, preferring the real (full-screen) metrics so that
     * system bars do not shrink the reported pixel dimensions.
     *
     * Returns null only if the platform gives us nothing at all.
     */
    private fun readDisplayMetrics(): DisplayMetrics?
    {
        Log.d(TAG, "ENTER readDisplayMetrics")

        // Start from the resource metrics: these always carry xdpi / ydpi, which
        // are the fields the calibration actually depends on.
        val metrics = DisplayMetrics()
        val resourceMetrics = resources?.displayMetrics

        if (resourceMetrics == null)
        {
            Log.e(TAG, "EXIT readDisplayMetrics | resources.displayMetrics was null")
            return null
        }

        metrics.setTo(resourceMetrics)

        val realMetrics = readRealMetrics()

        if (realMetrics == null)
        {
            Log.w(TAG, "STEP readDisplayMetrics | real metrics unavailable, using resource metrics")
            Log.d(TAG, "EXIT readDisplayMetrics | source=resources")
            return metrics
        }

        // Prefer the real pixel dimensions, but keep the resource xdpi / ydpi if
        // the real metrics report nothing usable for them.
        metrics.widthPixels = realMetrics.widthPixels
        metrics.heightPixels = realMetrics.heightPixels

        if (realMetrics.xdpi > 0f)
        {
            metrics.xdpi = realMetrics.xdpi
        }

        if (realMetrics.ydpi > 0f)
        {
            metrics.ydpi = realMetrics.ydpi
        }

        Log.d(TAG, "EXIT readDisplayMetrics | source=real")
        return metrics
    }

    @Suppress("DEPRECATION")
    private fun readRealMetrics(): DisplayMetrics?
    {
        Log.d(TAG, "ENTER readRealMetrics")

        try
        {
            val target = DisplayMetrics()

            val activeDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R)
            {
                display
            }
            else
            {
                windowManager?.defaultDisplay
            }

            if (activeDisplay == null)
            {
                Log.w(TAG, "EXIT readRealMetrics | no display available")
                return null
            }

            activeDisplay.getRealMetrics(target)

            Log.d(TAG, "EXIT readRealMetrics | ${target.widthPixels}x${target.heightPixels}")
            return target
        }
        catch (e: Exception)
        {
            Log.e(TAG, "EXIT readRealMetrics | failed: ${e.message}", e)
            return null
        }
    }
}
