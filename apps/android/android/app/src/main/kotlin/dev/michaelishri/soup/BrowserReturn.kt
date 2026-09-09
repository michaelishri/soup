package dev.michaelishri.soup

/** Tracks our tab, including completion before Android has finished opening it. */
internal class BrowserReturn(private val bringSoupForward: () -> Unit) {
    private var active = false
    private var stopped = false
    private var returned = false
    private var returning = false
    private var completion: ((Boolean) -> Unit)? = null

    fun begin() {
        cancel()
        active = true
        stopped = false
        returned = false
        returning = false
    }

    fun requestReturn(callback: (Boolean) -> Unit) {
        if (!active) {
            callback(returned)
            return
        }
        check(completion == null)
        completion = callback
        returnIfReady()
    }

    fun onStopped() {
        if (!active) return
        stopped = true
        returnIfReady()
    }

    private fun returnIfReady() {
        if (!active || !stopped || completion == null || returning) return
        returning = true
        try {
            bringSoupForward()
        } catch (_: Exception) {
            cancel()
        }
    }

    fun onResumed() {
        if (!active || !stopped) return
        active = false
        returned = true
        val callback = completion
        completion = null
        callback?.invoke(true)
    }

    fun cancel() {
        active = false
        returned = false
        val callback = completion
        completion = null
        callback?.invoke(false)
    }
}
