---
name: notion-sync-large-markdown
description: "Split oversized markdown files into Notion-safe chunks, then sync them with create-or-replace plus append passes."
allowed-tools:
  - Bash
  - Read
  - mcp__claude_ai_Notion__notion-search
  - mcp__claude_ai_Notion__notion-create-pages
  - mcp__claude_ai_Notion__notion-update-page
  - mcp__claude_ai_Notion__notion-fetch
---

## 역할

512KB를 넘거나, 훅 주입 한도를 넘어갈 가능성이 높은 `.md` 문서를
Notion-safe chunk로 분할한 뒤 순서대로 동기화하는 스킬.

이 스킬의 목표:

1. 큰 문서도 path 기반 업로드 흐름을 유지한다.
2. `new_str`/`content` inline 문자열로 되돌아가지 않는다.
3. 첫 chunk는 create 또는 replace, 이후 chunk는 append로 이어 붙인다.

---

## 언제 사용하는가

아래 중 하나면 이 스킬을 우선 사용한다.

- 파일 크기가 `512KB`를 초과한다
- 훅이 경고를 내고 본문 주입을 건너뛴다
- 헤딩/섹션이 많아 append 순서 관리가 필요하다
- 긴 Notion 문서를 손상 없이 여러 번에 나눠 올려야 한다

---

## STEP 1 — 파일 분할

먼저 splitter 스크립트를 실행한다.

```bash
python3 notion_sync_large_markdown/scripts/split_markdown_for_notion.py \
  /absolute/path/to/file.md \
  --out-dir /tmp/notion-chunks
```

기본 동작:

- H1~H3 헤딩을 우선 경계로 사용한다
- chunk당 바이트 수를 `400000` 근처로 유지한다
- 첫 chunk는 문서 시작부와 제목을 유지한다
- 결과물:
  - `part-001.md`
  - `part-002.md`
  - ...
  - `manifest.json`

---

## STEP 2 — 동기화 방식 결정

### A. 신규 페이지

1. `part-001.md`로 create
2. `part-002.md` 이후는 순서대로 append

### B. 기존 페이지 전체 교체

1. `part-001.md`로 replace
2. `part-002.md` 이후는 순서대로 append

### C. 기존 페이지 특정 구간 교체

특정 구간만 바꾸는 경우엔 이 스킬보다 `notion-sync-markdown`이 더 적합하다.
큰 문서 전체를 다시 동기화할 때만 이 스킬을 사용한다.

---

## STEP 3 — 쓰기

### 첫 chunk

- 신규 페이지면 `markdown` create
- 기존 페이지면 `replace_content.new_str_path`

### 이후 chunk

- `insert_content.content_path`로 순서대로 append
- chunk 순서를 바꾸지 않는다

예시:

```json
{
  "type": "insert_content",
  "insert_content": {
    "content_path": "/tmp/notion-chunks/part-002.md"
  }
}
```

---

## STEP 4 — 검증

모든 chunk 반영 후 fetch는 **1회만** 호출한다.

확인 항목:

- `truncated: false`
- `unknown_block_ids` 비어 있음
- 마지막 chunk의 마지막 헤딩이 실제로 존재함
- manifest의 chunk 수와 append 횟수가 일치함

수식이 있으면 `notion-formula-checker`를 이어서 호출한다.

---

## STEP 5 — 정리

유저에게는 아래만 간단히 보고한다.

- 원본 파일 경로
- 생성된 chunk 수
- create/replace + append 횟수
- 검증 결과
- 필요하면 chunk 디렉터리 경로

---

## 금지 행동

- ❌ 512KB 초과 문서를 inline `new_str`로 직접 보내기
- ❌ chunk를 임의 순서로 append하기
- ❌ 각 chunk마다 fetch 반복 호출하기
- ❌ splitter 없이 임시로 수동 복붙해서 분할하기

---

## 추천 조합

- 보통은 `notion-sync-markdown`의 상위 호환으로 사용한다
- 검증 요약은 `notion-fetch-digest` 스타일로 짧게 끝낸다
