package com.example.androidApp

import android.app.Activity
import android.os.Bundle
import android.widget.TextView
import com.example.shared.Greeting

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val textView = TextView(this).apply {
            text = Greeting().greet()
            textSize = 24f
        }
        setContentView(textView)
    }
}
