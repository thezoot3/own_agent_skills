---
name: notion-sync-markdown-codex
description: "Codex/OpenAI-side compact Notion sync workflow using codex_apps Notion tools."
allowed-tools:
  - mcp__codex_apps__notion._search
  - mcp__codex_apps__notion._notion_create_pages
  - mcp__codex_apps__notion._notion_update_page
  - mcp__codex_apps__notion._fetch
  - Read
---

## 역할

Codex/OpenAI 환경에서 `.md` 문서를 Notion에 동기화할 때 쓰는 compact workflow.

목표:

1. `search -> write -> verify`를 짧게 유지한다
2. Codex billable을 늘리는 중복 fetch와 장문 재출력을 피한다

---

## STEP 1 — 대상 결정

- `page_id`가 있으면 search 생략
- 없으면 `mcp__codex_apps__notion._search`를 한 번만 호출
- 같은 제목 후보가 여러 개면 가장 명확한 하나만 선택

---

## STEP 2 — 쓰기

### 신규 생성

`mcp__codex_apps__notion._notion_create_pages`

### 전체 교체 / append / patch

`mcp__codex_apps__notion._notion_update_page`

주의:

- 현재 기본 Codex 경로에서는 본문이 문자열 필드로 들어간다
- 따라서 매우 큰 문서는 `notion-sync-large-markdown`의 splitter를 먼저 사용한다

---

## STEP 3 — 검증

- `mcp__codex_apps__notion._fetch`는 최대 1회
- 응답 정리는 `notion-fetch-digest-codex` 방식으로 한다

검증 항목:

- `truncated`
- `unknown_block_ids`
- 주요 헤딩
- 마지막 append chunk 반영 여부

---

## 금지 행동

- ❌ search와 fetch를 번갈아 여러 번 호출하기
- ❌ verify용으로 본문 전체를 다시 길게 인용하기
- ❌ 작은 수정인데 전체 페이지를 여러 번 replace하기
