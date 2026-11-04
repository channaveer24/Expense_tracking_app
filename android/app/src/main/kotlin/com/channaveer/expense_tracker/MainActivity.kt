package com.channaveer.expense_tracker

import android.annotation.TargetApi
import android.app.StatusBarManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "expense_tracker/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestAddTile" -> requestAddTile(result)
                    "openVoiceSettings" -> {
                        openSettings(Settings.ACTION_VOICE_INPUT_SETTINGS)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Android 13+: system dialog "Add Log Expense tile to Quick Settings?" */
    private fun requestAddTile(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestAddTileApi33(result)
        } else {
            result.success("unsupported")
        }
    }

    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    private fun requestAddTileApi33(result: MethodChannel.Result) {
        val sbm = getSystemService(StatusBarManager::class.java)
        sbm.requestAddTileService(
            ComponentName(this, ExpenseTileService::class.java),
            "Log Expense",
            Icon.createWithResource(this, R.drawable.ic_tile_mic),
            mainExecutor,
        ) { code ->
            result.success(
                when (code) {
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ADDED -> "added"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_ALREADY_ADDED -> "exists"
                    StatusBarManager.TILE_ADD_REQUEST_RESULT_TILE_NOT_ADDED -> "declined"
                    else -> "unsupported"
                }
            )
        }
    }

    private fun openSettings(action: String) {
        try {
            startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }
}
