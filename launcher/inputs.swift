// 입력 소스 정리 도구 (설치 앱 안에 들어감 · install.command 가 부름)
//   ks-inputs list          → 전환되는 입력 소스 (id \t 이름)
//   ks-inputs fix           → 한국어 2벌식 · ABC 가 없으면 켜고, 나머지 키보드 입력 소스는 끔 (한/영만 오가게)
//   ks-inputs fix --add     → 없으면 켜기만 (나머지는 그대로)
// 시스템 설정을 열지 않고 바로 적용돼요 (TIS API)
import Carbon

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
default:
    print("사용법: ks-inputs list | fix [--add]")
    exit(1)
}
