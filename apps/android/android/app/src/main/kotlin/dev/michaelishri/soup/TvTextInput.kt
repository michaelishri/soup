package dev.michaelishri.soup

import android.app.Activity
import android.app.AlertDialog
import android.content.pm.PackageManager
import android.view.ContextThemeWrapper
import android.text.InputType
import android.view.View
import android.view.KeyEvent
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import android.widget.LinearLayout
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Own the TV editor and IME in one native window, outside Flutter key routing. */
class TvTextInput(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var dialog: AlertDialog? = null

    private val isTelevision: Boolean
        get() = activity.packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isTelevision" -> result.success(isTelevision)
            "dismiss" -> {
                dismiss()
                result.success(null)
            }
            "edit" -> {
                if (!isTelevision) {
                    result.error("not_television", "TV editing is unavailable on this device.", null)
                    return
                }
                if (dialog != null || activity.isFinishing || activity.isDestroyed) {
                    result.error("editor_unavailable", "The TV editor is already open or unavailable.", null)
                    return
                }
                showEditor(call, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun showEditor(call: MethodCall, result: MethodChannel.Result) {
        val label = call.argument<String>("label") ?: "Text"
        val password = call.argument<Boolean>("obscureText") == true
        val next = call.argument<Boolean>("next") == true
        val editorContext = ContextThemeWrapper(activity, R.style.TvTextInputTheme)
        var closeEditor: () -> Unit = {}
        val editor = object : EditText(editorContext) {
            override fun onKeyPreIme(keyCode: Int, event: KeyEvent): Boolean {
                if (keyCode == KeyEvent.KEYCODE_BACK) {
                    if (event.action == KeyEvent.ACTION_UP) closeEditor()
                    return true
                }
                return super.onKeyPreIme(keyCode, event)
            }
        }.apply {
            setSingleLine(true)
            inputType = InputType.TYPE_CLASS_TEXT or when {
                password -> InputType.TYPE_TEXT_VARIATION_PASSWORD
                call.argument<Boolean>("isUrl") == true -> InputType.TYPE_TEXT_VARIATION_URI
                else -> InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS
            }
            imeOptions = (if (next) EditorInfo.IME_ACTION_NEXT else EditorInfo.IME_ACTION_DONE) or
                EditorInfo.IME_FLAG_NO_EXTRACT_UI or EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO
            contentDescription = label
            hint = label
            setText(call.argument<String>("text") ?: "")
            setSelection(text.length)
        }
        val padding = (24 * activity.resources.displayMetrics.density).toInt()
        val container = LinearLayout(editorContext).apply {
            setPadding(padding, padding / 2, padding, 0)
            addView(editor, LinearLayout.LayoutParams(-1, -2))
        }
        var submitted = false
        val current = AlertDialog.Builder(editorContext)
            .setTitle(label)
            .setView(container)
            .setPositiveButton(if (next) "Next" else "Done") { _, _ -> submitted = true }
            .setNegativeButton("Back") { _, _ -> }
            .create()
        dialog = current
        closeEditor = { current.dismiss() }
        current.setOnDismissListener {
            if (dialog === current) dialog = null
            // Back preserves the draft, but never submits or changes the setup step.
            val text = editor.text.toString()
            editor.text.clear()
            result.success(mapOf("text" to text, "submitted" to submitted))
        }
        editor.setOnEditorActionListener { _, action, _ ->
            if (action == EditorInfo.IME_ACTION_DONE || action == EditorInfo.IME_ACTION_NEXT) {
                submitted = true
                current.dismiss()
                true
            } else {
                false
            }
        }
        current.setOnShowListener {
            editor.requestFocus()
            editor.post {
                if (current.isShowing) {
                    activity.getSystemService(InputMethodManager::class.java)
                        .showSoftInput(editor, InputMethodManager.SHOW_IMPLICIT)
                }
            }
        }
        current.window?.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        current.show()
    }

    fun dismiss() {
        dialog?.dismiss()
    }
}
