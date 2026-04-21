---
name: notion-md-uploader-codex
description: "Codex/OpenAI-side Notion uploader workflow that mirrors the compact path-first strategy where available and keeps verification minimal."
---

# Skill: notion-md-uploader-codex

## 역할

Codex/OpenAI 환경에서 Notion 업로드를 할 때 사용하는 버전.
Claude namespace 대신 **Codex Notion MCP 함수 이름**을 기준으로 작업한다.

핵심 원칙:

- 페이지 탐색은 `mcp__codex_apps__notion._search`
- 신규 생성은 `mcp__codex_apps__notion._notion_create_pages`
- 내용 갱신은 `mcp__codex_apps__notion._notion_update_page`
- 검증 조회는 `mcp__codex_apps__notion._fetch`

---

## Codex 경로에서 유지할 절감 원칙

- 같은 페이지를 search/fetch로 여러 번 왕복하지 않는다
- 가능한 한 create/update 후 fetch는 1회만 한다
- 검증은 전체 본문 재인용이 아니라 digest 중심으로 한다
- 향후 로컬 wrapper tool이 생기면 file path 기반 write를 우선 사용한다

중요:

- 현재 기본 Codex Notion MCP는 `new_str`/`content`에 직접 문자열을 받는다
- 즉 Claude PreToolUse 훅처럼 자동 path 치환이 기본 제공되지는 않는다
- 그래서 현 단계의 Codex 절감 포인트는 **round-trip 축소**와 **검증 응답 축소**다

---

## 빠른 매핑

| 목적 | Claude-side | Codex-side |
|---|---|---|
| 페이지 검색 | `mcp__claude_ai_Notion__notion-search` | `mcp__codex_apps__notion._search` |
| 신규 생성 | `mcp__claude_ai_Notion__notion-create-pages` | `mcp__codex_apps__notion._notion_create_pages` |
| 페이지 조회 | `mcp__claude_ai_Notion__notion-fetch` | `mcp__codex_apps__notion._fetch` |
| 페이지 업데이트 | `mcp__claude_ai_Notion__notion-update-page` | `mcp__codex_apps__notion._notion_update_page` |

---

## 추천 조합

- 짧은 동기화는 `notion-sync-markdown-codex`
- 검증은 `notion-fetch-digest-codex`
- 큰 문서는 splitter를 먼저 돌린 뒤 chunk append 전략을 따른다
