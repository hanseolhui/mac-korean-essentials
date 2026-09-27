// 맥 한국인 필수 설정 — 더블클릭하면 설치기를 터미널에서 실행하는 작은 앱
// 최신 설치기를 받아 쓰고, 인터넷이 안 되면 앱에 들어 있는 설치기를 씀
import Cocoa

let fm = FileManager.default
let work = fm.temporaryDirectory.appendingPathComponent("mac-korean-essentials-\(UUID().uuidString)")
try? fm.createDirectory(at: work, withIntermediateDirectories: true)

// 앱에 들어 있는 설치기 · 빠른 동작 복사
if let res = Bundle.main.resourceURL {
    for name in ["install.command", "quick-actions"] {
        let src = res.appendingPathComponent(name)
        if fm.fileExists(atPath: src.path) { try? fm.copyItem(at: src, to: work.appendingPathComponent(name)) }
    }
}
let script = work.appendingPathComponent("install.command")

// 최신 설치기로 바꿔 쓰기 (실패하면 앱에 들어 있는 것 그대로)
let latest = URL(string: "https://raw.githubusercontent.com/hanseolhui/mac-korean-essentials/main/install.command")!
let sem = DispatchSemaphore(value: 0)
URLSession.shared.dataTask(with: latest) { data, resp, _ in
    if let data, (resp as? HTTPURLResponse)?.statusCode == 200, data.starts(with: Array("#!/bin/bash".utf8)) {
        try? data.write(to: script)
    }
    sem.signal()
}.resume()
_ = sem.wait(timeout: .now() + 6)

try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
// 터미널에서 실행 (이 앱이 만든 파일이라 '확인되지 않은 개발자' 경고 없음)
let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
let config = NSWorkspace.OpenConfiguration(); config.activates = true
let done = DispatchSemaphore(value: 0)
NSWorkspace.shared.open([script], withApplicationAt: terminal, configuration: config) { _, error in
    if let error {
        let a = NSAlert(); a.messageText = "설치기를 열지 못했어요"; a.informativeText = error.localizedDescription; a.runModal()
    }
    done.signal()
}
_ = done.wait(timeout: .now() + 10)
