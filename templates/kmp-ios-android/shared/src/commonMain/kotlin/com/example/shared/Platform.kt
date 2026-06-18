package com.example.shared

interface Platform {
    val name: String
}

expect fun getPlatform(): Platform

class Greeting {
    private val platform = getPlatform()
    fun greet(): String = "Hello, ${platform.name}!"
}
