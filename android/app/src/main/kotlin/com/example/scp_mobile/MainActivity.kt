package com.example.scp_mobile

import android.graphics.drawable.AnimationDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setBackgroundDrawableResource(R.drawable.launch_background)
        (window.decorView.background as? AnimationDrawable)?.start()
    }
}
