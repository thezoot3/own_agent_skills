---
name: notion-md-uploader
description: "Uploads a completed .md file to Notion via MCP without content corruption. Use after notion-md-writer has produced a .md file and the user asks to upload or publish to Notion."
---

# Skill: notion-md-uploader
# Notion MCP를 이용해 .md 파일을 정확하게 업로드하는 규칙

## 역할 (Role)
너는 Notion MCP 업로드 전문가다.
`notion-md-writer` 스킬로 완성된 `.md` 파일을 받아
Notion API (Notion-Version: 2026-03-11 기준)를 통해
내용 손상 없이 업로드한다.

## 사전 조건 (Prerequisites)
- `.md` 파일이 `notion-md-writer` 규칙에 따라 작성되어 있어야 한다.
- Notion MCP 서버가 연결되어 있어야 한다.
- Integration에 `insert_content`, `update_content`, `read_content` capability가 있어야 한다.

---

## 업로드 워크플로우

### STEP 1 — 업로드 대상 확인

업로드 전 반드시 확인:
1. `.md` 파일의 **절대 경로**를 받는다. 파일을 직접 읽지 않는다 — PreToolUse 훅이 자동으로 내용을 주입한다.
2. 업로드할 Notion 위치를 파악한다:
    - **신규 페이지**: 부모 페이지 ID 또는 데이터베이스 ID 필요
    - **기존 페이지 교체**: 대상 페이지 ID 필요
    - **기존 페이지 추가**: 대상 페이지 ID + 삽입 위치 필요

### STEP 2 — 부모 페이지 탐색 (모르는 경우)

Notion MCP 툴: `mcp__claude_ai_Notion__notion-search`

```json
{
  "query": "페이지명",
  "filter": { "value": "page", "property": "object" }
}
```

- 결과에서 `id` 필드를 추출한다 (32자 UUID, 하이픈 포함 형태)
- 형식 예: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

### STEP 3 — 신규 페이지 생성

Notion MCP 툴: `mcp__claude_ai_Notion__notion-create-pages`

#### 3-A. markdown 파라미터 방식 (권장 ✅)

`Notion-Version: 2026-03-11` 이상에서만 동작.
`children` 파라미터와 **절대 동시에 사용하지 않는다**.

```json
{
  "parent": { "page_id": "PARENT_PAGE_ID" },
  "markdown": "/absolute/path/to/file.md"
}
```

- 첫 번째 `# H1` 헤딩이 자동으로 페이지 제목이 됨
- 제목을 명시하려면 `properties.title`을 별도로 설정:

```json
{
  "parent": { "page_id": "PARENT_PAGE_ID" },
  "properties": {
    "title": { "title": [{ "text": { "content": "페이지 제목" } }] }
  },
  "markdown": "<본문 마크다운 (제목 헤딩 제외)"
}
```

#### 3-B. 데이터베이스에 항목 추가

```json
{
  "parent": { "database_id": "DATABASE_ID" },
  "properties": {
    "Name": { "title": [{ "text": { "content": "항목 제목" } }] }
  },
  "markdown": "<본문 마크다운>"
}
```

### STEP 4 — 기존 페이지 업데이트

#### 4-A. 전체 내용 교체

Notion MCP 툴: `mcp__claude_ai_Notion__notion-update-page`

```json
{
  "type": "replace_content",
  "replace_content": {
    "new_str_path": "/absolute/path/to/file.md"
  }
}
```

- `new_str` 대신 `new_str_path`를 우선 사용한다
- PreToolUse 훅이 파일을 읽어 `new_str`로 자동 치환한다
⚠️ **주의**: 페이지 안의 child page/database가 있으면 삭제 경고 발생.
삭제를 허용하려면 `"allow_deleting_content": true` 추가.

#### 4-B. 특정 내용 교체 (search-and-replace)

```json
{
  "type": "update_content",
  "update_content": {
    "content_updates": [
      {
        "old_str": "교체할 기존 텍스트 (정확히 일치해야 함)",
        "new_str_path": "/absolute/path/to/replacement.md"
      }
    ]
  }
}
```

- `old_str`은 대소문자 구분하여 정확히 일치해야 함
- 동일한 텍스트가 여러 곳에 있으면 `"replace_all_matches": true` 추가
- `new_str` 직접 인라인 대신 `new_str_path`를 우선 사용한다

#### 4-C. 끝에 내용 추가 (append)

```json
{
  "type": "insert_content",
  "insert_content": {
    "content_path": "/absolute/path/to/appendix.md"
  }
}
```

- `content` 직접 인라인 대신 `content_path`를 우선 사용한다
- PreToolUse 훅이 파일을 읽어 `content`로 자동 치환한다

### STEP 5 — 업로드 결과 검증

업로드 후 반드시 확인:

1. `mcp__claude_ai_Notion__notion-fetch`로 내용 조회
2. `truncated: false` 확인 (true이면 일부 누락)
3. `unknown_block_ids` 배열이 비어 있는지 확인
    - 비어있지 않으면 → 해당 블록 ID를 개별적으로 재조회
4. 수식(`$...$`, `$$...$$`)이 포함된 문서면 업로드 직후 `notion-formula-checker` 스킬을 실행한다.

---

## 에러 핸들링

| 에러 | 원인 | 해결 방법 |
|---|---|---|
| `validation_error` — mutually exclusive | `markdown`과 `children` 동시 사용 | `children` 제거, `markdown`만 사용 |
| `validation_error` — old_str not found | 검색 텍스트 불일치 | 대소문자·공백 확인 후 재시도 |
| `validation_error` — multiple matches | `old_str`이 중복 존재 | `replace_all_matches: true` 추가 |
| `validation_error` — would delete child | 자식 페이지 삭제 위험 | `allow_deleting_content: true` 추가 (신중히) |
| `object_not_found` | 페이지 ID 틀림 또는 권한 없음 | Integration 공유 설정 확인 |
| `restricted_resource` | capability 부족 | Integration 설정에서 capability 추가 |
| 이미지 깨짐 | 로컬 경로 사용 | 이미지를 외부 URL로 호스팅 후 재업로드 |

---

## 토큰 절감 수칙

- `children` 파라미터(JSON 블록 방식)는 **사용하지 않는다** — 동일 내용 대비 3~7배 토큰 소비
- `markdown` 파라미터에 **파일 절대 경로**를 전달한다 — PreToolUse 훅(`inject_md.sh`)이 파일을 읽어 내용으로 교체하므로 Claude context에 파일 내용이 진입하지 않는다
- `replace_content.new_str_path`, `update_content.content_updates[].new_str_path`, `insert_content.content_path`도 동일하게 경로 기반으로 넘긴다
- 검증 시 `GET /markdown` 엔드포인트를 사용해 JSON 블록 API 대신 마크다운으로 받는다
- 업데이트는 `replace_content` 또는 `update_content`를 사용하고 블록 단위 append는 피한다
- `.md` 파일은 **512KB 이하**를 권장한다 — 초과 시 훅이 경고를 출력하고 주입을 건너뜀

---

## 추천 조합

- 업로드 전체를 짧은 흐름으로 끝내려면 `notion-sync-markdown` 스킬을 함께 사용한다
- 파일이 `512KB`를 넘으면 `notion-sync-large-markdown` 스킬로 먼저 분할한다
- 업로드 후 가벼운 검증만 필요하면 `notion-fetch-digest` 스킬을 함께 사용한다

---

## 빠른 참조 — MCP 툴 이름 매핑

| 작업 | MCP 툴 |
|---|---|
| 페이지 검색 | `mcp__claude_ai_Notion__notion-search` |
| 신규 페이지 생성 | `mcp__claude_ai_Notion__notion-create-pages` |
| 페이지 내용 조회 | `mcp__claude_ai_Notion__notion-fetch` |
| 페이지 내용 업데이트 | `mcp__claude_ai_Notion__notion-update-page` |
| 데이터베이스 생성 | `mcp__claude_ai_Notion__notion-create-database` |

> **Notion-Version**: 항상 `2026-03-11` 이상을 사용한다.
> 구버전에서는 `markdown` 파라미터가 동작하지 않는다.
