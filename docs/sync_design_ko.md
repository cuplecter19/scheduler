# 동기화 설계

- 클라이언트는 Task와 TimeBlock 변경을 항상 로컬 SQLite에 먼저 저장한다.
- 각 레코드는 `updated_at`, `is_deleted`, `device_id`를 포함한다.
- `/sync` 업로드 시 서버는 기존 레코드보다 `updated_at`이 최신인 변경만 반영한다.
- `/sync` 다운로드 시 클라이언트도 같은 last-write-wins 규칙으로 로컬 레코드를 갱신한다.
- 삭제는 실제 삭제가 아니라 `is_deleted=true`로 전파한다.
