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

---

## Notion 인라인 수식 깨짐 예방 가이드

업로드 전 단계에서 아래 기준을 지키면 수식 깨짐을 크게 줄일 수 있다.

### 핵심 원칙

- Notion 인라인 수식은 `코드`가 아니라 `수식`이다. 빨간 하이라이트가 뜨면 수식이 아니라 코드로 들어간 것이다.
- 수식 안 내용은 "영어 단어"가 아니라 "LaTeX 명령"으로 작성해야 한다.
- 설명 문장과 수식은 분리하는 것이 가장 안전하다. 긴 설명을 수식 안에 억지로 넣지 않는다.
- 짧은 식만 인라인으로 넣고, 너무 길면 수식 블록으로 빼는 것이 안전하다.

### Notion에서 직접 입력할 때

- 인라인 수식 기능으로 입력한다. 일반 텍스트에 백틱으로 감싸지 않는다.
- 수식 칸 안에는 순수 LaTeX만 넣는다.
- `theta`, `pi`, `infinity`처럼 그냥 영어로 쓰지 않는다.
- 함수 이름도 LaTeX 함수형으로 쓴다. `sin x`보다 `\sin x`, `cosh x`보다 `\cosh x`가 안전하다.

### 자주 깨지는 표기 — 자동 치환 대상

| 잘못된 표기 | 올바른 LaTeX |
|---|---|
| `theta` | `\theta` |
| `pi` | `\pi` |
| `infinity` | `\infty` |
| `epsilon`, `delta` | `\varepsilon`, `\delta` |
| `sin x`, `cos x`, `tan x` | `\sin x`, `\cos x`, `\tan x` |
| `sinh x`, `cosh x`, `tanh x` | `\sinh x`, `\cosh x`, `\tanh x` |
| `sqrt(x+1)` | `\sqrt{x+1}` |
| `a/b` | `\frac{a}{b}` |
| `->` | `\to` |
| `=>` | `\Rightarrow` |
| `<=`, `>=`, `!=` | `\le`, `\ge`, `\ne` |
| `approx` | `\approx` |
| `x2`, `a1` | `x_2`, `a_1` |
| `x^sqrt(x)` | `x^{\sqrt{x}}` |
| `f^-1(x)` | `f^{-1}(x)` |

### Notion에서 안전한 작성 습관

- 한 인라인 수식에는 한 개념만 넣는다.
- 한국어 설명은 수식 밖에 두고, 수식 안에는 식만 넣는다.
- 꼭 필요한 짧은 텍스트만 `\text{...}`로 넣는다.
- 괄호가 복잡하면 `{}`를 충분히 써서 묶는다.
- 위첨자, 아래첨자가 2글자 이상이면 반드시 중괄호를 쓴다.
- 절댓값은 `|x|`, 벡터/사영은 `\cdot`, `\mathrm{proj}`처럼 표준형으로 쓴다.

### 쌍곡함수 주의사항

- `coshx`, `sinhx`처럼 붙여 쓰지 말고 `\cosh x`, `\sinh x`로 쓴다.
- 항등식: `\cosh^2 x - \sinh^2 x = 1`
- 미분: `(\sinh x)' = \cosh x`, `(\cosh x)' = \sinh x`
- 영어 철자를 그대로 두면 기호가 아니라 문자로 렌더링될 가능성이 크다.

### 업로드 전 자체 검수 체크리스트

- [ ] 백틱이 수식에 잘못 들어가 있지 않은가
- [ ] `theta/pi/infinity/sqrt/approx` 같은 영어 토큰이 남아 있지 않은가
- [ ] `sin cos tan sinh cosh ln lim sum int`에 역슬래시가 붙어 있는가
- [ ] `^`, `_` 뒤에 중괄호가 필요한데 빠지지 않았는가
- [ ] 긴 설명 문장이 수식 안으로 들어가지 않았는가
- [ ] 너무 긴 식을 인라인으로 우겨넣지 않았는가

### 내부 자동 적용 규칙 (수식 작성 시)

1. 영어 수학 토큰 자동 치환 (`theta` → `\theta` 등)
2. 함수명에 LaTeX 명령 강제 (`sin` → `\sin`)
3. `sqrt(...)`, `->`, `<=` 같은 표기 자동 정리
4. 설명과 수식 분리
5. 업로드 후 fetch 기준으로 재확인
