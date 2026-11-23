"""Durable account names and accepted friendships; no plaintext device keys."""
from __future__ import annotations

import os
import secrets
import sqlite3
import time
from pathlib import Path

MAX_FRIENDS = 64
MAX_PENDING = 32
REQUEST_DAYS = 14


class StoreError(ValueError):
    pass


class Store:
    def __init__(self, path: str) -> None:
        if path != ":memory:":
            target = Path(path).expanduser().absolute()
            target.parent.mkdir(parents=True, exist_ok=True)
            path = str(target)
        self.db = sqlite3.connect(path, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.execute("PRAGMA busy_timeout=2000")
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.executescript("""
            CREATE TABLE IF NOT EXISTS accounts(
                uid TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                username_key TEXT NOT NULL UNIQUE,
                created INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS friendships(
                owner TEXT NOT NULL REFERENCES accounts(uid),
                friend TEXT NOT NULL REFERENCES accounts(uid),
                created INTEGER NOT NULL,
                PRIMARY KEY(owner, friend),
                CHECK(owner <> friend)
            );
            CREATE TABLE IF NOT EXISTS friend_requests(
                request_id TEXT PRIMARY KEY,
                sender TEXT NOT NULL REFERENCES accounts(uid),
                target TEXT NOT NULL REFERENCES accounts(uid),
                created INTEGER NOT NULL,
                UNIQUE(sender, target),
                CHECK(sender <> target)
            );
            CREATE INDEX IF NOT EXISTS requests_target ON friend_requests(target);
        """)
        if path != ":memory:":
            os.chmod(path, 0o600)

    def close(self) -> None:
        self.db.close()

    def account(self, uid: str) -> dict | None:
        row = self.db.execute("SELECT uid,username FROM accounts WHERE uid=?", (uid,)).fetchone()
        return dict(row) if row else None

    def username(self, username: str) -> dict | None:
        row = self.db.execute("SELECT uid,username FROM accounts WHERE username_key=?",
                              (username.casefold(),)).fetchone()
        return dict(row) if row else None

    def register(self, uid: str, username: str) -> dict:
        found = self.account(uid)
        if found:
            return found
        if self.db.execute("SELECT COUNT(*) FROM accounts").fetchone()[0] >= 100000:
            raise StoreError("registration_unavailable")
        try:
            self.db.execute("INSERT INTO accounts VALUES(?,?,?,?)",
                            (uid, username, username.casefold(), int(time.time())))
        except sqlite3.IntegrityError as error:
            raise StoreError("username_taken") from error
        return {"uid": uid, "username": username}

    def is_friend(self, owner: str, friend: str) -> bool:
        return self.db.execute("SELECT 1 FROM friendships WHERE owner=? AND friend=?",
                               (owner, friend)).fetchone() is not None

    def friends(self, owner: str) -> list[dict]:
        return [dict(row) for row in self.db.execute(
            "SELECT a.uid,a.username FROM friendships f JOIN accounts a ON a.uid=f.friend "
            "WHERE f.owner=? ORDER BY a.username_key LIMIT ?", (owner, MAX_FRIENDS))]

    def requests(self, target: str) -> list[dict]:
        self.expire_requests()
        return [dict(row) for row in self.db.execute(
            "SELECT r.request_id,a.uid,a.username,r.created FROM friend_requests r "
            "JOIN accounts a ON a.uid=r.sender WHERE r.target=? ORDER BY r.created "
            "LIMIT ?", (target, MAX_PENDING))]

    def expire_requests(self) -> None:
        self.db.execute("DELETE FROM friend_requests WHERE created<?",
                        (int(time.time()) - REQUEST_DAYS * 86400,))

    def request_friend(self, sender: str, username: str) -> dict:
        self.expire_requests()
        target = self.username(username)
        if target is None:
            raise StoreError("username_not_found")
        uid = target["uid"]
        if sender == uid:
            raise StoreError("cannot_invite_self")
        if self.is_friend(sender, uid):
            raise StoreError("already_friends")
        if len(self.friends(sender)) >= MAX_FRIENDS or len(self.friends(uid)) >= MAX_FRIENDS:
            raise StoreError("friends_full")
        existing = self.db.execute("SELECT request_id FROM friend_requests WHERE sender=? AND target=?",
                                    (sender, uid)).fetchone()
        if existing:
            return {"request_id": existing[0], "uid": uid, "username": target["username"]}
        for column, value in (("sender", sender), ("target", uid)):
            # column is an internal fixed identifier, not client input.
            count = self.db.execute(f"SELECT COUNT(*) FROM friend_requests WHERE {column}=?", (value,)).fetchone()[0]
            if count >= MAX_PENDING:
                raise StoreError("friend_requests_full")
        request_id = secrets.token_hex(16)
        self.db.execute("INSERT INTO friend_requests VALUES(?,?,?,?)",
                        (request_id, sender, uid, int(time.time())))
        return {"request_id": request_id, "uid": uid, "username": target["username"]}

    def accept_friend(self, target: str, request_id: str) -> str:
        self.expire_requests()
        request = self.db.execute("SELECT sender FROM friend_requests WHERE request_id=? AND target=?",
                                   (request_id, target)).fetchone()
        if request is None:
            raise StoreError("friend_request_expired")
        sender = request[0]
        if len(self.friends(sender)) >= MAX_FRIENDS or len(self.friends(target)) >= MAX_FRIENDS:
            raise StoreError("friends_full")
        self.db.execute("BEGIN IMMEDIATE")
        try:
            created = int(time.time())
            self.db.executemany("INSERT OR IGNORE INTO friendships VALUES(?,?,?)",
                                [(sender, target, created), (target, sender, created)])
            self.db.execute("DELETE FROM friend_requests WHERE "
                            "(sender=? AND target=?) OR (sender=? AND target=?)",
                            (sender, target, target, sender))
            self.db.execute("COMMIT")
        except Exception:
            self.db.execute("ROLLBACK")
            raise
        return sender

    def decline_friend(self, target: str, request_id: str) -> None:
        self.db.execute("DELETE FROM friend_requests WHERE target=? AND request_id=?", (target, request_id))

    def remove_friend(self, owner: str, friend: str) -> None:
        self.db.execute("BEGIN IMMEDIATE")
        try:
            self.db.execute("DELETE FROM friendships WHERE (owner=? AND friend=?) OR (owner=? AND friend=?)",
                            (owner, friend, friend, owner))
            self.db.execute("COMMIT")
        except Exception:
            self.db.execute("ROLLBACK")
            raise
