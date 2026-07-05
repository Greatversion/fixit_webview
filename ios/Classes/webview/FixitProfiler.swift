import Foundation

/// Internal profiler for Fixit WebView startup milestones on iOS.
///
/// Milestone definitions:
///   T0 – Flutter widget inserted (tracked by Dart side, NOT this class)
///   T1 – PlatformView created (FixitWebViewFactory.create called)
///   T2 – Native WebView created (FixitWebView init block)
///   T3 – First frame drawn     (didStartProvisionalNavigation)
///   T4 – First meaningful progress (estimatedProgress >= 0.1)
///        ⚠️ This is a heuristic, NOT a true First Paint.
///   T5 – Page finished loading (didFinish navigation)
///
/// This is NOT part of the public SDK API.
class FixitProfiler {
    static let shared = FixitProfiler()
    
    private var milestones: [String: Int64] = [:]
    private let queue = DispatchQueue(label: "com.fixit.profiler", attributes: .concurrent)
    
    private init() {}
    
    func reset() {
        queue.async(flags: .barrier) {
            self.milestones.removeAll()
        }
    }
    
    private func mark(_ key: String) {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        queue.async(flags: .barrier) {
            if self.milestones[key] == nil {
                self.milestones[key] = nowMs
            }
        }
    }
    
    func markT1PlatformViewCreated() { mark("T1_platform_view_created") }
    func markT2NativeWebViewCreated() { mark("T2_native_webview_created") }
    func markT3FirstFrame() { mark("T3_first_frame") }
    func markT4FirstMeaningfulProgress() { mark("T4_first_meaningful_progress") }
    func markT5PageFinished() { mark("T5_page_finished") }
    
    func snapshotAsMap() -> [String: Int64] {
        var copy: [String: Int64] = [:]
        queue.sync {
            copy = self.milestones
        }
        return copy
    }
    
    func buildTimeline() -> String {
        let snap = snapshotAsMap()
        if snap.isEmpty { return "No milestones recorded." }
        
        guard let t1 = snap["T1_platform_view_created"] else {
            return "T1 not yet recorded."
        }
        
        var sb = "=== Fixit Startup Timeline (iOS) ===\n"
        sb += "T1 PlatformView created       : \(t1) ms (epoch)\n"
        
        let addDelta: (String, String) -> Void = { key, label in
            if let t = snap[key] {
                sb += "\(label) : +\(t - t1) ms from T1\n"
            }
        }
        
        addDelta("T2_native_webview_created",      "T2 Native WebView created    ")
        addDelta("T3_first_frame",                 "T3 First frame drawn         ")
        addDelta("T4_first_meaningful_progress",   "T4 First meaningful progress ⚠")
        addDelta("T5_page_finished",               "T5 Page finished             ")
        
        return sb
    }
}
