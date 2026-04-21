---
name: notion-fetch-digest
description: "Verify or inspect a Notion page with a compact digest instead of a full-page walkthrough. Optimized to reduce follow-up tool calls and verbose output."
allowed-tools:
  - mcp__claude_ai_Notion__notion-fetch
  - mcp__claude_ai_Notion__notion-search
---

## 역할

Notion 페이지를 읽을 때 **전체 본문을 다시 길게 전개하지 않고**, 검증에 필요한 최소 정보만 요약하는 스킬.

이 스킬의 목적은:

- fetch 이후의 불필요한 왕복을 줄이기
- 검증용 응답을 짧고 구조적으로 유지하기
- 전체 본문 재인용으로 billable이 커지는 것을 막기

중요:

- 현재 Claude hooks 문서 기준으로 `PostToolUse`는 `additionalContext` 추가 중심이며,
  fetch 응답 본문 자체를 안전하게 치환하는 방식은 확인되지 않았다.
- 따라서 이 스킬은 **fetch payload 자체를 줄이는 툴이 아니라**, fetch 이후의 운영 비용을 줄이는 스킬이다.

---

## STEP 1 — 대상 결정

- `page_id` 또는 `page_url`이 있으면 바로 fetch
- 둘 다 없으면 `notion-search`를 한 번만 사용해 대상 페이지를 찾는다

search는 페이지 식별용으로만 쓰고, fetch 전에 반복 호출하지 않는다.

---

## STEP 2 — fetch 1회

`notion-fetch`를 한 번 호출한다.

전체 본문이 반환되더라도, 이후 응답에서는 아래 digest만 추출한다.

---

## STEP 3 — digest 구성

반드시 아래 항목만 우선 정리한다.

- 페이지 제목
- 페이지 ID / URL
- `truncated` 여부
- `unknown_block_ids` 개수와 값
- 최상위 헤딩 목록
  - H1~H3 중심
  - 최대 10개
- child page / database 존재 여부
- 수식 문서인 경우
  - 인라인 수식 존재 여부
  - 블록 수식 존재 여부

필요할 때만 추가:

- 첫 섹션 제목
- 마지막 섹션 제목
- 특정 키워드 존재 여부

---

## STEP 4 — 확대 조건

아래 경우에만 full-content 기준 후속 작업으로 확대한다.

- `truncated: true`
- `unknown_block_ids`가 비어 있지 않음
- 정확한 `old_str`가 필요함
- 유저가 전문 전체 확인을 명시적으로 요청함

그 외에는 digest 단계에서 멈춘다.

---

## STEP 5 — 결과 보고 형식

권장 출력 형식:

```text
페이지: <title>
ID: <page_id>
truncated: false
unknown_block_ids: 0
헤딩:
- ...
- ...
- ...
특이사항:
- 없음
```

본문 전체를 장문으로 재출력하지 않는다.

---

## 금지 행동

- ❌ fetch 후 본문 전체를 다시 길게 요약하기
- ❌ 같은 페이지를 검증 목적으로 연속 fetch 여러 번 하기
- ❌ digest로 충분한 상황에서 search/fetch를 반복하기
- ❌ `old_str`가 필요하지 않은데 세부 문단을 길게 인용하기

---

## 언제 이 스킬을 우선 쓰는가

- 업로드 직후 반영 여부만 확인할 때
- `truncated` / `unknown_block_ids`만 확인하면 될 때
- 헤딩 구조만 보고 페이지가 정상인지 확인할 때
- 유저가 “노션에 썻니?” “업로드 됐니?”처럼 짧은 검증을 원할 때
