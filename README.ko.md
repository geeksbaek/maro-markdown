# Maro Markdown

[English](README.md) | 한국어

GitHub과 같은 방식으로 GitHub Flavored Markdown을 렌더링하는 macOS용 Markdown 편집기 겸 뷰어입니다. 한국어·일본어·중국어 입력과 표시를 세심하게 다룹니다.

- 편집, 나란히 보기, 미리보기 모드
- GitHub Flavored Markdown: 표, 작업 목록, 취소선, 자동 링크, 각주
- GitHub 알림 (`> [!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`)
- GitHub과 같은 제목 앵커 id를 만들어 `#제목` 링크가 그대로 동작
- GitHub의 Markdown 스타일시트, 라이트·다크 모드
- Finder Quick Look 미리보기: `.md` 파일을 선택하고 스페이스바를 누르면 렌더링된 화면으로 표시
- 모드를 바꾸거나 창을 닫을 때 입력기(한국어·일본어·중국어) 조합 중인 글자를 확정해 글자가 사라지지 않음
- 저장할 때 원래 인코딩 유지 (UTF-8, BOM 있는 UTF-8, UTF-16 LE/BE)

렌더링은 macOS에 들어 있는 `libcmark-gfm`으로 기기 안에서만 이루어집니다. 문서는 어디로도 전송되지 않습니다.

## 요구 사항

- macOS 27 이상 (시스템 `libcmark-gfm`을 사용)
- Apple Silicon (arm64)

## 설치

[Releases](https://github.com/geeksbaek/maro-markdown/releases)에서 `Maro-Markdown.zip`을 내려받아 압축을 풀고, `Maro Markdown.app`을 `/Applications`로 옮깁니다.

이 앱은 Apple Developer ID로 서명·공증되지 않았습니다. 그래서 처음 열 때 macOS가 "확인되지 않은 개발자" 경고를 띄우며 실행을 막습니다. 다음 중 하나로 여세요.

- Finder에서 앱을 **우클릭 → 열기**를 누르고, 경고 창에서 다시 **열기**를 누릅니다.
- 또는 터미널에서 다운로드 격리 표시를 지웁니다.

  ```sh
  xattr -dr com.apple.quarantine "/Applications/Maro Markdown.app"
  ```

`.md` 파일을 항상 Maro Markdown으로 열려면, Finder에서 Markdown 파일을 선택하고 **정보 가져오기 → 다음으로 열기 → Maro Markdown**을 고른 뒤 **모두 변경…**을 누릅니다.

설치 후에도 Quick Look이 원문 텍스트로 보이면 캐시를 초기화합니다.

```sh
qlmanage -r && qlmanage -r cache
```

그리고 **시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → Quick Look**에서 Maro Markdown이 켜져 있는지 확인합니다.

## 소스에서 빌드

Swift 6가 포함된 Xcode 명령줄 도구가 필요합니다.

```sh
MARO_BUILD_CONFIGURATION=release script/build_and_run.sh --build-only
ditto "dist/Maro Markdown.app" "/Applications/Maro Markdown.app"
```

스크립트는 SwiftPM으로 빌드하고, 앱 번들과 Quick Look 확장을 조립한 뒤 둘 다 ad hoc 서명합니다. `--build-only` 없이 실행하면 개발 빌드를 띄웁니다. 직접 빌드한 앱은 다운로드 격리 표시가 없어 위의 경고 없이 열립니다.

## 테스트

```sh
swift test
```

렌더러, GitHub 알림 변환, 제목 id(GitHub Markdown API에서 실측한 54개 사례 포함), 텍스트 인코딩, 편집기의 입력기 조합 처리, Quick Look 이미지 경로 처리를 검사합니다.

## 단축키

| 동작 | 단축키 |
| --- | --- |
| 굵게 | ⌘B |
| 기울임 | ⌘I |
| 인라인 코드 | ⌘E |
| 링크 | ⌘K |
| 제목 | ⌥⌘2 |
| 찾기 | ⌘F |

## GitHub과 다른 점

- 렌더링하지 않는 것: 코드 구문 강조, 수식, Mermaid 다이어그램, 이모지 단축어(`:smile:`), `#123`·`@user` 같은 GitHub 참조
- 원본 HTML은 렌더링하지 않습니다. GitHub이 허용하는 `<details>`, `<kbd>`도 마찬가지입니다.
- 알림 제목과 제목 링크에 Octicon 아이콘이 없습니다.

## 알려진 제한

- **Quick Look에서 상대 경로 이미지가 보이지 않습니다.** Quick Look 확장은 샌드박스 안에서 Markdown 파일 자체만 읽을 수 있어서, 옆에 있는 이미지(`![](images/a.png)`)는 스페이스바 미리보기에서 빈칸으로 나옵니다. 앱에서는 정상으로 보입니다.
- 4 MB보다 큰 파일은 Quick Look 미리보기에서 잘립니다.
- Developer ID 서명과 공증이 없습니다. 위의 설치 안내를 참고하세요.

## 라이선스

MIT. [LICENSE](LICENSE)를 참고하세요. 포함된 서드파티 코드와 라이선스는 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)에 있습니다.
