package com.example.flutter_check_post

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.appcompat.app.AppCompatActivity

class CameraActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_camera)

        Handler(Looper.getMainLooper()).postDelayed(Runnable {
            Log.i("CustomTag", "loop got over")
            setResult(2)
            finish()
        }, 5000)
    }
}