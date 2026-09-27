#!/bin/bash
# 맥 한국인 필수 설정 — https://github.com/hanseolhui/mac-korean-essentials
# 포함: ① 오른쪽 ⌘ 한/영 전환  ② 마우스 휠 윈도우처럼 (트랙패드는 그대로)
#       ③ Finder 우클릭 '한글 파일명 윈도우용으로 정리' (자소 분리 해결)
#       ④ 톡톡: 트랙패드 TipTap으로 뒤로/앞으로 (https://github.com/hanseolhui/toktok)
#       ⑤ 맥북 기본 설정 (키보드·Finder·배터리 %·스크린샷, 되돌리기 파일 생성)
# 더블클릭으로 실행하세요. 다시 실행해도 안전합니다(중복 적용 안 됨).
#
# 테스트/자동화용 환경 변수:
#   MODULES=hanyoung,mouse,filename,toktok,basics  선택 창 없이 실행할 항목
#   SKIP_SYSTEM=1           앱 설치·시스템 설정은 건너뛰고 설정 파일만 수정
#   KARABINER_JSON, LINEARMOUSE_JSON, DEVICES_JSON, MOUSE_OPTS, SERVICES_DIR, BASICS_OPTS

set -u
KJSON="${KARABINER_JSON:-$HOME/.config/karabiner/karabiner.json}"
KAPP="/Applications/Karabiner-Elements.app"
KCLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
KLOG="/var/log/karabiner/core_service.log"
RULE_DESC="[한영키] Right Command alone -> F18 (macOS input source toggle)"
LMJSON="${LINEARMOUSE_JSON:-$HOME/.config/linearmouse/linearmouse.json}"
LMAPP="/Applications/LinearMouse.app"
SKIP="${SKIP_SYSTEM:-0}"
RAW="https://raw.githubusercontent.com/hanseolhui/mac-korean-essentials/main"
SERVICES="${SERVICES_DIR:-$HOME/Library/Services}"
WF_NAME="한글 파일명 윈도우용으로 정리.workflow"
WF_URL="quick-actions/%ED%95%9C%EA%B8%80%20%ED%8C%8C%EC%9D%BC%EB%AA%85%20%EC%9C%88%EB%8F%84%EC%9A%B0%EC%9A%A9%EC%9C%BC%EB%A1%9C%20%EC%A0%95%EB%A6%AC.workflow"
SRC_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

title() { printf "\n\033[1;36m▶ %s\033[0m\n" "$1"; }
ok()    { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn()  { printf "  \033[33m!\033[0m %s\n" "$1"; }
pause() { [ "$SKIP" = "1" ] || read -r -p "  $1 (Enter) " _; }
backup() { [ -f "$1" ] && cp "$1" "${1%.json}.backup-$(date +%Y%m%d-%H%M%S).json" && ok "기존 설정 백업 완료"; }

# brew로 cask 설치, brew가 없으면 다운로드 페이지 열기. 설치되면 0 반환
install_cask() { # $1=cask $2=app경로 $3=이름 $4=홈페이지
  if [ -d "$2" ]; then ok "$3 이미 설치되어 있음"; return 0; fi
  if command -v brew >/dev/null 2>&1; then
    echo "  Homebrew로 $3 설치 중… (맥 로그인 비밀번호를 물어볼 수 있어요)"
    brew install --cask "$1" && return 0
    warn "$3 설치 실패. $4 에서 직접 설치 후 다시 실행하세요."
  else
    warn "$3 가 없어요. 다운로드 페이지를 엽니다. 설치 후 이 설치기를 다시 실행하세요."
    open "$4"
  fi
  return 1
}

run_jxa() { # stdin=JXA 코드, 나머지 인자는 run(argv)로 전달
  local f; f=$(mktemp -t kressentials).js; cat > "$f"
  osascript -l JavaScript "$f" "$@" 2>&1; local rc=$?
  rm -f "$f"; return $rc
}

clear
echo "==============================================="
echo "   🇰🇷 맥 한국인 필수 설정"
echo "==============================================="

# ── 설치할 항목 선택 ─────────────────────────────────
if [ -z "${MODULES:-}" ]; then
  MODULES=$(run_jxa <<'JS'
function run(){
  const app = Application.currentApplication(); app.includeStandardAdditions = true;
  const items = ['⌨️  오른쪽 ⌘로 한/영 전환', '🖱  마우스 휠 윈도우처럼 (트랙패드는 그대로)',
                 '📁  한글 파일명 윈도우용으로 정리 (Finder 우클릭 메뉴 추가)',
                 '👆  톡톡: 중지 대고 검지 톡 = 뒤로, 검지 대고 중지 톡 = 앞으로',
                 '⚙️  맥북 기본 설정 (키보드·Finder·배터리 %·스크린샷)'];
  const keys  = ['hanyoung', 'mouse', 'filename', 'toktok', 'basics'];
  let r;
  try { r = app.chooseFromList(items, { withTitle:'맥 한국인 필수 설정',
        withPrompt:'적용할 항목을 고르세요. (⌘ 클릭으로 여러 개 선택)',
        defaultItems: items, multipleSelectionsAllowed:true, emptySelectionAllowed:false }); }
  catch(e) { r = false; }
  return (r || []).map(x => keys[items.indexOf(x)]).join(',');
}
JS
)
fi
[ -z "$MODULES" ] && { echo "  선택한 항목이 없어 종료합니다."; exit 0; }
has() { case ",$MODULES," in *",$1,"*) return 0;; esac; return 1; }

# ════════════════════════════════════════════════════
#  ① 오른쪽 ⌘ 한/영 전환 (Karabiner-Elements)
# ════════════════════════════════════════════════════
module_hanyoung() {
  echo; echo "━━━━━━━━ ⌨️  오른쪽 ⌘ 한/영 전환 ━━━━━━━━"

  if [ "$SKIP" != "1" ]; then
    title "Karabiner-Elements 확인"
    local fresh=0
    [ -d "$KAPP" ] || fresh=1
    install_cask karabiner-elements "$KAPP" "Karabiner-Elements" "https://karabiner-elements.pqrs.org" || return 1
    open -a "Karabiner-Elements"; sleep 3
    if [ "$fresh" = "1" ] || tail -5 "$KLOG" 2>/dev/null | grep -q "permissions are not granted"; then
      echo
      echo "  Karabiner 창의 안내에 따라 권한을 허용해 주세요:"
      echo "   • 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > 드라이버 확장 프로그램 허용"
      echo "   • 시스템 설정 > 개인정보 보호 및 보안 > 입력 모니터링 > Karabiner 항목 켜기"
      pause "모두 허용했으면"
    fi
    if tail -5 "$KLOG" 2>/dev/null | grep -q "permissions are not granted"; then
      warn "아직 권한이 허용되지 않은 것 같아요. 허용 후 이 설치기를 다시 실행하세요."
    else
      ok "Karabiner 동작 중"
    fi

    title "macOS 입력 소스 전환 단축키(F18) 설정"
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 61 \
      "<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>8388608</integer></array><key>type</key><string>standard</string></dict></dict>"
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u >/dev/null 2>&1
    ok "'입력 메뉴에서 다음 소스 선택' = F18"
    if defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | grep -q "inputmethod.Korean"; then
      ok "한국어 입력기 확인"
    else
      warn "한국어 입력기가 없어요. 시스템 설정 > 키보드 > 입력 소스에서 '한국어 - 2벌식'을 추가하세요."
    fi
  fi

  title "Karabiner 규칙 적용"
  local devices="[]"
  [ -x "$KCLI" ] && devices="$("$KCLI" --list-connected-devices 2>/dev/null || echo '[]')"
  devices="${DEVICES_JSON:-$devices}"
  mkdir -p "$(dirname "$KJSON")"; backup "$KJSON"

  local result
  result=$(run_jxa "$KJSON" "$devices" "$RULE_DESC" <<'JS'
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
)
  case "$result" in
    \{*) ok "오른쪽 ⌘ 단독 → 한/영 전환 규칙 적용"
         echo "$result" | grep -q '"added":\[\]' || ok "외장 키보드 적용: $(echo "$result" | sed -E 's/.*"added":\[([^]]*)\].*/\1/')" ;;
    *)   warn "설정 파일 수정 실패: $result"; return 1 ;;
  esac

  if [ "$SKIP" != "1" ]; then
    sleep 3
    grep "(grabbed)" "$KLOG" 2>/dev/null | tail -5 | sed -E 's/.*\] (.*) \(device_id.*/\1/' | sort -u |
      while read -r n; do ok "Karabiner가 처리 중인 키보드: $n"; done
  fi
  DONE_MSG="${DONE_MSG:-}\n • 오른쪽 ⌘를 한 번 눌러 한/영이 바뀌는지 확인 (새 외장 키보드를 연결하면 다시 실행)"
}

# ════════════════════════════════════════════════════
#  ② 마우스 휠 윈도우처럼 (LinearMouse)
# ════════════════════════════════════════════════════
module_mouse() {
  echo; echo "━━━━━━━━ 🖱  마우스 휠 윈도우처럼 ━━━━━━━━"
  echo "  macOS는 트랙패드와 마우스의 스크롤 방향을 따로 설정할 수 없어요."
  echo "  무료 오픈소스 앱 LinearMouse로 '마우스만' 윈도우처럼 바꿉니다."

  # 자연스러운 스크롤(트랙패드 기준)이 켜져 있어야 '마우스만 반대로'가 성립
  local natural
  natural=$(defaults read -g com.apple.swipescrolldirection 2>/dev/null || echo 1)

  local opts="${MOUSE_OPTS:-}"
  if [ -z "$opts" ]; then
    opts=$(run_jxa <<'JS'
function run(){
  const app = Application.currentApplication(); app.includeStandardAdditions = true;
  const items = ['휠 방향을 윈도우처럼 (아래로 굴리면 아래로)',
                 '휠 한 칸 = 3줄, 가속 없이 일정하게 (윈도우 기본값)',
                 '마우스 포인터 가속 끄기 (움직인 만큼만 이동, 게임·디자인용)'];
  const keys = ['reverse','lines','nopointeraccel'];
  let r;
  try { r = app.chooseFromList(items, { withTitle:'마우스 설정', withPrompt:'마우스에 적용할 설정을 고르세요. (트랙패드는 바뀌지 않아요)',
        defaultItems: items.slice(0,2), multipleSelectionsAllowed:true, emptySelectionAllowed:true }); }
  catch(e) { r = false; }
  return (r || []).map(x => keys[items.indexOf(x)]).join(',');
}
JS
)
  fi
  [ -z "$opts" ] && { warn "선택한 마우스 설정이 없어 건너뜁니다."; return 0; }

  if [ "$SKIP" != "1" ]; then
    title "LinearMouse 확인"
    install_cask linearmouse "$LMAPP" "LinearMouse" "https://linearmouse.app" || return 1
    if [ -d "/Applications/logioptionsplus.app" ] || [ -d "/Applications/Logi Options+.app" ]; then
      warn "Logi Options+ 가 설치되어 있어요. Logi Options+ 의 '스크롤 방향'/'부드러운 스크롤'이 켜져 있으면"
      warn "LinearMouse 와 겹칠 수 있으니, 이상하면 Logi Options+ 쪽 스크롤 설정을 기본값으로 두세요."
    fi
  fi

  title "마우스 설정 적용"
  mkdir -p "$(dirname "$LMJSON")"; backup "$LMJSON"
  local result
  result=$(run_jxa "$LMJSON" "$opts" "$natural" <<'JS'
ObjC.import('Foundation');
function readText(p){ const s=$.NSString.stringWithContentsOfFileEncodingError(p,$.NSUTF8StringEncoding,null); return s.isNil()?null:ObjC.unwrap(s); }
function writeText(p,t){ $(t).writeToFileAtomicallyEncodingError(p,true,$.NSUTF8StringEncoding,null); }
function run(argv){
  const [path, optsStr, natural] = argv; const opts = optsStr.split(',');
  const raw = readText(path);
  const c = raw && raw.trim() ? JSON.parse(raw) : {};
  c['$schema'] = c['$schema'] || 'https://app.linearmouse.org/schema/0.11.4';
  c.schemes = c.schemes || [];
  // "모든 마우스" 스킴을 찾아 갱신 (없으면 추가)
  const isMouseOnly = s => s.if && !Array.isArray(s.if) && JSON.stringify(s.if) === JSON.stringify({device:{category:'mouse'}});
  let s = c.schemes.find(isMouseOnly);
  if (!s) { s = {if:{device:{category:'mouse'}}}; c.schemes.push(s); }
  s.scrolling = s.scrolling || {};
  // 시스템의 '자연스러운 스크롤'이 켜져 있으면(기본값) 마우스만 뒤집어 윈도우 방향으로
  if (opts.includes('reverse')) s.scrolling.reverse = { vertical: natural !== '0', horizontal: natural !== '0' };
  if (opts.includes('lines'))   s.scrolling.distance = { vertical: '3' };
  if (opts.includes('nopointeraccel')) { s.pointer = s.pointer || {}; s.pointer.disableAcceleration = true; }
  writeText(path, JSON.stringify(c, null, 2));
  return 'ok';
}
JS
)
  [ "$result" = "ok" ] || { warn "설정 파일 수정 실패: $result"; return 1; }
  case ",$opts," in *",reverse,"*) ok "마우스 휠 방향: 윈도우처럼";; esac
  case ",$opts," in *",lines,"*)   ok "마우스 휠 한 칸 = 3줄";; esac
  case ",$opts," in *",nopointeraccel,"*) ok "마우스 포인터 가속 끔";; esac
  if [ "$natural" = "0" ]; then
    warn "지금 '자연스러운 스크롤'이 꺼져 있어서 트랙패드도 윈도우 방향이에요."
    warn "트랙패드를 맥 기본 방향으로 쓰려면: 시스템 설정 > 트랙패드 > 스크롤 및 확대/축소 > '자연스러운 스크롤' 켠 뒤 다시 실행하세요."
  fi

  if [ "$SKIP" != "1" ]; then
    osascript -e 'tell application "LinearMouse" to quit' >/dev/null 2>&1; sleep 1
    open -a "LinearMouse"
    osascript -e 'tell application "System Events" to if not (exists login item "LinearMouse") then make login item at end with properties {path:"/Applications/LinearMouse.app", hidden:true}' >/dev/null 2>&1 \
      && ok "로그인 시 LinearMouse 자동 실행" \
      || warn "자동 실행 등록 실패 — LinearMouse 메뉴바 아이콘 > 'Start at login'을 켜 주세요."
    echo
    echo "  처음이면 LinearMouse가 '손쉬운 사용' 권한을 요청해요:"
    echo "   • 시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 > LinearMouse 켜기"
    pause "허용했으면"
  fi
  DONE_MSG="${DONE_MSG:-}\n • 마우스 휠을 굴려 윈도우처럼 움직이는지 확인 (트랙패드는 그대로)"
}

# ════════════════════════════════════════════════════
#  ③ 한글 파일명 자소 분리 해결 (Finder 빠른 동작)
# ════════════════════════════════════════════════════
module_filename() {
  echo; echo "━━━━━━━━ 📁  한글 파일명 윈도우용으로 정리 ━━━━━━━━"
  echo "  맥에서 만든 한글 파일명은 윈도우에서 'ㅎㅏㄴㄱㅡㄹ'처럼 풀어져 보여요."
  echo "  Finder에서 우클릭 한 번으로 윈도우에서도 멀쩡한 이름으로 바꾸는 메뉴를 추가합니다."

  title "빠른 동작 설치"
  local dest="$SERVICES/$WF_NAME" tmp
  mkdir -p "$SERVICES"
  tmp=$(mktemp -d -t kressentials)
  if [ -d "$SRC_DIR/quick-actions/$WF_NAME" ]; then
    cp -R "$SRC_DIR/quick-actions/$WF_NAME" "$tmp/"
  else  # 한 줄 설치(curl)로 실행한 경우 GitHub에서 받기
    mkdir -p "$tmp/$WF_NAME/Contents"
    for f in Info.plist document.wflow; do
      curl -fsSL "$RAW/$WF_URL/Contents/$f" -o "$tmp/$WF_NAME/Contents/$f" || { warn "다운로드 실패: $f"; rm -rf "$tmp"; return 1; }
    done
  fi
  plutil -lint -s "$tmp/$WF_NAME/Contents/document.wflow" "$tmp/$WF_NAME/Contents/Info.plist" || { warn "파일이 손상됐어요. 다시 실행해 주세요."; rm -rf "$tmp"; return 1; }
  rm -rf "$dest"; mv "$tmp/$WF_NAME" "$dest"; rm -rf "$tmp"
  xattr -dr com.apple.quarantine "$dest" 2>/dev/null
  [ "$SKIP" = "1" ] || /System/Library/CoreServices/pbs -update >/dev/null 2>&1
  ok "Finder 우클릭 > 빠른 동작 > '한글 파일명 윈도우용으로 정리' 추가"
  DONE_MSG="${DONE_MSG:-}\n • 윈도우로 보낼 파일·폴더를 Finder에서 우클릭 > 빠른 동작 > '한글 파일명 윈도우용으로 정리'\n   (메뉴가 안 보이면 시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램 > Finder 에서 켜기)"
}

# ════════════════════════════════════════════════════
#  ④ 톡톡 (트랙패드 TipTap 뒤로/앞으로)
# ════════════════════════════════════════════════════
module_toktok() {
  echo; echo "━━━━━━━━ 👆  톡톡: 트랙패드로 뒤로/앞으로 ━━━━━━━━"
  echo "  오른손 중지를 대고 검지를 톡: 뒤로 / 검지를 대고 중지를 톡: 앞으로"
  echo "  애플 공증을 받은 톡톡 최신 버전을 받아 설치합니다."
  title "톡톡 설치"
  local script
  script=$(curl -fsSL "https://raw.githubusercontent.com/hanseolhui/toktok/main/install.sh") \
    || { warn "톡톡 설치 파일을 받지 못했어요. 인터넷 연결을 확인하고 다시 실행하세요."; return 1; }
  if [ "$SKIP" = "1" ]; then
    TOKTOK_NO_OPEN=1 bash -c "$script" || return 1
  else
    bash -c "$script" || return 1
    pause "손쉬운 사용 권한을 허용했으면"
  fi
  DONE_MSG="${DONE_MSG:-}\n • 중지 대고 검지 톡(뒤로) / 검지 대고 중지 톡(앞으로) 확인 (메뉴바 V 손가락 아이콘)"
}

# ════════════════════════════════════════════════════
#  ⑤ 맥북 기본 설정 (되돌리기 파일 생성)
# ════════════════════════════════════════════════════
RESTORE_DIR="$HOME/Library/Application Support/mac-korean-essentials"
RESTORE="$RESTORE_DIR/기본설정-되돌리기.command"

# 바꾸기 전 값을 되돌리기 파일에 기록 (처음 바꿀 때 한 번만 → 최초 원래 값 보존)
remember() { # $1=-currentHost 또는 "" $2=도메인 $3=키
  local host="$1" dom="$2" key="$3" t v flag
  grep -qF "# key: $host $dom $key" "$RESTORE" 2>/dev/null && return
  echo "# key: $host $dom $key" >> "$RESTORE"
  if t=$(defaults $host read-type "$dom" "$key" 2>/dev/null); then
    v=$(defaults $host read "$dom" "$key" 2>/dev/null)
    case "${t#Type is }" in
      boolean) flag=-bool; [ "$v" = "1" ] && v=true || v=false ;;
      integer) flag=-int ;; float) flag=-float ;; string) flag=-string ;;
      *) echo "# (복잡한 값이라 건너뜀)" >> "$RESTORE"; return ;;
    esac
    printf 'defaults %s write %q %q %s %q\n' "$host" "$dom" "$key" "$flag" "$v" >> "$RESTORE"
  else
    printf 'defaults %s delete %q %q 2>/dev/null\n' "$host" "$dom" "$key" >> "$RESTORE"
  fi
}
setp() { # $1=host $2=도메인 $3=키 $4=타입 $5=값
  remember "$1" "$2" "$3"
  defaults $1 write "$2" "$3" "$4" "$5"
}

module_basics() {
  echo; echo "━━━━━━━━ ⚙️  맥북 기본 설정 ━━━━━━━━"
  local opts="${BASICS_OPTS:-}"
  if [ -z "$opts" ]; then
    opts=$(run_jxa <<'JS'
function run(){
  const app = Application.currentApplication(); app.includeStandardAdditions = true;
  const items = [
    '⌨️ 키 반복 빠르게, 반복 지연 짧게 (다시 로그인하면 적용)',
    '⌨️ Tab 키로 모든 버튼 이동',
    '⌨️ 자동 수정·자동 대문자·스마트 따옴표 끄기',
    '📁 파일 확장자 항상 표시',
    '📁 Finder 경로 막대·상태 막대 표시',
    '📁 새 Finder 창을 ‘최근 항목’ 대신 다운로드 폴더로',
    '📁 Finder 검색 범위를 ‘현재 폴더’로',
    '🔋 메뉴바에 배터리 % 표시',
    '📸 스크린샷을 바탕화면 대신 사진 > 스크린샷 폴더에 저장'];
  const keys = ['keyrepeat','tabnav','autocorrect','extensions','pathbar','newwindow','searchscope','battery','screenshot'];
  let r;
  try { r = app.chooseFromList(items, { withTitle:'맥북 기본 설정',
        withPrompt:'적용할 설정을 고르세요. (⌘ 클릭으로 선택 해제)\n원래대로 돌리는 파일도 함께 만들어 드려요.',
        defaultItems: items, multipleSelectionsAllowed:true, emptySelectionAllowed:true }); }
  catch(e) { r = false; }
  return (r || []).map(x => keys[items.indexOf(x)]).join(',');
}
JS
)
  fi
  [ -z "$opts" ] && { warn "선택한 설정이 없어 건너뜁니다."; return 0; }
  on() { case ",$opts," in *",$1,"*) return 0;; esac; return 1; }

  mkdir -p "$RESTORE_DIR"
  if [ ! -f "$RESTORE" ]; then
    cat > "$RESTORE" <<'EOF'
#!/bin/bash
# 맥 한국인 필수 설정 — 기본 설정을 처음 적용하기 전 상태로 되돌립니다. 더블클릭으로 실행하세요.
EOF
    chmod +x "$RESTORE"
  fi
  # 되돌리기 명령은 마지막에 한 번 덧붙임 (재실행 시 중복 제거)
  sed -i '' '/^# --- 마무리 ---$/,$d' "$RESTORE"

  title "설정 적용"
  local G=NSGlobalDomain F=com.apple.finder
  if on keyrepeat; then
    setp "" $G KeyRepeat -int 2; setp "" $G InitialKeyRepeat -int 15
    ok "키 반복 빠르게 · 반복 지연 짧게 (다시 로그인하면 적용)"
  fi
  if on tabnav; then setp "" $G AppleKeyboardUIMode -int 2; ok "Tab 키로 모든 버튼 이동"; fi
  if on autocorrect; then
    setp "" $G NSAutomaticSpellingCorrectionEnabled -bool false
    setp "" $G WebAutomaticSpellingCorrectionEnabled -bool false
    setp "" $G NSAutomaticCapitalizationEnabled -bool false
    setp "" $G NSAutomaticQuoteSubstitutionEnabled -bool false
    ok "자동 수정 · 자동 대문자 · 스마트 따옴표 끔"
  fi
  if on extensions; then setp "" $G AppleShowAllExtensions -bool true; ok "파일 확장자 항상 표시"; fi
  if on pathbar; then setp "" $F ShowPathbar -bool true; setp "" $F ShowStatusBar -bool true; ok "경로 막대 · 상태 막대 표시"; fi
  if on newwindow; then
    setp "" $F NewWindowTarget -string PfLo
    setp "" $F NewWindowTargetPath -string "file://$HOME/Downloads/"
    ok "새 Finder 창 = 다운로드 폴더"
  fi
  if on searchscope; then setp "" $F FXDefaultSearchScope -string SCcf; ok "Finder 검색 범위 = 현재 폴더"; fi
  if on battery; then setp -currentHost com.apple.controlcenter BatteryShowPercentage -bool true; ok "메뉴바 배터리 % 표시"; fi
  if on screenshot; then
    local shots="$HOME/Pictures/스크린샷"
    mkdir -p "$shots"
    setp "" com.apple.screencapture location -string "$shots"
    ok "스크린샷 저장 위치 = 사진 > 스크린샷"
  fi

  cat >> "$RESTORE" <<'EOF'
# --- 마무리 ---
killall Finder SystemUIServer ControlCenter 2>/dev/null
echo "원래 설정으로 되돌렸어요. 키보드 설정은 다시 로그인하면 적용돼요."
EOF

  if [ "$SKIP" != "1" ]; then
    killall Finder SystemUIServer ControlCenter 2>/dev/null
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u >/dev/null 2>&1
  fi
  ok "되돌리기 파일: ~/Library/Application Support/mac-korean-essentials/기본설정-되돌리기.command"
  DONE_MSG="${DONE_MSG:-}\n • 기본 설정 적용 완료 (키보드 반복 속도는 다시 로그인하면 적용)\n   원래대로: ~/Library/Application Support/mac-korean-essentials/기본설정-되돌리기.command 더블클릭"
}

DONE_MSG=""
has hanyoung && module_hanyoung
has mouse    && module_mouse
has filename && module_filename
has toktok   && module_toktok
has basics   && module_basics

echo
echo "==============================================="
echo " 완료! 확인해 보세요:"
printf "%b\n" "$DONE_MSG"
echo
echo " 안 되면: 시스템 설정 > 개인정보 보호 및 보안에서"
echo "          입력 모니터링(Karabiner) / 손쉬운 사용(LinearMouse, TokTok) 권한 확인"
echo "==============================================="
pause "창을 닫으려면"
