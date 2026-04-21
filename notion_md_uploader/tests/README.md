# inject_md.sh Regression Tests

Run the local regression suite with:

```bash
bash notion_md_uploader/tests/test_inject_md.sh
```

The suite covers:

- `markdown` path injection
- `replace_content.new_str_path`
- `update_content.content_updates[].new_str_path`
- top-level `content_updates[].new_str_path`
- `insert_content.content_path`
- top-level `new_str_path`
- ignored relative paths
- oversized file skip behavior
