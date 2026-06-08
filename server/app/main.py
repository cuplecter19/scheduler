from __future__ import annotations

import json
import os
import sqlite3
from contextlib import asynccontextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import jwt
from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from passlib.context import CryptContext
from pydantic import BaseModel, EmailStr, Field

DATABASE_URL = Path(os.getenv('SCHEDULER_DB', 'scheduler_sync.sqlite3'))
JWT_SECRET = os.getenv('SCHEDULER_JWT_SECRET')
JWT_ALGORITHM = 'HS256'
TOKEN_EXPIRE_DAYS = 30


@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


def cors_origins() -> list[str]:
    value = os.getenv('SCHEDULER_CORS_ORIGINS', '')
    return [origin.strip() for origin in value.split(',') if origin.strip()]


app = FastAPI(title='Structured Clone Sync API', version='0.1.0', lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins(),
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)
security = HTTPBearer()
passwords = CryptContext(schemes=['bcrypt'], deprecated='auto')


class AuthRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = 'bearer'


class SyncRecord(BaseModel):
    id: str
    type: str
    data: dict[str, Any]
    updated_at: datetime
    is_deleted: bool = False
    device_id: str = ''


class PushRequest(BaseModel):
    changes: list[SyncRecord] = Field(default_factory=list)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat()


def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DATABASE_URL)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    with connect() as conn:
        conn.execute(
            '''
            CREATE TABLE IF NOT EXISTS users(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT NOT NULL UNIQUE,
              password_hash TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
            '''
        )
        conn.execute(
            '''
            CREATE TABLE IF NOT EXISTS records(
              user_id INTEGER NOT NULL,
              id TEXT NOT NULL,
              type TEXT NOT NULL,
              data TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              device_id TEXT NOT NULL DEFAULT '',
              PRIMARY KEY(user_id, type, id),
              FOREIGN KEY(user_id) REFERENCES users(id)
            )
            '''
        )
        conn.execute('CREATE INDEX IF NOT EXISTS idx_records_updated ON records(user_id, updated_at)')


def jwt_secret() -> str:
    if not JWT_SECRET or len(JWT_SECRET) < 32:
        raise RuntimeError('SCHEDULER_JWT_SECRET must be set to at least 32 characters')
    return JWT_SECRET


def make_token(user_id: int, email: str) -> str:
    expires = utcnow() + timedelta(days=TOKEN_EXPIRE_DAYS)
    return jwt.encode({'sub': str(user_id), 'email': email, 'exp': expires}, jwt_secret(), algorithm=JWT_ALGORITHM)


def current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> sqlite3.Row:
    try:
        payload = jwt.decode(credentials.credentials, jwt_secret(), algorithms=[JWT_ALGORITHM])
        user_id = int(payload['sub'])
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Token expired') from exc
    except (jwt.InvalidTokenError, KeyError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid token') from exc
    with connect() as conn:
        user = conn.execute('SELECT * FROM users WHERE id = ?', (user_id,)).fetchone()
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='User not found')
    return user


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok', 'server_time': iso(utcnow())}


@app.post('/auth/register', response_model=AuthResponse)
def register(request: AuthRequest) -> AuthResponse:
    with connect() as conn:
        existing = conn.execute('SELECT id FROM users WHERE email = ?', (request.email.lower(),)).fetchone()
        if existing:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail='Email already registered')
        cursor = conn.execute(
            'INSERT INTO users(email, password_hash, created_at) VALUES (?, ?, ?)',
            (request.email.lower(), passwords.hash(request.password), iso(utcnow())),
        )
        user_id = int(cursor.lastrowid)
    return AuthResponse(access_token=make_token(user_id, request.email.lower()))


@app.post('/auth/login', response_model=AuthResponse)
def login(request: AuthRequest) -> AuthResponse:
    with connect() as conn:
        user = conn.execute('SELECT * FROM users WHERE email = ?', (request.email.lower(),)).fetchone()
    if user is None or not passwords.verify(request.password, user['password_hash']):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid email or password')
    return AuthResponse(access_token=make_token(int(user['id']), user['email']))


@app.get('/sync')
def pull_sync(
    since: datetime | None = Query(default=None, description='Only records updated after this timestamp'),
    user: sqlite3.Row = Depends(current_user),
) -> dict[str, Any]:
    sql = 'SELECT * FROM records WHERE user_id = ?'
    args: list[Any] = [user['id']]
    if since is not None:
        sql += ' AND updated_at > ?'
        args.append(iso(since))
    sql += ' ORDER BY updated_at ASC'
    with connect() as conn:
        rows = conn.execute(sql, args).fetchall()
    return {
        'server_time': iso(utcnow()),
        'changes': [record_to_dict(row) for row in rows],
    }


@app.post('/sync')
def push_sync(request: PushRequest, user: sqlite3.Row = Depends(current_user)) -> dict[str, Any]:
    applied = 0
    with connect() as conn:
        for change in request.changes:
            existing = conn.execute(
                'SELECT updated_at FROM records WHERE user_id = ? AND type = ? AND id = ?',
                (user['id'], change.type, change.id),
            ).fetchone()
            incoming_updated = iso(change.updated_at)
            if existing is None or incoming_updated > existing['updated_at']:
                conn.execute(
                    '''
                    INSERT INTO records(user_id, id, type, data, updated_at, is_deleted, device_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(user_id, type, id) DO UPDATE SET
                      data = excluded.data,
                      updated_at = excluded.updated_at,
                      is_deleted = excluded.is_deleted,
                      device_id = excluded.device_id
                    ''',
                    (
                        user['id'],
                        change.id,
                        change.type,
                        json.dumps(change.data, ensure_ascii=False),
                        incoming_updated,
                        1 if change.is_deleted else 0,
                        change.device_id,
                    ),
                )
                applied += 1
    return {'server_time': iso(utcnow()), 'applied': applied}


def record_to_dict(row: sqlite3.Row) -> dict[str, Any]:
    return {
        'id': row['id'],
        'type': row['type'],
        'data': json.loads(row['data']),
        'updated_at': row['updated_at'],
        'is_deleted': bool(row['is_deleted']),
        'device_id': row['device_id'],
    }
