---
name: notion-fetch-digest-codex
description: "Codex/OpenAI-side compact verification workflow for Notion pages."
allowed-tools:
  - mcp__codex_apps__notion._fetch
  - mcp__codex_apps__notion._search
---

## 역할

Codex/OpenAI 환경에서 Notion 페이지를 확인할 때
전체 본문을 장문으로 다시 전개하지 않고 digest만 추출하는 스킬.

---

## 기본 원칙

- fetch는 1회
- 필요한 경우에만 search 1회
- 응답은 아래 항목만 우선 정리

---

## digest 항목

- 페이지 제목
- 페이지 ID / URL
- `truncated`
- `unknown_block_ids`
- 최상위 헤딩 최대 10개
- child page/database 존재 여부
- 특정 키워드 존재 여부

---

## 확대 조건

아래 경우에만 후속 상세 조회로 넘어간다.

- `truncated: true`
- `unknown_block_ids`가 비어 있지 않음
- 정확한 `old_str`를 찾아야 함
- 유저가 전문 전체 확인을 명시함

---

## 금지 행동

- ❌ fetch 후 본문 전체를 다시 길게 서술하기
- ❌ digest로 충분한데 추가 fetch 반복하기
