package com.kodetech.mobiboss

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class UssdAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "UssdAccessibility"
        private const val STEP_DELAY_MS = 500L

        var isServiceEnabled = false
            private set

        private val stepsQueue = mutableListOf<String>()
        private var isProcessingStep = false
        var onUssdCallback: ((rawResponse: String, isSuccess: Boolean) -> Unit)? = null

        fun startAutomation(steps: List<String>) {
            synchronized(stepsQueue) {
                stepsQueue.clear()
                stepsQueue.addAll(steps)
                isProcessingStep = false
                Log.d(TAG, "=== START AUTOMATION ===")
                Log.d(TAG, "Queued ${steps.size} steps: $steps")
            }
        }

        fun stopAutomation() {
            synchronized(stepsQueue) {
                stepsQueue.clear()
                isProcessingStep = false
                Log.d(TAG, "Automation stopped/cleared")
            }
        }

        fun hasActiveAutomation(): Boolean {
            synchronized(stepsQueue) {
                return stepsQueue.isNotEmpty()
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastProcessedDialogSignature = ""

    override fun onServiceConnected() {
        super.onServiceConnected()
        isServiceEnabled = true
        Log.d(TAG, "UssdAccessibilityService connected and ACTIVE")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            event.eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            return
        }

        val pkg = event.packageName?.toString() ?: ""
        Log.d(TAG, "Event: pkg=$pkg, type=${AccessibilityEvent.eventTypeToString(event.eventType)}")

        val rootNode = findUsableRootNode(event) ?: return

        try {
            val dialogText = extractAllText(rootNode)
            if (dialogText.isBlank()) return

            val lower = dialogText.lowercase().trim()
            Log.d(TAG, "Captured dialog text: '$dialogText'")

            // 1. Check if this is a transient loading / progress dialog ("USSD code running...")
            if (isProgressDialog(lower)) {
                Log.d(TAG, "Progress dialog detected ('$dialogText'). Waiting for actual menu...")
                return
            }

            // 2. Check for PIN prompt — stop automation to let user enter PIN manually
            if (isPinPrompt(lower)) {
                Log.d(TAG, "PIN prompt detected! Pausing automation for user input.")
                stopAutomation()
                return
            }

            // 3. Check for final telecom confirmation / result dialog
            if (isFinalConfirmation(lower)) {
                val isSuccess = !lower.contains("failed") &&
                        !lower.contains("invalid") &&
                        !lower.contains("insufficient") &&
                        !lower.contains("error") &&
                        !lower.contains("not successful")
                Log.d(TAG, "Final USSD response detected. Success=$isSuccess. Dispatching callback.")
                onUssdCallback?.invoke(dialogText, isSuccess)
                stopAutomation()
                lastProcessedDialogSignature = ""

                // Auto-dismiss the confirmation dialog
                handler.postDelayed({
                    try {
                        val currentRoot = findUsableRootNode(null) ?: return@postDelayed
                        val dismissBtn = findDismissButton(currentRoot)
                        dismissBtn?.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error dismissing final dialog", e)
                    }
                }, 800)
                return
            }

            // 4. Automation: Look for the input field (EditText or editable view)
            val inputField = findInputField(rootNode)
            if (inputField == null) {
                Log.d(TAG, "No input field in dialog yet. Waiting for interactive menu...")
                return
            }

            // If we already filled and submitted this exact dialog text, do not repeat
            val dialogSignature = "$dialogText|${inputField.hashCode()}"
            if (dialogSignature == lastProcessedDialogSignature) {
                Log.d(TAG, "Dialog signature already processed. Skipping duplicate event.")
                return
            }

            // Process the next step from stepsQueue
            synchronized(stepsQueue) {
                if (stepsQueue.isEmpty()) {
                    Log.d(TAG, "No more automation steps queued.")
                    return
                }

                if (isProcessingStep) {
                    Log.d(TAG, "Step already in progress, waiting...")
                    return
                }

                isProcessingStep = true
                val nextStep = stepsQueue[0]
                Log.d(TAG, "Next step to execute: '$nextStep' (remaining in queue: ${stepsQueue.size})")

                handler.postDelayed({
                    try {
                        val currentRoot = findUsableRootNode(null) ?: rootNode
                        val targetInput = findInputField(currentRoot) ?: inputField

                        // Focus input field
                        targetInput.performAction(AccessibilityNodeInfo.ACTION_FOCUS)

                        // Try ACTION_SET_TEXT
                        val arguments = Bundle()
                        arguments.putCharSequence(
                            AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                            nextStep
                        )
                        var setTextSuccess = targetInput.performAction(
                            AccessibilityNodeInfo.ACTION_SET_TEXT,
                            arguments
                        )
                        Log.d(TAG, "ACTION_SET_TEXT for '$nextStep' result: $setTextSuccess")

                        // Fallback: Clipboard + ACTION_PASTE if SET_TEXT returned false
                        if (!setTextSuccess) {
                            try {
                                val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                                val clip = ClipData.newPlainText("ussd_step", nextStep)
                                clipboard?.setPrimaryClip(clip)
                                setTextSuccess = targetInput.performAction(AccessibilityNodeInfo.ACTION_PASTE)
                                Log.d(TAG, "ACTION_PASTE fallback result: $setTextSuccess")
                            } catch (e: Exception) {
                                Log.e(TAG, "Paste fallback error", e)
                            }
                        }

                        // Delay slightly before clicking Send so the system registers the text
                        handler.postDelayed({
                            try {
                                val sendRoot = findUsableRootNode(null) ?: currentRoot
                                val sendButton = findSendButton(sendRoot)

                                if (sendButton != null) {
                                    val clickSuccess = sendButton.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                                    Log.d(TAG, "Send button clicked: success=$clickSuccess (text=${sendButton.text}, id=${sendButton.viewIdResourceName})")

                                    // Successfully submitted: consume this step and record signature
                                    synchronized(stepsQueue) {
                                        if (stepsQueue.isNotEmpty() && stepsQueue[0] == nextStep) {
                                            stepsQueue.removeAt(0)
                                            Log.d(TAG, "Step '$nextStep' CONSUMED. ${stepsQueue.size} steps remaining.")
                                        }
                                    }
                                    lastProcessedDialogSignature = dialogSignature
                                } else {
                                    Log.w(TAG, "Could not find send/reply button in dialog!")
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error clicking send button", e)
                            } finally {
                                isProcessingStep = false
                            }
                        }, 300)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error filling step text", e)
                        isProcessingStep = false
                    }
                }, STEP_DELAY_MS)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onAccessibilityEvent", e)
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "UssdAccessibilityService interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        isServiceEnabled = false
        stopAutomation()
        Log.d(TAG, "UssdAccessibilityService destroyed")
    }

    private fun findUsableRootNode(event: AccessibilityEvent?): AccessibilityNodeInfo? {
        val root = rootInActiveWindow
        if (root != null) return root

        if (event != null && event.source != null) {
            return event.source
        }

        try {
            for (window in windows) {
                val winRoot = window.root
                if (winRoot != null) return winRoot
            }
        } catch (_: Exception) {}

        return null
    }

    private fun isProgressDialog(lower: String): Boolean {
        return lower.contains("ussd code running") ||
                lower.contains("running ussd") ||
                lower.contains("please wait") ||
                lower.contains("loading") ||
                lower.contains("processing") ||
                lower.contains("sending")
    }

    private fun isPinPrompt(lowerText: String): Boolean {
        return lowerText.contains("enter pin") ||
                lowerText.contains("enter your pin") ||
                lowerText.contains("enter mm pin") ||
                lowerText.contains("enter momo pin") ||
                lowerText.contains("enter 4-digit") ||
                lowerText.contains("enter 4 digit") ||
                lowerText.contains("secret code") ||
                lowerText.contains("pin to confirm") ||
                lowerText.contains("enter your secret") ||
                lowerText.contains("enter mobile money pin")
    }

    private fun isFinalConfirmation(lowerText: String): Boolean {
        val hasConfirmationKeyword = lowerText.contains("payment made") ||
                lowerText.contains("payment received") ||
                lowerText.contains("transferred to") ||
                lowerText.contains("transaction id") ||
                lowerText.contains("current balance") ||
                lowerText.contains("available balance") ||
                lowerText.contains("successful") ||
                lowerText.contains("approved") ||
                lowerText.contains("failed") ||
                lowerText.contains("insufficient funds") ||
                lowerText.contains("transaction failed") ||
                lowerText.contains("not successful")

        val isNotMenuScreen = !lowerText.contains("1)") &&
                !lowerText.contains("2)") &&
                !lowerText.contains("1.") &&
                !lowerText.contains("2.") &&
                !lowerText.contains("enter ") &&
                !lowerText.contains("select ") &&
                !lowerText.contains("choose ")

        return hasConfirmationKeyword && isNotMenuScreen
    }

    private fun extractAllText(node: AccessibilityNodeInfo): String {
        val sb = StringBuilder()
        traverseNodes(node) { n ->
            if (n.className?.contains("TextView") == true && !n.text.isNullOrBlank()) {
                val t = n.text.toString().trim()
                val tLower = t.lowercase()
                if (tLower != "send" && tLower != "cancel" && tLower != "ok" &&
                    tLower != "reply" && tLower != "dismiss" && tLower != "close") {
                    sb.append(t).append(" ")
                }
            }
        }
        return sb.toString().trim()
    }

    private fun findInputField(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var result: AccessibilityNodeInfo? = null
        traverseNodes(node) { n ->
            if (result == null && (n.className?.contains("EditText") == true || n.isEditable)) {
                result = n
            }
        }
        return result
    }

    private fun findSendButton(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var result: AccessibilityNodeInfo? = null

        // 1. Text check: send / reply / ok / submit / continue
        traverseNodes(node) { n ->
            if (result == null && (n.className?.contains("Button") == true || n.isClickable)) {
                val text = n.text?.toString()?.lowercase()?.trim() ?: ""
                if (text == "send" || text == "reply" || text == "ok" ||
                    text == "submit" || text == "continue" || text == "yes") {
                    result = n
                }
            }
        }

        // 2. Resource ID check: button1, send, reply, positive
        if (result == null) {
            traverseNodes(node) { n ->
                if (result == null && n.isClickable) {
                    val resId = n.viewIdResourceName?.lowercase() ?: ""
                    if (resId.contains("button1") ||
                        resId.contains("send") ||
                        resId.contains("reply") ||
                        resId.contains("positive") ||
                        resId.contains("btn_ok")) {
                        result = n
                    }
                }
            }
        }

        // 3. Fallback: Any clickable button that is NOT Cancel / Dismiss
        if (result == null) {
            val nonCancelButtons = mutableListOf<AccessibilityNodeInfo>()
            traverseNodes(node) { n ->
                if (n.className?.contains("Button") == true && n.isClickable) {
                    val text = n.text?.toString()?.lowercase()?.trim() ?: ""
                    if (text != "cancel" && text != "dismiss" && text != "close") {
                        nonCancelButtons.add(n)
                    }
                }
            }
            if (nonCancelButtons.isNotEmpty()) {
                result = nonCancelButtons.last()
            }
        }

        return result
    }

    private fun findDismissButton(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var result: AccessibilityNodeInfo? = null
        traverseNodes(node) { n ->
            if (result == null && (n.className?.contains("Button") == true || n.isClickable)) {
                val text = n.text?.toString()?.lowercase()?.trim() ?: ""
                val resId = n.viewIdResourceName?.lowercase() ?: ""
                if (text == "ok" || text == "cancel" || text == "dismiss" || text == "close" ||
                    resId.contains("button2") || resId.contains("negative") || resId.contains("dismiss")) {
                    result = n
                }
            }
        }
        return result
    }

    private fun traverseNodes(node: AccessibilityNodeInfo?, visitor: (AccessibilityNodeInfo) -> Unit) {
        if (node == null) return
        visitor(node)
        for (i in 0 until node.childCount) {
            traverseNodes(node.getChild(i), visitor)
        }
    }
}
