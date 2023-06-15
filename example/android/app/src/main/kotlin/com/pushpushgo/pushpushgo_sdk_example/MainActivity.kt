package com.pushpushgo.pushpushgo_sdk_example

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import com.pushpushgo.pushpushgo_sdk.PushPushGoHelpers
import io.flutter.embedding.android.FlutterActivity


class MainActivity: FlutterActivity() {

    @RequiresApi(api = Build.VERSION_CODES.TIRAMISU)
    private fun requestNotificationsPermission() {
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf<String>(Manifest.permission.POST_NOTIFICATIONS),
                0
            )
        }
    }

   override fun onCreate(savedInstanceState: Bundle?) {
       super.onCreate(savedInstanceState)

       if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
           requestNotificationsPermission();
       }

       PushPushGoHelpers.onCreate(this.application, intent, savedInstanceState)
   }

    override fun onNewIntent(intent: Intent) {
       PushPushGoHelpers.onNewIntent(this.application, intent)
    }

}
