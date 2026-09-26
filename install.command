#!/bin/bash
# 맥 한국인 필수 설정 — https://github.com/hanseolhui/mac-korean-essentials
# 현재 포함: 우측 ⌘ 한/영 전환 (Karabiner-Elements + macOS 입력 소스 단축키 F18)
# 더블클릭으로 실행하세요. 다시 실행해도 안전합니다(중복 적용 안 됨).

set -u
KJSON="${KARABINER_JSON:-$HOME/.config/karabiner/karabiner.json}"
KAPP="/Applications/Karabiner-Elements.app"
KCLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
KLOG="/var/log/karabiner/core_service.log"
RULE_DESC="[한영키] Right Command alone -> F18 (macOS input source toggle)"

title() { printf "\n\033[1;36m▶ %s\033[0m\n" "$1"; }
ok()    { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn()  { printf "  \033[33m!\033[0m %s\n" "$1"; }
pause() { read -r -p "  $1 (Enter) " _; }

clear
echo "==============================================="
echo "   맥 한국인 필수 설정 — 우측 ⌘ 한/영 전환"
echo "==============================================="

if [ "${SKIP_SYSTEM:-0}" != "1" ]; then

# ── 1. Karabiner-Elements 설치 ─────────────────────────
title "1/4 Karabiner-Elements 확인"
FRESH=0
if [ -d "$KAPP" ]; then
  ok "이미 설치되어 있음 ($(defaults read "$KAPP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null))"
else
  FRESH=1
  if command -v brew >/dev/null 2>&1; then
    echo "  Homebrew로 설치합니다. 맥 로그인 비밀번호를 물어볼 수 있어요."
    brew install --cask karabiner-elements || { warn "설치 실패. https://karabiner-elements.pqrs.org 에서 직접 설치 후 다시 실행하세요."; exit 1; }
  else
    warn "Karabiner-Elements가 없습니다. 다운로드 페이지를 엽니다."
    echo "  설치를 마친 뒤 이 파일을 다시 더블클릭하세요."
    open "https://karabiner-elements.pqrs.org"
    exit 0
  fi
fi

open -a "Karabiner-Elements"
sleep 3
if [ "$FRESH" = "1" ] || tail -5 "$KLOG" 2>/dev/null | grep -q "permissions are not granted"; then
  echo
  echo "  Karabiner 창의 안내에 따라 권한을 허용해 주세요:"
  echo "   • 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 드라이버 확장 프로그램 허용"
  echo "   • 시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링 > Karabiner 항목 켜기"
  pause "모두 허용했으면"
fi
if tail -5 "$KLOG" 2>/dev/null | grep -q "permissions are not granted"; then
  warn "아직 권한이 허용되지 않은 것 같아요. 허용 후 이 파일을 다시 실행하세요."
else
  ok "Karabiner 동작 중"
fi

# ── 2. macOS 단축키: 다음 입력 소스 = F18 ───────────────
title "2/4 macOS 입력 소스 전환 단축키(F18) 설정"
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
  "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>8388608</integer></array><key>type</key><string>standard</string></dict></dict>"
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u >/dev/null 2>&1
ok "'입력 메뉴에서 다음 소스 선택' = F18"

if defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -q "inputmethod.Korean"; then
  ok "한국어 입력기 확인"
else
  warn "한국어 입력기가 없어요. 시스템 설정 > 키보드 > 입력 소스에서 '한국어 - 2벌식'을 추가하세요."
fi

fi # SKIP_SYSTEM

# ── 3. 외장 키보드 선택 ────────────────────────────────
title "3/4 외장 키보드 확인"
DEVICES="[]"
if [ -x "$KCLI" ]; then DEVICES="$("$KCLI" --list-connected-devices 2>/dev/null || echo '[]')"; fi
DEVICES="${DEVICES_JSON:-$DEVICES}"

# ── 4. karabiner.json 수정 (JXA, 추가 설치 불필요) ───────
title "4/4 Karabiner 규칙 적용"
mkdir -p "$(dirname "$KJSON")"
[ -f "$KJSON" ] && cp "$KJSON" "${KJSON%.json}.backup-$(date +%Y%m%d-%H%M%S).json" && ok "기존 설정 백업 완료"

JXA=$(mktemp -t hanyoung).js
cat > "$JXA" <<'JS'
ObjC.import('Foundation');
function readText(p){ const s=$.NSString.stringWithContentsOfFileEncodingError(p,$.NSUTF8StringEncoding,null); return s.isNil()?null:ObjC.unwrap(s); }
function writeText(p,t){ $(t).writeToFileAtomicallyEncodingError(p,true,$.NSUTF8StringEncoding,null); }
function sameIds(a,b){ const k=['vendor_id','product_id','is_keyboard','is_pointing_device']; return k.every(x=>(a[x]||false)===(b[x]||false)); }

function run(argv){
  const [path, devicesJson, desc] = argv;
  const app = Application.currentApplication(); app.includeStandardAdditions = true;
  const raw = readText(path);
  const c = raw ? JSON.parse(raw) : {global:{}, profiles:[{name:"Default profile", selected:true, virtual_hid_keyboard:{keyboard_type_v2:"ansi"}}]};
  c.global = c.global || {};
  c.global.enable_cgeventtap_fallback = false;   // 켜면 한영 반영 지연·키 반복 문제 발생
  const prof = c.profiles.find(p=>p.selected) || c.profiles[0];
  prof.selected = true;

  // 기존 right_command 단순 매핑 제거
  const dropRC = a => (a||[]).filter(m=>!(m.from && m.from.key_code==='right_command'));
  prof.simple_modifications = dropRC(prof.simple_modifications);
  prof.devices = prof.devices || [];
  prof.devices.forEach(d=>{ if (d.simple_modifications) d.simple_modifications = dropRC(d.simple_modifications); });

  // 한영 규칙 (재실행 시 교체)
  const cm = prof.complex_modifications = prof.complex_modifications || {};
  cm.rules = (cm.rules||[]).filter(r=>!(r.description||'').startsWith('[한영키]'));
  cm.rules.push({ description: desc, manipulators: [
    { type:'basic', from:{key_code:'right_command', modifiers:{optional:['any']}},
      to:[{key_code:'right_command', lazy:true}], to_if_alone:[{key_code:'f18'}] },
    { type:'basic', from:{key_code:'lang1', modifiers:{optional:['any']}}, to:[{key_code:'f18'}] }
  ]});

  // "키보드+포인팅" 으로 보고되는 외장 키보드는 기본적으로 Karabiner가 안 잡음 → 선택해서 강제 적용
  let devs = []; try { devs = JSON.parse(devicesJson); } catch(e) {}
  const cands = devs.filter(d=>!d.is_apple && d.device_identifiers && d.device_identifiers.is_keyboard
                              && d.device_identifiers.is_pointing_device && !d.device_identifiers.is_virtual_device);
  let added = [];
  if (cands.length) {
    const label = d => `${(d.product||'이름없음').trim()} (${d.manufacturer||'-'})`;
    const names = cands.map(label);
    let picked = false;
    try {
      picked = app.chooseFromList(names, {
        withTitle:'외장 키보드 선택',
        withPrompt:'한/영 전환을 적용할 외장 키보드를 고르세요.\n(마우스는 고르지 마세요. ⌘ 클릭으로 여러 개 선택)',
        defaultItems:names.filter(n=>!/mouse|mx master|trackball|마우스/i.test(n)),
        multipleSelectionsAllowed:true, emptySelectionAllowed:true });
    } catch(e) { picked = false; }
    (picked||[]).forEach(n=>{
      const d = cands[names.indexOf(n)]; const ids = d.device_identifiers;
      const id = {is_keyboard:true, is_pointing_device:true, vendor_id:ids.vendor_id, product_id:ids.product_id};
      prof.devices = prof.devices.filter(x=>!(x.identifiers && sameIds(x.identifiers,id)));
      prof.devices.push({identifiers:id, ignore:false});
      added.push(n);
    });
  }
  writeText(path, JSON.stringify(c, null, 4));
  return JSON.stringify({added, candidates:cands.length});
}
JS
RESULT=$(osascript -l JavaScript "$JXA" "$KJSON" "$DEVICES" "$RULE_DESC" 2>&1)
rm -f "$JXA"
case "$RESULT" in
  \{*) ok "우측 ⌘ 단독 → 한/영 전환 규칙 적용"
       echo "$RESULT" | grep -q '"added":\[\]' || ok "외장 키보드 적용: $(echo "$RESULT" | sed -E 's/.*"added":\[([^]]*)\].*/\1/')" ;;
  *)   warn "설정 파일 수정 실패: $RESULT"; exit 1 ;;
esac

if [ "${SKIP_SYSTEM:-0}" != "1" ]; then
  sleep 3
  GRAB=$(grep "(grabbed)" "$KLOG" 2>/dev/null | tail -5 | sed -E 's/.*\] (.*) \(device_id.*/\1/' | sort -u)
  [ -n "$GRAB" ] && echo "$GRAB" | while read -r n; do ok "Karabiner가 처리 중인 키보드: $n"; done
fi

echo
echo "==============================================="
echo " 완료! 우측 ⌘를 한 번 눌러 한/영이 바뀌는지 확인하세요."
echo " • 새 외장 키보드를 연결하면 이 파일을 다시 실행하세요."
echo " • 안 되면: 입력 모니터링에서 Karabiner 권한 확인"
echo "==============================================="
[ "${SKIP_SYSTEM:-0}" = "1" ] || pause "창을 닫으려면"
