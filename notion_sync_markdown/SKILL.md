---
name: notion-sync-markdown
description: "Sync a local .md file to Notion with minimal tool round-trips. Resolves the target once, writes from file paths, and verifies with a compact digest."
allowed-tools:
  - mcp__claude_ai_Notion__notion-search
  - mcp__claude_ai_Notion__notion-create-pages
  - mcp__claude_ai_Notion__notion-update-page
  - mcp__claude_ai_Notion__notion-fetch
  - Read
---

## 역할

로컬 `.md` 파일을 Notion에 **동기화(sync)**할 때 호출하는 스킬.
목표는 두 가지다.

1. Notion 동기화 전체를 `search -> write -> verify`의 짧은 흐름으로 끝낸다.
2. 본문 마크다운을 모델 컨텍스트에 넣지 않고 **파일 경로 기반**으로 처리한다.

---

## 핵심 원칙

- `.md` 파일의 **절대 경로**를 받는다.
- 전체 파일 내용을 먼저 `Read`로 열지 않는다.
- 가능한 한 **툴 왕복 횟수**를 줄인다.
- 생성은 `markdown: "/absolute/path/to/file.md"`를 사용한다.
- 교체는 `new_str_path`를 사용한다.
- 추가는 `content_path`를 사용한다.
- 검증은 전체 본문 낭독이 아니라 **digest** 기준으로 끝낸다.

파일이 `512KB`를 넘거나 훅 주입이 건너뛰어질 가능성이 있으면:

- `notion-sync-large-markdown`으로 먼저 분할한 뒤 동기화한다.

---

## STEP 1 — 입력 정리

먼저 아래 정보 중 가능한 것을 수집한다.

- `file_path`: 업로드할 `.md` 파일 절대 경로
- `page_id` 또는 `page_url`
- `parent_page_id` 또는 `parent_database_id`
- `title`
- 원하는 동작
  - `create`
  - `replace`
  - `append`
  - `patch`

판단 규칙:

- `page_id`가 있으면 **search 생략**
- `page_id`가 없고 `parent + title`이 있으면 한 번만 search
- `patch`가 아니면 전체 본문 `Read` 금지

---

## STEP 2 — 대상 결정

### A. 기존 페이지를 덮어쓸 때

- `page_id` 또는 `page_url`이 있으면 바로 update 단계로 간다.

### B. 부모 아래 같은 제목 페이지를 찾을 때

`notion-search`를 **한 번만** 호출한다.

검색 목적:
- 기존 페이지가 있으면 `replace`
- 없으면 `create`

검색 결과가 2개 이상이면:
- 가장 명확한 1개만 선택 가능한 경우에만 진행
- 애매하면 유저에게 짧게 확인

---

## STEP 3 — 쓰기

### A. 신규 생성

`notion-create-pages`에서 `markdown` 필드에 절대 경로를 넘긴다.

```json
{
  "parent": { "page_id": "PARENT_PAGE_ID" },
  "markdown": "/absolute/path/to/file.md"
}
```

### B. 전체 교체

`notion-update-page`에서 `new_str` 대신 `new_str_path`를 사용한다.

```json
{
  "page_id": "PAGE_ID",
  "type": "replace_content",
  "replace_content": {
    "new_str_path": "/absolute/path/to/file.md"
  }
}
```

### C. 끝에 추가

`insert_content.content` 대신 `content_path`를 사용한다.

```json
{
  "page_id": "PAGE_ID",
  "type": "insert_content",
  "insert_content": {
    "content_path": "/absolute/path/to/appendix.md"
  }
}
```

### D. 부분 치환

치환 조각도 경로로 넘긴다.

```json
{
  "page_id": "PAGE_ID",
  "type": "update_content",
  "update_content": {
    "content_updates": [
      {
        "old_str": "교체할 기존 문자열",
        "new_str_path": "/absolute/path/to/replacement.md"
      }
    ]
  }
}
```

---

## STEP 4 — 검증

쓰기 후 `notion-fetch`는 **최대 1회**만 호출한다.

검증 체크:

- `truncated: false`
- `unknown_block_ids`가 비어 있음
- 최상위 제목/섹션 구조가 예상과 맞음
- 생성/교체/추가 결과가 페이지에 반영됨

수식 문서면:

- `$...$` 또는 `$$...$$`가 원본 파일에 있으면 즉시 `notion-formula-checker`로 넘긴다.

---

## STEP 5 — 결과 보고

유저에게는 전체 본문을 다시 길게 복붙하지 않는다.
반드시 아래 정보만 짧게 정리한다.

- 어떤 동작을 했는지 (`create` / `replace` / `append` / `patch`)
- 대상 페이지 ID 또는 URL
- 검증 결과
  - `truncated`
  - `unknown_block_ids`
  - 주요 헤딩 3~10개
- 수식 검증 여부

---

## 금지 행동

- ❌ `page_id`가 있는데 search부터 다시 하기
- ❌ 전체 파일 본문을 tool 인자로 직접 문자열로 싣기
- ❌ write 뒤 fetch를 여러 번 반복하기
- ❌ 검증 결과를 이유 없이 본문 전체 재인용으로 길게 출력하기

---

## 추천 흐름

가장 billable 친화적인 기본 흐름:

1. `page_id`가 있으면 바로 write
2. 없으면 search 1회
3. create 또는 replace 1회
4. fetch 1회
5. 필요 시 formula-check 1회

이 스킬은 **툴 수를 줄이는 것**과 **본문을 경로 기반으로 넘기는 것**을 동시에 강제한다.
