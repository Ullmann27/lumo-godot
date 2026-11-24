"""Authenticated, bounded two-player WebSocket relay for Lumo Kart.

Names and mutually accepted friendships are stored in SQLite on a durable
volume. A random 256-bit device key proves identity over TLS; its one-way hash
identifies the account internally. Only active race sessions are in memory.
No credentials, payloads or IP addresses are written to application logs.

The server owns invitations, course agreement, the shared clock and result
timing. Clients simulate their normal kart physics and exchange checked poses.
This friendly mode is not a server-authoritative physics or ranking service.
"""
from __future__ import annotations

import asyncio
import contextlib
import hashlib
import json
import math
import os
import re
import secrets
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from typing import Any

from aiohttp import WSMsgType, web
from storage import Store, StoreError

PROTOCOL = 1
MAX_PACKET = 4096
MAX_CONNECTIONS = 256
MAX_IP_CONNECTIONS = 8
MAX_INVITES = 8
INVITE_SECONDS = 60.0
ROOM_SECONDS = 180.0
RACE_SECONDS = 1200.0
TRACKS = frozenset((
    "sonnenhafen", "zauberwald", "bergwelt", "holo_city", "crystal_canyon",
    "jungle_temple", "candy_cloud", "volcano_night", "winter_sprint",
    "galaxy_ringway", "desert_drift", "learning_lab", "jungle_emerald_3600",
    "riesengarten_2400", "windwerk_3000",
))
ALIAS_RE = re.compile(r"[A-Za-z][A-Za-z0-9_]{2,19}\Z")
KEY_RE = re.compile(r"[0-9a-f]{64}\Z")
ID_RE = re.compile(r"[a-z0-9_]{1,40}\Z")
VERSION_RE = re.compile(r"[a-z0-9_:.-]{1,64}\Z")
APP_RELAY = web.AppKey("lumo_relay")


def now_ms() -> int:
    return time.monotonic_ns() // 1_000_000


def device_id(key: str) -> str:
    return hashlib.sha256(bytes.fromhex(key)).hexdigest()


def finite(value: Any, low: float, high: float) -> bool:
    return type(value) in (int, float) and low <= value <= high and math.isfinite(value)


def clean_info(raw: Any) -> dict[str, Any] | None:
    if not isinstance(raw, dict):
        return None
    result: dict[str, Any] = {}
    for name in ("driver", "kart"):
        value = raw.get(name)
        if not isinstance(value, str) or not ID_RE.fullmatch(value):
            return None
        result[name] = value
    look = raw.get("look", {})
    if not isinstance(look, dict) or len(look) > 24:
        return None
    result["look"] = {}
    for key, value in look.items():
        if (not isinstance(key, str) or not ID_RE.fullmatch(key)
                or not isinstance(value, str) or not ID_RE.fullmatch(value)):
            return None
        result["look"][key] = value
    colors = raw.get("colors", {})
    allowed_colors = {"paint", "trim", "accent", "neon", "rim", "two_tone", "cockpit"}
    if not isinstance(colors, dict) or len(colors) > len(allowed_colors):
        return None
    result["colors"] = {}
    for key, value in colors.items():
        if key not in allowed_colors or not isinstance(value, str) or re.fullmatch(r"[0-9a-f]{8}", value) is None:
            return None
        result["colors"][key] = value
    return result


@dataclass(eq=False)
class Peer:
    ws: web.WebSocketResponse
    uid: str = ""
    address: str = ""
    handle: str = ""
    room: str = ""
    started: float = field(default_factory=time.monotonic)
    rates: dict[str, deque[float]] = field(default_factory=lambda: defaultdict(deque))
    target_invites: dict[str, float] = field(default_factory=dict)
    bad_packets: int = 0

    def allowed(self, kind: str, maximum: int, window: float) -> bool:
        queue = self.rates[kind]
        now = time.monotonic()
        while queue and queue[0] < now - window:
            queue.popleft()
        if len(queue) >= maximum:
            return False
        queue.append(now)
        return True


@dataclass
class Invitation:
    key: str
    sender: Peer
    target: Peer
    track: str
    info: dict[str, Any]
    expiry: float


@dataclass
class Room:
    key: str
    peers: tuple[Peer, Peer]
    track: str
    info: dict[str, dict[str, Any]]
    created: float = field(default_factory=time.monotonic)
    ready: set[str] = field(default_factory=set)
    loaded: dict[str, tuple[str, float, int]] = field(default_factory=dict)
    state: str = "lobby"
    start_ms: int = 0
    last: dict[str, dict[str, Any]] = field(default_factory=dict)
    finishes: dict[str, float] = field(default_factory=dict)


class Relay:
    def __init__(self, database_path: str, *, start_delay_ms: int = 4500) -> None:
        self.store = Store(database_path)
        self.registrations: dict[str, deque[float]] = defaultdict(deque)
        self.peers: dict[str, Peer] = {}
        self.sockets: set[Peer] = set()
        self.invites: dict[str, Invitation] = {}
        self.rooms: dict[str, Room] = {}
        self.ip_connections: dict[str, int] = defaultdict(int)
        self.start_delay_ms = start_delay_ms
        self._cleanup_task: asyncio.Task[None] | None = None

    async def send(self, peer: Peer, payload: dict[str, Any]) -> None:
        if peer.ws.closed:
            return
        try:
            async with asyncio.timeout(2.0):
                await peer.ws.send_json(payload, dumps=lambda p: json.dumps(p, allow_nan=False))
        except (TimeoutError, ConnectionError, RuntimeError):
            await peer.ws.close(code=1011, message=b"slow connection")

    async def error(self, peer: Peer, code: str) -> None:
        await self.send(peer, {"t": "error", "code": code})

    async def broadcast(self, room: Room, payload: dict[str, Any]) -> None:
        await asyncio.gather(*(self.send(p, payload) for p in room.peers))

    async def websocket(self, request: web.Request) -> web.StreamResponse:
        # The deployment terminates TLS. Untrusted forwarding headers are not
        # used for identity or per-transport limits.
        address = request.remote or "unknown"
        if len(self.sockets) >= MAX_CONNECTIONS or self.ip_connections[address] >= MAX_IP_CONNECTIONS:
            raise web.HTTPServiceUnavailable(text="The race relay is busy. Try again shortly.")
        ws = web.WebSocketResponse(max_msg_size=MAX_PACKET, heartbeat=15.0, autoping=True,
                                   compress=False, receive_timeout=45.0)
        await ws.prepare(request)
        peer = Peer(ws, address=address)
        self.sockets.add(peer)
        self.ip_connections[address] += 1
        try:
            async for packet in ws:
                if packet.type == WSMsgType.TEXT:
                    if len(packet.data.encode("utf-8")) > MAX_PACKET:
                        await ws.close(code=1009)
                        break
                    try:
                        message = json.loads(packet.data, parse_constant=lambda _: None)
                    except (ValueError, TypeError, RecursionError):
                        message = None
                    if not isinstance(message, dict):
                        await self.bad(peer, "invalid_packet")
                        continue
                    await self.handle(peer, message)
                elif packet.type == WSMsgType.BINARY:
                    await self.bad(peer, "text_packets_only")
                elif packet.type == WSMsgType.ERROR:
                    break
        except TimeoutError:
            pass
        finally:
            await self.disconnected(peer)
            self.sockets.discard(peer)
            self.ip_connections[address] -= 1
            if self.ip_connections[address] <= 0:
                del self.ip_connections[address]
        return ws

    async def bad(self, peer: Peer, reason: str) -> None:
        peer.bad_packets += 1
        await self.error(peer, reason)
        if peer.bad_packets >= 8:
            await peer.ws.close(code=1008, message=b"invalid protocol")

    async def handle(self, peer: Peer, message: dict[str, Any]) -> None:
        kind = message.get("t")
        if not isinstance(kind, str):
            await self.bad(peer, "invalid_packet")
            return
        allowed = peer.allowed("state", 28, 1.0) if kind == "state" else peer.allowed("control", 30, 10.0)
        if not allowed:
            await self.bad(peer, "rate_limited")
            return
        if not peer.uid:
            if kind != "hello":
                await self.bad(peer, "authentication_required")
            else:
                await self.hello(peer, message)
            return
        if kind == "ping":
            stamp = message.get("client_ms")
            if type(stamp) is int and 0 <= stamp < 2**53:
                await self.send(peer, {"t": "pong", "client_ms": stamp, "server_ms": now_ms()})
            else:
                await self.bad(peer, "invalid_packet")
        elif kind == "friend_request":
            await self.request_friend(peer, message)
        elif kind == "friend_accept":
            await self.accept_friend(peer, message)
        elif kind == "friend_decline":
            self.store.decline_friend(peer.uid, str(message.get("request", "")))
            await self.send_friend_requests(peer)
        elif kind == "friends":
            await self.send_friends(peer)
            await self.send_friend_requests(peer)
        elif kind == "friend_remove":
            target = str(message.get("id", ""))
            if peer.room:
                await self.error(peer, "already_in_room")
                return
            self.store.remove_friend(peer.uid, target)
            await self.send_friends(peer)
            if target in self.peers:
                await self.send_friends(self.peers[target])
        elif kind == "invite":
            await self.invite(peer, message)
        elif kind == "accept":
            await self.accept(peer, message)
        elif kind == "decline":
            invitation = self.invites.get(str(message.get("invite", "")))
            if invitation is not None and invitation.target is peer:
                self.invites.pop(invitation.key, None)
                await self.send(invitation.sender, {"t": "declined", "handle": peer.handle})
        elif kind == "ready":
            await self.ready(peer, message)
        elif kind == "loaded":
            await self.loaded(peer, message)
        elif kind == "state":
            await self.race_state(peer, message)
        elif kind == "finish":
            await self.finish(peer)
        elif kind == "leave":
            await self.leave_room(peer, "friend_left")
        else:
            await self.bad(peer, "unknown_message")

    async def hello(self, peer: Peer, message: dict[str, Any]) -> None:
        key, alias = message.get("key"), message.get("alias")
        if (type(message.get("v")) is not int or message["v"] != PROTOCOL
                or not isinstance(key, str) or not KEY_RE.fullmatch(key)
                or not isinstance(alias, str) or not ALIAS_RE.fullmatch(alias)):
            await self.bad(peer, "invalid_identity")
            return
        uid = device_id(key)
        if uid in self.peers:
            await self.error(peer, "identity_already_online")
            await peer.ws.close(code=1008)
            return
        if self.store.account(uid) is None:
            recent = self.registrations[peer.address]
            now = time.monotonic()
            while recent and recent[0] < now - 3600.0:
                recent.popleft()
            if len(recent) >= 10:
                await self.error(peer, "registration_limited")
                return
            recent.append(now)
        try:
            account = self.store.register(uid, alias)
        except StoreError as error:
            await self.error(peer, str(error))
            return
        peer.uid = uid
        peer.handle = account["username"]
        self.peers[uid] = peer
        await self.send(peer, {"t": "welcome", "v": PROTOCOL, "id": uid,
                               "handle": peer.handle, "server_ms": now_ms()})
        await self.send_friends(peer)
        await self.send_friend_requests(peer)
        await self.notify_presence(peer.uid)

    async def send_friends(self, peer: Peer) -> None:
        friends = [{**account, "online": account["uid"] in self.peers}
                   for account in self.store.friends(peer.uid)]
        await self.send(peer, {"t": "friends", "friends": friends})

    async def send_friend_requests(self, peer: Peer) -> None:
        await self.send(peer, {"t": "friend_requests", "requests": self.store.requests(peer.uid)})

    async def notify_presence(self, uid: str) -> None:
        for friend in self.store.friends(uid):
            if friend["uid"] in self.peers:
                await self.send_friends(self.peers[friend["uid"]])

    async def request_friend(self, peer: Peer, message: dict[str, Any]) -> None:
        username = message.get("username")
        if not isinstance(username, str) or not ALIAS_RE.fullmatch(username):
            await self.error(peer, "invalid_username")
            return
        if not peer.allowed("friend_request", 5, 60.0):
            await self.error(peer, "invite_limit")
            return
        try:
            request = self.store.request_friend(peer.uid, username)
        except StoreError as error:
            await self.error(peer, str(error))
            return
        await self.send(peer, {"t": "friend_request_sent", "username": request["username"]})
        target = self.peers.get(request["uid"])
        if target is not None:
            await self.send_friend_requests(target)

    async def accept_friend(self, peer: Peer, message: dict[str, Any]) -> None:
        try:
            sender_id = self.store.accept_friend(peer.uid, str(message.get("request", "")))
        except StoreError as error:
            await self.error(peer, str(error))
            return
        await self.send_friend_requests(peer)
        await self.send_friends(peer)
        if sender_id in self.peers:
            await self.send_friend_requests(self.peers[sender_id])
            await self.send_friends(self.peers[sender_id])

    async def invite(self, peer: Peer, message: dict[str, Any]) -> None:
        uid = message.get("to")
        info, track = clean_info(message.get("info")), message.get("track")
        if (not isinstance(uid, str) or not KEY_RE.fullmatch(uid) or info is None
                or not isinstance(track, str) or track not in TRACKS):
            await self.bad(peer, "invalid_invitation")
            return
        if peer.room:
            await self.error(peer, "already_in_room")
            return
        if not self.store.is_friend(peer.uid, uid):
            await self.error(peer, "not_friends")
            return
        target = self.peers.get(uid)
        if target is None:
            await self.error(peer, "friend_offline")
            return
        if target.room:
            await self.error(peer, "friend_busy")
            return
        if not peer.allowed("invite", 5, 60.0):
            await self.error(peer, "invite_limit")
            return
        now = time.monotonic()
        if now - peer.target_invites.get(uid, -1000.0) < 15.0:
            await self.error(peer, "invite_pending")
            return
        if sum(i.target is target for i in self.invites.values()) >= MAX_INVITES:
            await self.error(peer, "friend_busy")
            return
        peer.target_invites = {k: v for k, v in peer.target_invites.items() if now - v < 60.0}
        peer.target_invites[uid] = now
        invitation = Invitation(secrets.token_hex(16), peer, target, track, info, now + INVITE_SECONDS)
        self.invites[invitation.key] = invitation
        await self.send(target, {"t": "invitation", "invite": invitation.key,
                                "from": peer.handle, "track": track, "expires_in": 60})
        await self.send(peer, {"t": "invite_sent", "to": target.handle, "invite": invitation.key})

    async def accept(self, peer: Peer, message: dict[str, Any]) -> None:
        invitation = self.invites.get(str(message.get("invite", "")))
        info = clean_info(message.get("info"))
        if invitation is None or invitation.target is not peer or info is None:
            await self.error(peer, "invitation_expired")
            return
        if time.monotonic() > invitation.expiry:
            self.invites.pop(invitation.key, None)
            await self.error(peer, "invitation_expired")
            return
        host = invitation.sender
        if host.uid not in self.peers or host.room or peer.room:
            await self.error(peer, "friend_busy")
            return
        key = secrets.token_hex(16)
        room = Room(key, (host, peer), invitation.track, {host.uid: invitation.info, peer.uid: info})
        self.rooms[key] = room
        host.room = peer.room = key
        for invitation_id, pending in tuple(self.invites.items()):
            if pending.sender in room.peers or pending.target in room.peers:
                del self.invites[invitation_id]
        await self.broadcast(room, {"t": "room", "room": key, "track": room.track,
                                    "players": [{"id": p.uid, "handle": p.handle,
                                                 **room.info[p.uid]} for p in room.peers]})

    async def ready(self, peer: Peer, message: dict[str, Any]) -> None:
        room = self.rooms.get(peer.room)
        if room is None or room.state != "lobby":
            await self.error(peer, "not_in_lobby")
            return
        if "info" in message:
            info = clean_info(message["info"])
            if info is None:
                await self.bad(peer, "invalid_loadout")
                return
            room.info[peer.uid] = info
        room.ready.add(peer.uid)
        await self.broadcast(room, {"t": "ready", "ids": sorted(room.ready)})
        if len(room.ready) == 2 and room.state == "lobby":
            room.state = "loading"
            await self.broadcast(room, {"t": "prepare", "room": room.key, "track": room.track,
                                        "players": [{"id": p.uid, "handle": p.handle,
                                                     **room.info[p.uid]} for p in room.peers]})

    async def loaded(self, peer: Peer, message: dict[str, Any]) -> None:
        room = self.rooms.get(peer.room)
        if room is None or room.state != "loading":
            await self.error(peer, "not_loading")
            return
        version, length, laps = message.get("version"), message.get("length"), message.get("laps")
        if (not isinstance(version, str) or not VERSION_RE.fullmatch(version)
                or not finite(length, 200.0, 20000.0) or type(laps) is not int or not 1 <= laps <= 5):
            await self.bad(peer, "invalid_course")
            return
        room.loaded[peer.uid] = (version, float(length), laps)
        if len(room.loaded) < 2:
            return
        left, right = (room.loaded[p.uid] for p in room.peers)
        if left[0] != right[0] or abs(left[1] - right[1]) > 0.5 or left[2] != right[2]:
            await self.broadcast(room, {"t": "error", "code": "course_mismatch"})
            await self.leave_room(peer, "course_mismatch")
            return
        room.state = "racing"
        room.start_ms = now_ms() + self.start_delay_ms
        await self.broadcast(room, {"t": "start", "room": room.key,
                                    "start_ms": room.start_ms, "server_ms": now_ms()})

    async def race_state(self, peer: Peer, message: dict[str, Any]) -> None:
        room = self.rooms.get(peer.room)
        if room is None or room.state != "racing" or peer.uid in room.finishes:
            return
        stamp = now_ms()
        if stamp < room.start_ms:
            return
        seq, position, quaternion = message.get("seq"), message.get("p"), message.get("q")
        speed, steer = message.get("speed"), message.get("steer")
        progress, checkpoint = message.get("distance"), message.get("checkpoint")
        _, length, laps = room.loaded[peer.uid]
        if (type(seq) is not int or not 0 <= seq < 2**31
                or not isinstance(position, list) or len(position) != 3
                or not all(finite(x, -20000, 20000) for x in position)
                or not isinstance(quaternion, list) or len(quaternion) != 4
                or not all(finite(x, -1.01, 1.01) for x in quaternion)
                or not 0.9 <= sum(x * x for x in quaternion) <= 1.1
                or not finite(speed, -80.0, 180.0) or not finite(steer, -1.0, 1.0)
                or not finite(progress, -100.0, length * (laps + 0.2))
                or type(checkpoint) is not int or not 0 <= checkpoint <= laps * 8):
            await self.bad(peer, "invalid_state")
            return
        previous = room.last.get(peer.uid)
        if previous is not None:
            if seq <= previous["seq"]:
                return
            span = (stamp - previous["stamp"]) / 1000.0
            if progress - previous["distance"] > 180.0 * span + 25.0:
                await self.bad(peer, "invalid_progress")
                return
            if not 0 <= checkpoint - previous["checkpoint"] <= 2:
                await self.bad(peer, "invalid_progress")
                return
        elif progress > max(50.0, (stamp - room.start_ms) * 0.18 + 25.0) or checkpoint > 1:
            await self.bad(peer, "invalid_progress")
            return
        room.last[peer.uid] = {"seq": seq, "stamp": stamp, "distance": progress, "checkpoint": checkpoint}
        snapshot = {"t": "state", "id": peer.uid, "seq": seq,
                    "k": (stamp - room.start_ms) / 1000.0, "p": position, "q": quaternion,
                    "speed": speed, "steer": steer, "distance": progress, "checkpoint": checkpoint}
        other = room.peers[1] if room.peers[0] is peer else room.peers[0]
        await self.send(other, snapshot)

    async def finish(self, peer: Peer) -> None:
        room = self.rooms.get(peer.room)
        if room is None or room.state != "racing" or peer.uid in room.finishes:
            return
        _, length, laps = room.loaded[peer.uid]
        last = room.last.get(peer.uid)
        elapsed = (now_ms() - room.start_ms) / 1000.0
        if (last is None or last["checkpoint"] < laps * 8 or last["distance"] < length * laps - 1.0
                or elapsed < length * laps / 180.0 or elapsed > RACE_SECONDS):
            await self.error(peer, "finish_not_verified")
            return
        room.finishes[peer.uid] = elapsed
        await self.broadcast(room, {"t": "finish", "id": peer.uid, "time": elapsed})
        if len(room.finishes) == 2:
            room.state = "finished"
            order = sorted(room.peers, key=lambda p: room.finishes[p.uid])
            difference = abs(room.finishes[order[0].uid] - room.finishes[order[1].uid])
            await self.broadcast(room, {"t": "result", "room": room.key,
                                        "winner": "" if difference < 0.05 else order[0].uid,
                                        "times": room.finishes})

    async def leave_room(self, peer: Peer, reason: str) -> None:
        room = self.rooms.pop(peer.room, None)
        if room is None:
            peer.room = ""
            return
        for member in room.peers:
            member.room = ""
            await self.send(member, {"t": "room_closed", "reason": reason,
                                     "by": peer.uid, "room": room.key})

    async def disconnected(self, peer: Peer) -> None:
        if peer.uid and self.peers.get(peer.uid) is peer:
            del self.peers[peer.uid]
        await self.leave_room(peer, "connection_lost")
        if peer.uid:
            await self.notify_presence(peer.uid)
        for key, invitation in tuple(self.invites.items()):
            if invitation.sender is peer or invitation.target is peer:
                del self.invites[key]
                other = invitation.target if invitation.sender is peer else invitation.sender
                await self.send(other, {"t": "invitation_expired", "invite": key})

    async def sweep(self) -> None:
        now = time.monotonic()
        for address, recent in tuple(self.registrations.items()):
            while recent and recent[0] < now - 3600.0:
                recent.popleft()
            if not recent:
                del self.registrations[address]
        self.store.expire_requests()
        for peer in tuple(self.sockets):
            if not peer.uid and now - peer.started > 10.0:
                await peer.ws.close(code=1008, message=b"authentication timeout")
        for key, invitation in tuple(self.invites.items()):
            if now > invitation.expiry:
                del self.invites[key]
                for peer in (invitation.sender, invitation.target):
                    await self.send(peer, {"t": "invitation_expired", "invite": key})
        for room in tuple(self.rooms.values()):
            expiry = RACE_SECONDS if room.state in ("racing", "finished") else ROOM_SECONDS
            since = room.start_ms / 1000.0 if room.start_ms else room.created
            if now - since > expiry:
                await self.leave_room(room.peers[0], "room_expired")

    async def start(self, _app: web.Application) -> None:
        async def loop() -> None:
            while True:
                await asyncio.sleep(5)
                await self.sweep()
        self._cleanup_task = asyncio.create_task(loop())

    async def stop(self, _app: web.Application) -> None:
        if self._cleanup_task is not None:
            self._cleanup_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await self._cleanup_task
        await asyncio.gather(*(p.ws.close(code=1001, message=b"server restart") for p in tuple(self.sockets)))


def make_app(*, database_path: str = ":memory:", start_delay_ms: int = 4500) -> web.Application:
    app = web.Application(client_max_size=MAX_PACKET)
    relay = Relay(database_path, start_delay_ms=start_delay_ms)
    app[APP_RELAY] = relay
    app.router.add_get("/ws", relay.websocket)

    async def health(_request: web.Request) -> web.Response:
        return web.json_response({"service": "lumo-kart-online", "protocol": PROTOCOL, "status": "ok"})

    app.router.add_get("/health", health)
    app.on_startup.append(relay.start)
    app.on_shutdown.append(relay.stop)

    async def close_store(_app: web.Application) -> None:
        relay.store.close()

    app.on_cleanup.append(close_store)
    return app


if __name__ == "__main__":
    # Local by default. Public hosting must set HOST and terminate HTTPS/WSS.
    database = os.environ.get("LUMO_DATABASE_PATH", "data/lumo-kart.sqlite3")
    if database == ":memory:":
        raise SystemExit("Production requires a persistent LUMO_DATABASE_PATH")
    web.run_app(make_app(database_path=database), host=os.environ.get("HOST", "127.0.0.1"),
                port=int(os.environ.get("PORT", "8765")), access_log=None)
