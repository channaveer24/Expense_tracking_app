package com.channaveer.expense_tracker

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode

/**
 * Transparent, lock-screen capable activity started by the Quick Settings
 * tile (or the launcher shortcut). It boots a separate Flutter engine on the
 * `quickVoiceMain` entrypoint which listens, parses, saves and closes itself
 * via SystemNavigator.pop().
 */
class QuickVoiceActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        super.onCreate(savedInstanceState)
    }

    override fun getDartEntrypointFunctionName(): String = "quickVoiceMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent
}
