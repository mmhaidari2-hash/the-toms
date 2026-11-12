package app.thetoms.newlifeuk

import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/// Library "device voice": the phone's own TextToSpeech, used only for library books without recorded clips.
/// No permission, no key, no server of ours; started lazily on the first request and shut down with the activity.
class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: MethodChannel.Result? = null
    private var seq = 0
    private var waiting: MutableList<(Boolean) -> Unit>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "newlifeuk/tts").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> withTts { ok -> result.success(ok) }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val rate = (call.argument<Double>("rate") ?: 1.0).toFloat()
                    withTts { ok ->
                        if (!ok || text.isBlank()) {
                            result.success(false)
                        } else {
                            finishPending(false)
                            pending = result
                            val id = "nl${++seq}"
                            tts?.setSpeechRate(rate.coerceIn(0.5f, 2.0f))
                            if (tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, id) != TextToSpeech.SUCCESS) finishPending(false)
                        }
                    }
                }
                "stop" -> {
                    tts?.stop()
                    finishPending(false)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun finishPending(ok: Boolean) {
        val r = pending ?: return
        pending = null
        runOnUiThread { r.success(ok) }
    }

    private fun withTts(then: (Boolean) -> Unit) {
        waiting?.let { it.add(then); return }
        if (tts != null) {
            then(ready)
            return
        }
        waiting = mutableListOf(then)
        tts = TextToSpeech(this) { status ->
            ready = status == TextToSpeech.SUCCESS
            if (ready) {
                val r = tts?.setLanguage(Locale.UK)
                if (r == TextToSpeech.LANG_MISSING_DATA || r == TextToSpeech.LANG_NOT_SUPPORTED) {
                    ready = tts?.setLanguage(Locale.ENGLISH).let { it != TextToSpeech.LANG_MISSING_DATA && it != TextToSpeech.LANG_NOT_SUPPORTED }
                }
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String?) {}
                    override fun onDone(utteranceId: String?) { if (utteranceId == "nl$seq") finishPending(true) }
                    @Deprecated("Deprecated in Java")
                    override fun onError(utteranceId: String?) { finishPending(false) }
                    override fun onStop(utteranceId: String?, interrupted: Boolean) { finishPending(false) }
                })
            }
            val all = waiting ?: mutableListOf()
            waiting = null
            runOnUiThread { all.forEach { it(ready) } }
        }
    }

    override fun onDestroy() {
        finishPending(false)
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
