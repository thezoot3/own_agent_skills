---
name: notion-formula-checker
description: "Run after uploading any math-formula-containing document to Notion. Fetches the uploaded page back, detects broken inline/block equations, and repairs them in-place via MCP. Must be called whenever the source .md file contained $...$ or $$...$$ notation."
allowed-tools:
  - Read
  - mcp__claude_ai_Notion__notion-fetch
  - mcp__claude_ai_Notion__notion-update-page
  - mcp__claude_ai_Notion__notion-update-data-source
---

## 역할

Notion에 수식이 포함된 문서를 업로드한 직후 호출하는 스킬.
업로드 과정에서 인라인·블록 수식이 깨지는 일이 자주 발생하므로,
**항상** 페이지 내용을 다시 조회하여 수식 상태를 검증하고 자동 수정한다.

---

## STEP 1 — 대상 페이지 특정

업로드 직후 알려진 정보에서 페이지 URL 또는 ID를 확인한다.

- Notion 페이지 URL 형식: `https://www.notion.so/<workspace>/<title>-<32자ID>`
- ID 추출: URL 맨 끝 32자 hex 문자열 (하이픈 제거 또는 포함 모두 허용)
- 업로더가 반환한 `page_id`가 있으면 그것을 그대로 사용한다.

---

## STEP 2 — 페이지 내용 조회

MCP 툴 `notion-fetch`로 업로드된 페이지의 마크다운 원문을 가져온다.

```
notion-fetch(url=<페이지 URL>)
```

- 반환된 마크다운 텍스트 전체를 이후 단계의 검사 대상으로 삼는다.
- `truncated: true`가 반환되면 페이지를 섹션으로 나눠 추가 조회한다.

---

## STEP 3 — 수식 깨짐 패턴 탐지

조회한 마크다운에서 아래 패턴을 순서대로 전부 검사한다.

### 패턴 A — 인라인 수식이 일반 텍스트로 노출

달러 기호가 텍스트로 그대로 보이는 경우.

| 깨진 형태 | 예시 |
|---|---|
| `$수식$` 전체가 일반 텍스트로 | `$x^2 + y^2 = r^2$` (수식 블록 아님) |
| 달러 기호가 이스케이프 | `\$x^2\$` |
| 달러 기호가 HTML 엔티티로 변환 | `&#36;x^2&#36;` |

→ 올바른 형태: Notion equation inline 블록 (`$x^2 + y^2 = r^2$`)

### 패턴 B — 인라인 수식이 블록 수식으로 승격

`$수식$`이 `$$\n수식\n$$` 블록으로 변환된 경우.

→ 원본 .md에서 해당 위치가 인라인이었는지 확인 후 롤백.

### 패턴 C — 블록 수식이 인라인으로 강등

`$$\n수식\n$$`이 `$수식$` 한 줄로 합쳐진 경우.

→ 원본 .md에서 해당 위치가 블록이었는지 확인 후 롤백.

### 패턴 D — LaTeX 명령어 이스케이프 손상

백슬래시가 이중 이스케이프되거나 제거된 경우.

| 깨진 형태 | 원래 의도 |
|---|---|
| `\\theta` | `\theta` |
| `theta` (백슬래시 탈락) | `\theta` |
| `\n` 가 개행으로 처리되어 수식 분리 | `\n` 리터럴 |

### 패턴 E — 수식이 코드 스팬으로 변환

인라인 수식이 `` `$x^2$` `` 처럼 백틱으로 감싸진 경우.

→ 백틱 제거 후 `$x^2$`로 교체.

### 패턴 F — 수식 내 특수문자 HTML 엔티티 변환

| 깨진 형태 | 원래 의도 |
|---|---|
| `&lt;` | `<` |
| `&gt;` | `>` |
| `&amp;` | `&` |
| `&#123;` | `{` |

---

## STEP 4 — 원본 .md 파일과 대조

탐지된 깨짐이 있으면, **원본 `.md` 파일을 `Read`로 열어** 해당 수식의 올바른 원문을 확인한다.

- 원본 파일 경로는 업로드 스킬이 선언한 파일명을 사용한다.
- 원본과 대조하여 **기대값(correct)**과 **실제값(broken)** 쌍을 목록으로 정리한다.

```
깨짐 목록:
  1. broken: `\theta`  → correct: `$\theta$`
  2. broken: `$$\nx^2\n$$`  → correct: `$x^2$`
  ...
```

깨짐이 0건이면 STEP 6으로 건너뛴다.

---

## STEP 5 — 수식 수정

깨짐 목록의 각 항목을 `notion-update-data-source`의 `update_content` 방식으로 하나씩 순차적으로 수정한다.

```json
{
  "type": "update_content",
  "update_content": {
    "content_updates": [
      {
        "old_str": "<깨진 원문 — 정확히 일치해야 함>",
        "new_str": "<올바른 수식 표기>"
      }
    ]
  }
}
```

### 수정 순칙

1. **한 번에 하나씩** 패치한다. 여러 수식을 배열에 묶어 한 번에 보내면 `old_str` 충돌 위험이 있다.
2. 각 패치 후 성공 여부(`validation_error` 없음)를 확인한 뒤 다음으로 넘어간다.
3. `old_str not found` 에러가 나면 — 공백·줄바꿈·이스케이프 차이를 의심하고 조회된 원문을 다시 복사하여 재시도한다.
4. 동일한 수식이 페이지에 여러 번 등장하면 `"replace_all_matches": true`를 추가한다.

---

## STEP 6 — 재검증

모든 패치 완료 후 `notion-fetch`로 페이지를 다시 조회하여 수식이 정상 렌더링되었는지 확인한다.

- 모든 `$...$` 구간이 equation inline 블록으로 파싱되는지 확인
- 모든 `$$\n...\n$$` 구간이 equation block으로 파싱되는지 확인
- 잔존 깨짐이 있으면 STEP 5로 돌아가 재수정

---

## STEP 7 — 완료 선언

```
✅ 수식 검증 완료

페이지: <Notion 페이지 URL>
수정된 수식: <N>건
  - $\theta$ (패턴 D — 백슬래시 손상)
  - $\frac{1}{2}$ (패턴 A — 텍스트 노출)
  ...
잔존 이상: 없음
```

수정 건수가 0이면:
```
✅ 수식 검증 완료 — 깨진 수식 없음
```

---

## 금지 행동

- ❌ STEP 2 조회 없이 "아마 괜찮을 것"으로 넘어가기
- ❌ 여러 수식 패치를 배열에 묶어 한 번에 전송 (충돌 위험)
- ❌ 원본 `.md` 파일 미확인 상태에서 수식 내용 임의 추측
- ❌ 재검증(STEP 6) 생략
