# Structured Scheduler

Structured의 핵심 흐름(오늘 할 일, 하루 타임라인, 주간 보기, 오프라인 우선 동기화)을 참고해 만든 Flutter 단일 코드베이스 앱입니다. 색상은 요구사항에 맞게 흰색 + 파란색 팔레트만 사용합니다.

## 구성

```text
lib/
  core/models/        Task, TimeBlock, SyncChange 모델
  core/db/            Windows/Android 공용 SQLite 저장소
  core/sync/          FastAPI 동기화 클라이언트 및 엔진
  theme/              app_colors.dart 색상 토큰, 전역 테마
  features/tasks/     할 일 추가/수정/삭제/완료/정렬/숨김
  features/timeblock/ 일간 타임라인, 주간 보기, Task 연결 블록
  features/settings/  서버 로그인/동기화, 폰트 크기 설정
server/app/           FastAPI + SQLite + JWT 동기화 백엔드
```

## 주요 기능

- 할 일: 제목, 메모, 마감일, 우선순위, 태그, 완료 체크, 삭제, 정렬, 완료 숨김
- 타임블록: 일간 24시간 타임라인, 주간 보기, 시작/종료 시간 입력, 색상 지정, 할 일 연결
- 접근성: 설정 화면에서 본문 폰트 크기 조절(기본 16sp 이상)
- 동기화: `updated_at`, `is_deleted`, `device_id` 기반 last-write-wins 방식
- 오프라인 우선: 모든 변경을 로컬 SQLite에 먼저 저장하고 로그인 후 서버와 변경분 교환

## Flutter 앱 실행

필요 버전: Flutter SDK 3.19 이상(Dart 3.3 이상).

> 현재 작업 환경에는 Flutter SDK가 없어 아래 Flutter 빌드 명령은 검증하지 못했습니다. 실제 Flutter 설치 환경에 따라 Android SDK/Visual Studio Windows Desktop 워크로드 등 추가 설정이 필요할 수 있습니다.

```bash
flutter create --platforms=android,windows .
flutter pub get
flutter analyze
flutter test
flutter run -d windows
flutter build windows
flutter build apk --release
```

Android 에뮬레이터에서 로컬 PC 서버에 접속하려면 앱 설정의 서버 URL을 `http://10.0.2.2:8000`으로 입력합니다. 실제 기기에서는 PC 또는 서버의 LAN/공인 IP를 사용합니다. 앱은 기본 서버 URL을 제공하지 않으므로 설정 화면에서 명시적으로 입력해야 합니다.

## FastAPI 서버 로컬 실행

```bash
cd server
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\\Scripts\\activate
pip install -r requirements.txt
export SCHEDULER_JWT_SECRET='REPLACE_WITH_RANDOM_SECRET_AT_LEAST_32_CHARS'
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

상태 확인:

```bash
curl http://127.0.0.1:8000/health
```

## 동기화 API

- `POST /auth/register`: `{ "email": "user@example.com", "password": "password" }`
- `POST /auth/login`: JWT 발급
- `GET /sync?since=ISO_TIME`: 마지막 동기화 이후 변경분 다운로드
- `POST /sync`: 클라이언트 변경분 업로드

서버는 사용자별로 레코드를 분리하고, 같은 `(user_id, type, id)` 레코드가 충돌하면 더 최신 `updated_at` 값을 유지합니다. 삭제는 `is_deleted=true` soft delete로 전파됩니다.

## Oracle Cloud 인스턴스 연결/배포 가이드

### 1. 인스턴스 준비

1. Oracle Cloud 콘솔에서 Ubuntu 22.04/24.04 인스턴스를 생성합니다.
2. 보안 목록 또는 Network Security Group에서 TCP 22(SSH), 80(HTTP), 443(HTTPS), 필요 시 8000(테스트용)을 허용합니다.
3. SSH 접속:

```bash
ssh ubuntu@<ORACLE_PUBLIC_IP>
```

### 2. 서버 런타임 설치

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip nginx certbot python3-certbot-nginx
```

### 3. 애플리케이션 배치

```bash
mkdir -p /opt/structured-clone
cd /opt/structured-clone
# 이 저장소를 배포 방식에 맞게 복사/체크아웃한 뒤 server 폴더로 이동
cd server
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
```

운영 환경 변수 파일을 만듭니다.

```bash
sudo tee /etc/structured-clone.env >/dev/null <<'ENV'
SCHEDULER_DB=/opt/structured-clone/server/scheduler_sync.sqlite3
SCHEDULER_JWT_SECRET=REPLACE_WITH_RANDOM_SECRET_AT_LEAST_32_CHARS
# 프로덕션에서는 앱/웹 클라이언트가 접근할 실제 HTTPS Origin을 명시합니다.
SCHEDULER_CORS_ORIGINS=https://<YOUR_DOMAIN>
ENV
```

### 4. systemd 서비스 등록

```bash
sudo tee /etc/systemd/system/structured-clone.service >/dev/null <<'SERVICE'
[Unit]
Description=Structured Scheduler Sync API
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/opt/structured-clone/server
EnvironmentFile=/etc/structured-clone.env
ExecStart=/opt/structured-clone/server/.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable --now structured-clone
sudo systemctl status structured-clone
```

### 5. Nginx 리버스 프록시

도메인이 있다면 `<YOUR_DOMAIN>`을 도메인으로, 없으면 임시로 공인 IP를 사용합니다.

```bash
sudo tee /etc/nginx/sites-available/structured-clone >/dev/null <<'NGINX'
server {
    listen 80;
    server_name <YOUR_DOMAIN>;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/structured-clone /etc/nginx/sites-enabled/structured-clone
sudo nginx -t
sudo systemctl reload nginx
```

HTTPS 인증서 발급:

```bash
sudo certbot --nginx -d <YOUR_DOMAIN>
```

### 6. 앱에서 Oracle 서버 연결

1. 앱 실행 후 **설정 → 서버 URL**에 `https://<YOUR_DOMAIN>` 또는 테스트 중이면 `http://<ORACLE_PUBLIC_IP>`를 입력합니다.
2. 회원가입 또는 로그인합니다.
3. **지금 동기화**를 누릅니다.
4. Windows 앱과 Android 앱에서 같은 계정으로 로그인하면 같은 데이터가 자동으로 교환됩니다.

### 7. 운영 점검

```bash
curl https://<YOUR_DOMAIN>/health
sudo journalctl -u structured-clone -f
sudo systemctl restart structured-clone
```

SQLite 파일은 `/opt/structured-clone/server/scheduler_sync.sqlite3`에 저장됩니다. 운영 규모가 커지면 PostgreSQL로 이전하고 `records(user_id, updated_at)` 인덱스를 유지하세요.
