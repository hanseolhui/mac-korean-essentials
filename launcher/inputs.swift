// 입력 소스 정리 도구 (설치 앱 안에 들어감 · install.command 가 부름)
//   ks-inputs list          → 전환되는 입력 소스 (id \t 이름)
//   ks-inputs fix           → 한국어 2벌식 · ABC 가 없으면 켜고, 나머지 키보드 입력 소스는 끔 (한/영만 오가게)
//   ks-inputs fix --add     → 없으면 켜기만 (나머지는 그대로)
//   ks-inputs current       → 지금 입력 소스 id
//   ks-inputs toggle        → 한국어면 ABC로, 아니면 한국어로 (다른 언어를 켜 둬도 한/영만)
//   ks-inputs daemon        → 「한/영만 고정」 도우미: F18(오른쪽 ⌘)을 누를 때마다 toggle — LaunchAgent 로 늘 켜 둠
//                             단축키 등록(RegisterEventHotKey)이라 손쉬운 사용 · 입력 모니터링 권한이 필요 없음
// 시스템 설정을 열지 않고 바로 적용돼요 (TIS API)
import Carbon
import AppKit

func sources(all: Bool) -> [TISInputSource] {
    let props = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String] as CFDictionary
    return (TISCreateInputSourceList(props, all)?.takeRetainedValue() as? [TISInputSource]) ?? []
}
func str(_ s: TISInputSource, _ key: CFString) -> String {
    guard let p = TISGetInputSourceProperty(s, key) else { return "" }
    return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
}
func bool(_ s: TISInputSource, _ key: CFString) -> Bool {
    guard let p = TISGetInputSourceProperty(s, key) else { return false }
    return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(p).takeUnretainedValue())
}
/// 한/영 전환에 끼는 것: 고를 수 있는 키보드 배열 · 입력 모드
func switchable() -> [TISInputSource] {
    sources(all: false).filter { bool($0, kTISPropertyInputSourceIsSelectCapable) && bool($0, kTISPropertyInputSourceIsEnabled) }
}
let id = { (s: TISInputSource) in str(s, kTISPropertyInputSourceID) }
let name = { (s: TISInputSource) in str(s, kTISPropertyLocalizedName) }
let isKorean = { (s: TISInputSource) in id(s).hasPrefix("com.apple.inputmethod.Korean.") }
let isLatin = { (s: TISInputSource) in str(s, kTISPropertyInputSourceType) == (kTISTypeKeyboardLayout as String) }

func enable(_ wanted: String) -> Bool {
    // 입력기(Korean) 자체와 그 안의 모드(2SetKorean)를 둘 다 켜야 전환 목록에 나옴
    var ok = false
    for s in sources(all: true) where id(s) == wanted || (wanted.hasPrefix(id(s) + ".") && !id(s).isEmpty) {
        if TISEnableInputSource(s) == noErr { ok = true }
    }
    return ok
}

/// 한국어 ↔ 영문만 오감. 영문은 ABC 먼저, 한국어는 2벌식 먼저 (켜져 있는 것 중에서)
func toggle() {
    let now = switchable()
    guard let cur = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
    let latin = now.first { id($0) == "com.apple.keylayout.ABC" } ?? now.first(where: isLatin)
    let korean = now.first { id($0) == "com.apple.inputmethod.Korean.2SetKorean" } ?? now.first(where: isKorean)
    guard let to = isKorean(cur) ? latin : korean else { return }
    TISSelectInputSource(to)
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "list":
    for s in switchable() { print("\(id(s))\t\(name(s))") }
case "fix":
    var done: [String] = []
    if !switchable().contains(where: isKorean), enable("com.apple.inputmethod.Korean.2SetKorean") { done.append("한국어 2벌식 켬") }
    if !switchable().contains(where: isLatin), enable("com.apple.keylayout.ABC") { done.append("ABC 켬") }
    if !args.contains("--add") {
        // 영문 배열 하나 · 한국어 하나만 남기고 끔 (ABC · 2벌식을 먼저 남김)
        let now = switchable()
        let keepLatin = now.first { id($0) == "com.apple.keylayout.ABC" } ?? now.first(where: isLatin)
        let keepKorean = now.first { id($0) == "com.apple.inputmethod.Korean.2SetKorean" } ?? now.first(where: isKorean)
        for s in now where s != keepLatin && s != keepKorean {
            if TISDisableInputSource(s) == noErr { done.append("\(name(s)) 끔") }
        }
    }
    let left = switchable().map(name)
    print((done.isEmpty ? "바꿀 것 없음" : done.joined(separator: " · ")) + "\t" + left.joined(separator: ", "))
case "current":
    if let cur = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() { print(id(cur)) }
case "toggle":
    toggle()
case "daemon":
    // F18 = 키코드 79 (오른쪽 ⌘ · [한/영] 키가 hidutil 로 바뀐 키), 수정키 없이
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)   // .prohibited 이면 단축키 이벤트가 안 옴
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        toggle()
        if ProcessInfo.processInfo.environment["KS_DEBUG"] != nil { print("toggle"); fflush(stdout) }
        return noErr
    }, 1, &spec, nil, nil)
    var ref: EventHotKeyRef?
    let hid = EventHotKeyID(signature: OSType(0x4B4F4B4F), id: 1)   // 'KOKO'
    guard RegisterEventHotKey(79, 0, hid, GetApplicationEventTarget(), 0, &ref) == noErr else {
        print("F18 단축키를 등록하지 못했어요"); exit(1)
    }
    app.run()
default:
    print("사용법: ks-inputs list | fix [--add] | current | toggle | daemon")
    exit(1)
}
