package com.example.mtg_lifecounter

import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * L'unica cosa che l'app chiede ad Android e' il suono di fine tempo: quello
 * delle sveglie di sistema, suonato sul canale delle sveglie (STREAM_ALARM),
 * cosi' si sente anche con i suoni dei media a zero.
 *
 * Il resto del contatore e' tutto in Dart.
 */
class MainActivity : FlutterActivity() {

    /** La sveglia in corso, se ce n'e' una: serve per poterla zittire. */
    private var alarm: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playAlarm" -> {
                        playAlarm()
                        result.success(null)
                    }

                    "stopAlarm" -> {
                        stopAlarm()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }

    /** Suona la sveglia una volta sola: non e' un allarme da dormirci sopra. */
    private fun playAlarm() {
        stopAlarm()
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: return
            val tone = RingtoneManager.getRingtone(applicationContext, uri)
                ?: return
            // Senza questo il suono uscirebbe dal canale dei media e basterebbe
            // abbassare il volume della musica per non sentirlo piu'.
            tone.audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            tone.play()
            alarm = tone
        } catch (_: Exception) {
            // Senza sveglia di sistema si resta senza suono: il tempo e'
            // comunque finito e il box lo dice.
        }
    }

    private fun stopAlarm() {
        try {
            alarm?.stop()
        } catch (_: Exception) {
            // Se non suonava piu' non c'e' niente da fare.
        }
        alarm = null
    }

    private companion object {
        const val CHANNEL = "mtg_lifecounter/alarm"
    }
}
