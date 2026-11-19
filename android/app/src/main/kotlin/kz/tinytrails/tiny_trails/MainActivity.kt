package kz.tinytrails.tiny_trails

import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.Voice
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var textToSpeech: TextToSpeech? = null
    private var speechReady = false
    private var initializationFinished = false
    private var speechChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSpeech: PendingSpeech? = null
    private val pendingAvailability = mutableListOf<PendingAvailability>()

    private data class PendingSpeech(
        val text: String,
        val language: String,
        val result: MethodChannel.Result,
    )

    private data class PendingAvailability(
        val language: String,
        val result: MethodChannel.Result,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        textToSpeech = TextToSpeech(applicationContext) { status ->
            mainHandler.post {
                initializationFinished = true
                speechReady = status == TextToSpeech.SUCCESS
                pendingSpeech?.let { pending ->
                    pendingSpeech = null
                    pending.result.success(speak(pending.text, pending.language))
                }
                val availabilityRequests = pendingAvailability.toList()
                pendingAvailability.clear()
                availabilityRequests.forEach { pending ->
                    pending.result.success(offlineVoice(pending.language) != null)
                }
            }
        }
        speechChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tiny_trails/speech",
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                val language = call.argument<String>("language") ?: "ru"
                when (call.method) {
                    "isAvailable" -> {
                        if (initializationFinished) {
                            result.success(offlineVoice(language) != null)
                        } else {
                            // Checking during engine startup must not look like a missing voice.
                            if (pendingAvailability.size >= 8) {
                                pendingAvailability.removeAt(0).result.success(false)
                            }
                            val pending = PendingAvailability(language, result)
                            pendingAvailability.add(pending)
                            mainHandler.postDelayed({
                                if (pendingAvailability.remove(pending)) pending.result.success(false)
                            }, 4000)
                        }
                    }
                    "stop" -> {
                        finishPending(false)
                        textToSpeech?.stop()
                        result.success(true)
                    }
                    "speak" -> {
                        val text = call.argument<String>("text")
                        if (text.isNullOrBlank() || text.length > 1000 || language !in setOf("ru", "kk", "en")) {
                            result.success(false)
                        } else if (initializationFinished) {
                            result.success(speak(text, language))
                        } else {
                            finishPending(false)
                            val pending = PendingSpeech(text, language, result)
                            pendingSpeech = pending
                            mainHandler.postDelayed({
                                if (pendingSpeech === pending) finishPending(false)
                            }, 4000)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun offlineVoice(language: String): Voice? {
        if (!speechReady || language !in setOf("ru", "kk", "en")) return null
        val preferredLocale = when (language) {
            "ru" -> Locale.forLanguageTag("ru-RU")
            "kk" -> Locale.forLanguageTag("kk-KZ")
            else -> Locale.US
        }
        return try {
            textToSpeech?.voices
                ?.filter {
                    !it.isNetworkConnectionRequired && it.locale.language == language &&
                        !it.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)
                }
                ?.sortedWith(compareByDescending<Voice> { it.locale == preferredLocale }.thenByDescending { it.quality })
                ?.firstOrNull()
        } catch (_: RuntimeException) {
            // A missing or disabled system speech engine must never interrupt a game.
            null
        }
    }

    private fun speak(text: String, language: String): Boolean {
        val engine = textToSpeech ?: return false
        val voice = offlineVoice(language) ?: return false
        return try {
            if (engine.setVoice(voice) != TextToSpeech.SUCCESS) return false
            engine.setSpeechRate(0.85f)
            engine.setPitch(1.06f)
            engine.speak(text, TextToSpeech.QUEUE_FLUSH, null, "tiny-trails-instruction") == TextToSpeech.SUCCESS
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun finishPending(accepted: Boolean) {
        pendingSpeech?.result?.success(accepted)
        pendingSpeech = null
    }

    private fun finishAvailability() {
        pendingAvailability.forEach { it.result.success(false) }
        pendingAvailability.clear()
    }

    override fun onStop() {
        finishPending(false)
        finishAvailability()
        textToSpeech?.stop()
        super.onStop()
    }

    override fun onDestroy() {
        finishPending(false)
        finishAvailability()
        speechChannel?.setMethodCallHandler(null)
        mainHandler.removeCallbacksAndMessages(null)
        textToSpeech?.shutdown()
        textToSpeech = null
        super.onDestroy()
    }
}
