# ⌘ 맥 한영키 원클릭 설정

**맥북 오른쪽 ⌘(Command) 키를 윈도우처럼 한/영 전환 키로.** 명령어 한 줄이면 설치 끝.

- 오른쪽 ⌘를 **혼자 누르면** → 한/영 전환 (누르자마자 바로 반영)
- 오른쪽 ⌘ + 다른 키 → 원래대로 ⌘ 조합 (⌘C, ⌘V, ⌘Tab 그대로)
- 한국어 자판 키보드의 **[한/영] 키**도 같은 동작
- **블루투스 외장 키보드**도 지원 (설치 중 목록에서 선택)
- 여러 번 실행해도 안전 (중복 적용 X, 기존 설정 자동 백업)

---

## 🚀 설치 (한 줄)

**터미널**(⌘ + Space → "터미널" 검색)을 열고 아래를 붙여넣은 뒤 Enter:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/hanseolhui/mac-hanyoung-key/main/install.command)"
```

화면 안내만 따라가면 끝납니다.

### 다른 방법: 파일 더블클릭

1. 이 페이지 위쪽 초록색 **Code → Download ZIP**
2. 압축 풀고 `install.command` 더블클릭
   - "확인되지 않은 개발자" 경고가 뜨면 **우클릭 → 열기 → 열기**
   - 그래도 막히면 시스템 설정 → 개인정보 보호 및 보안 → 맨 아래 **"그래도 열기"**

---

## 📋 설치 과정

| 단계 | 하는 일 | 내가 할 일 |
|---|---|---|
| 1 | [Karabiner-Elements](https://karabiner-elements.pqrs.org) 설치 확인·설치 (Homebrew 사용) | 처음이면 **권한 허용** (아래 참고) |
| 2 | macOS 단축키 "입력 메뉴에서 다음 소스 선택"을 F18로 설정 | 없음 |
| 3 | 연결된 외장 키보드 확인 | 목록에서 **키보드만** 선택 (마우스 제외) |
| 4 | Karabiner 규칙 적용 (오른쪽 ⌘ 단독 → F18) | 없음 |

### 처음 설치 시 권한 허용

Karabiner가 키 입력을 바꾸려면 두 가지 허용이 필요해요. Karabiner 창에도 안내가 나와요.

1. **시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → 드라이버 확장 프로그램** → Karabiner 켜기
2. **시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링** → `karabiner_grabber` / `Karabiner-Core-Service` 켜기

> Homebrew가 없으면 Karabiner 다운로드 페이지가 열려요. 설치 후 위 명령어를 다시 실행하세요.

---

## ❓ 문제 해결

**갑자기 안 돼요 (특히 macOS 업데이트 후)**
→ 입력 모니터링 권한이 풀린 경우가 대부분이에요. 시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링에서 Karabiner 항목을 껐다 켜세요.

**외장 키보드에서만 안 돼요**
→ 설치 명령을 다시 실행하고, 목록에서 그 키보드를 선택하세요. 일부 블루투스 키보드는 "키보드 + 포인팅 장치"로 인식되어 Karabiner가 기본적으로 건드리지 않거든요.

**한/영 말고 다른 언어로도 바뀌어요**
→ 입력 소스를 **ABC + 한국어 2벌식** 두 개만 남겨 두세요. (시스템 설정 → 키보드 → 입력 소스) 3개 이상이면 순서대로 돌아가요.

**전환은 되는데 반영이 늦어요**
→ 이 설치기는 macOS 기본 단축키(F18)를 거쳐 전환해서 바로 반영돼요. 예전에 Karabiner의 `select_input_source`나 `enable_cgeventtap_fallback`을 직접 설정했다면 이 설치기가 정리해 줍니다.

---

## 🔧 작동 원리

```
오른쪽 ⌘ (단독) ──Karabiner──▶ F18 ──macOS 단축키──▶ 다음 입력 소스 (한 ⇄ A)
```

- Karabiner가 입력 소스를 직접 바꾸면 메뉴바만 바뀌고 현재 창엔 늦게 반영되는 문제가 있어서, macOS 단축키로 넘겨 **즉시 반영**되게 했어요.
- 변경되는 파일: `~/.config/karabiner/karabiner.json` (백업: 같은 폴더 `karabiner.backup-날짜.json`), macOS 키보드 단축키 설정.

## 🗑 되돌리기

- Karabiner-Elements 앱 → **Complex Modifications**에서 `[한영키]` 규칙 삭제, 또는
- `~/.config/karabiner/`의 백업 파일로 `karabiner.json`을 교체, 또는
- Karabiner-Elements 앱 자체를 제거 (앱 메뉴 → Uninstall)

---

## 라이선스

MIT. 자유롭게 쓰고 고치고 공유하세요. 버그·제안은 [Issues](https://github.com/hanseolhui/mac-hanyoung-key/issues)로!
