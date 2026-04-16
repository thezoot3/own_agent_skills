---
name: notion-md-writer
description: "Writes content intended for Notion upload. Always creates a .md file first before any MCP tool call. Use when drafting articles, notes, or documents destined for Notion."
---
***

## 역할
Notion에 업로드할 글을 쓸 때 동작하는 스킬.
`.md` 파일 없이 MCP 툴로 블록을 직접 append하는 것은 **절대 금지**다.
항상 파일을 먼저 완성한 뒤 업로드 단계로 넘어간다.

***

## 워크플로우

### STEP 1 — 파일명 결정
- 형식: `notion_<slug>.md` (예: `notion_weekly-review.md`)
- slug: 영문 소문자 + 하이픈만 사용

### STEP 2 — Notion-flavored Markdown (Enhanced Markdown)으로 작성

Notion API `Notion-Version: 2026-03-11` 기준.

***

#### ✅ 블록 요소 (Block types)

| 요소 | 문법 | 비고 |
|---|---|---|
| 제목 H1~H4 | `# / ## / ### / ####` | H5·H6은 H4로 자동 변환됨 |
| 단락 | 빈 줄로 구분된 일반 텍스트 | |
| 블록 색상 | `# 제목 {color="blue"}` | 블록 첫 줄 끝에 속성 추가 |
| 불릿 리스트 | `- item` | 자식 블록은 탭으로 들여쓰기 |
| 번호 리스트 | `1. item` | |
| 체크박스 | `- [ ] todo` / `- [x] done` | |
| 인용 | `> quote` | 멀티라인: `> 줄1<br>줄2` |
| 구분선 | `---` | |
| 빈 블록 | `<empty-block/>` | 단순 빈 줄은 제거됨 |
| 코드 블록 | ` ```language\n코드\n``` ` | 언어 반드시 명시. Mermaid: ` ```mermaid ` |
| 블록 수식 | `$$\n수식\n$$` | 별도 줄로 분리 (인라인과 다름!) |
| 토글 | `<details><summary>제목</summary>\n\t자식\n</details>` | |
| 토글 헤딩 | `# 제목 {toggle="true"}` | |
| 콜아웃 | `<callout icon="🎯" color="blue_bg">\n\t내용\n</callout>` | icon·color 선택사항 |
| 테이블 | HTML `<table>` 태그 사용 (아래 참고) | 파이프 테이블 불안정 |
| 컬럼 레이아웃 | `<columns><column>내용</column><column>내용</column></columns>` | |
| 이미지 | `![캡션](https://hosted-url)` | 로컬 경로 불가, hosted URL만 |
| 오디오 | `<audio src="URL">캡션</audio>` | |
| 비디오 | `<video src="URL">캡션</video>` | |
| PDF | `<pdf src="URL">캡션</pdf>` | |
| 파일 첨부 | `<file src="URL">캡션</file>` | |
| 페이지 링크 | `<page url="URL">페이지 제목</page>` | |
| 데이터베이스 | `<database url="URL" inline="true">제목</database>` | |
| 목차 | `<table_of_contents/>` | |
| 싱크 블록 | `<synced_block url="URL">내용</synced_block>` | |

***

#### ✅ 인라인 서식 (Rich text formatting)

| 요소 | 문법 | 주의사항 |
|---|---|---|
| 굵게 | `**text**` | |
| 기울임 | `*text*` | |
| 취소선 | `~~text~~` | |
| 밑줄 | `<span underline="true">text</span>` | CSS 스타일 방식 불가 |
| 인라인 코드 | `` `code` `` | |
| 링크 | `[label](url)` | |
| **인라인 수식** | `$equation$` | ⚠️ 달러 **한 개** — `$$...$$`는 블록 수식 |
| 줄바꿈 (인라인) | `<br>` | Shift+Enter 효과 |
| 인라인 색상 | `<span color="blue">text</span>` | |
| 커스텀 이모지 | `:emoji_name:` | |
| 인용 각주 | `[^URL]` | |

***

#### ✅ 멘션 (Mentions)

```
<mention-user url="URL">이름</mention-user>
<mention-page url="URL">페이지 제목</mention-page>
<mention-database url="URL">DB 이름</mention-database>
<mention-date start="2026-04-16"/>
<mention-date start="2026-04-16" startTime="09:00" timeZone="Asia/Seoul"/>
```

***

#### ✅ 색상 값 목록

텍스트: `gray` `brown` `orange` `yellow` `green` `blue` `purple` `pink` `red`
배경: `gray_bg` `brown_bg` `orange_bg` `yellow_bg` `green_bg` `blue_bg` `purple_bg` `pink_bg` `red_bg`

블록 색상 사용법: `## 제목 {color="blue"}`
인라인 색상 사용법: `<span color="red">강조 텍스트</span>`

***

#### ✅ 테이블 문법

```html
<table fit-page-width="true" header-row="true" header-column="false">
<colgroup>
<col color="gray_bg">
<col>
</colgroup>
<tr>
<td>헤더 1</td>
<td>헤더 2</td>
</tr>
<tr color="blue_bg">
<td color="yellow_bg">셀 내용</td>
<td>셀 내용</td>
</tr>
</table>
```

색상 우선순위: 셀 > 행 > 열

***

#### ⚠️ 수식 주의사항 (가장 흔한 깨짐 원인)

| 종류 | 올바른 문법 | 잘못된 문법 (깨짐) |
|---|---|---|
| 인라인 수식 | `$x^2 + y^2$` (달러 1개) | `$$x^2$$` — 블록 수식으로 처리됨 |
| 블록 수식 | 줄 분리 후 `$$\n수식\n$$` | `$$수식$$` 한 줄에 쓰는 것 |

ChatGPT·Obsidian에서 복사한 `$...$` 인라인 수식은 그대로 사용 가능.
단, `$$...$$` 인라인 형식은 Notion에서 블록 수식으로 해석된다.

***

#### ❌ 사용 금지 (업로드 시 깨짐)

- 로컬 이미지 경로 (`./img.png`, `../assets/img.jpg`)
- 인라인 CSS 스타일 (`<span style="color:red">`) — `color` 속성 방식으로 대체
- `<script>`, `<iframe>`, `<bookmark>`, `<embed>`, `<link_preview>`
- GitHub 스타일 파이프 테이블 (`|---|`) — HTML 테이블로 대체
- `breadcrumb`, `template_button` 블록

***

### STEP 3 — 저장 전 체크리스트

- [ ] 첫 줄이 `# 제목` 형태인가?
- [ ] 로컬 이미지 경로가 없는가?
- [ ] 인라인 수식이 `$...$` (달러 1개)인가?
- [ ] 블록 수식이 `$$\n수식\n$$` 형태로 줄 분리되어 있는가?
- [ ] 지원되지 않는 HTML 태그가 없는가?
- [ ] 코드 블록에 언어가 명시되어 있는가?
- [ ] 파일 인코딩이 UTF-8인가?
- [ ] 자식 블록 들여쓰기가 탭(Tab) 기준인가? (스페이스 불가)

### STEP 4 — 완료 선언

파일 저장 후 반드시 아래 형태로 알린다:

```
✅ 파일 완성: notion_<slug>.md
📋 다음 단계: notion-md-uploader 스킬로 업로드
```

***

## 금지 행동
- ❌ `.md` 파일 없이 MCP 툴로 블록 직접 append
- ❌ 파일 작성 도중 업로드 툴 호출
- ❌ 지원되지 않는 문법 사용
- ❌ `markdown`과 `children` 파라미터 동시 사용 예고
