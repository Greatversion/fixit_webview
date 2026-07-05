package com.fixit.fixit_webview.webview

/**
 * Internal profiler for Fixit WebView startup milestones.
 *
 * Milestone definitions:
 *   T0 – Flutter widget inserted (tracked by Dart side, NOT this class)
 *   T1 – PlatformView created (FixitWebViewFactory.create called)
 *   T2 – Native WebView created (FixitWebView init block)
 *   T3 – First frame drawn     (onPageStarted fired)
 *   T4 – First meaningful progress (onProgressChanged >= 10%)
 *        ⚠️ This is a heuristic, NOT a true First Paint.
 *           Real FCP requires JavaScript injection (PerformanceObserver).
 *           Do NOT label this as "First Paint" in any user-facing output.
 *   T5 – Page finished loading (onPageFinished)
 *
 * This is NOT part of the public SDK API.
 * It is accessed only by FixitWebView internally, and results are
 * forwarded to the benchmark tool via the event channel when diagnostics
 * are enabled.
 */
internal object FixitProfiler {

    /** Epoch-relative wall-clock time at each milestone, in milliseconds. */
    private val milestones = mutableMapOf<String, Long>()

    /** Arbitrary named timers for measuring durations. */
    private val timers = mutableMapOf<String, Long>()

    // ── Milestone recording ────────────────────────────────────────────────

    fun markT1PlatformViewCreated() = mark("T1_platform_view_created")
    fun markT2NativeWebViewCreated() = mark("T2_native_webview_created")
    fun markT3FirstFrame() = mark("T3_first_frame")
    /** Records T4. Named 'first_meaningful_progress' to be honest about the heuristic. */
    fun markT4FirstMeaningfulProgress() = mark("T4_first_meaningful_progress")
    fun markT5PageFinished() = mark("T5_page_finished")

    private fun mark(key: String) {
        milestones[key] = System.currentTimeMillis()
    }

    // ── Duration timers ───────────────────────────────────────────────────

    fun startTimer(label: String) {
        timers[label] = System.nanoTime()
    }

    /** Returns elapsed time in milliseconds, or -1 if timer was not started. */
    fun stopTimer(label: String): Long {
        val start = timers.remove(label) ?: return -1L
        return (System.nanoTime() - start) / 1_000_000L
    }

    // ── Snapshot ──────────────────────────────────────────────────────────

    /**
     * Returns a snapshot of all recorded milestones as a Map<String, Long>
     * (wall-clock epoch ms). Safe to call at any time.
     */
    fun snapshot(): Map<String, Long> = milestones.toMap()

    /**
     * Returns a copy of the milestones as a Map<String, Long> that can be
     * serialised and sent to Dart so the controller can build typed
     * [StartupMilestone] objects.
     */
    fun snapshotAsLongMap(): Map<String, Long> = milestones.toMap()

    /**
     * Builds a human-readable benchmark timeline string.
     * T4 is labelled "First meaningful progress" — NOT "First Paint".
     */
    fun buildTimeline(): String {
        val snap = snapshot()
        if (snap.isEmpty()) return "No milestones recorded."
        val sb = StringBuilder("=== Fixit Startup Timeline ===\n")
        val t1 = snap["T1_platform_view_created"] ?: return "T1 not yet recorded."
        sb.append("T1 PlatformView created       : ${t1} ms (epoch)\n")
        fun delta(key: String, label: String) {
            snap[key]?.let { t -> sb.append("$label : +${t - t1} ms from T1\n") }
        }
        delta("T2_native_webview_created",      "T2 Native WebView created    ")
        delta("T3_first_frame",                 "T3 First frame drawn         ")
        delta("T4_first_meaningful_progress",   "T4 First meaningful progress ⚠")
        delta("T5_page_finished",               "T5 Page finished             ")
        return sb.toString()
    }

    fun reset() {
        milestones.clear()
        timers.clear()
    }
}
