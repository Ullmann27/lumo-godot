"""Real loopback WebSocket integration tests, with independent client sockets."""
from __future__ import annotations

import asyncio
import hashlib
import json
import secrets
import time
import unittest
from collections import deque

import aiohttp
from aiohttp import WSMsgType
from aiohttp.test_utils import TestServer

from relay import APP_RELAY, clean_info, device_id, finite, make_app

INFO = {"driver": "fox", "kart": "comet", "look": {"engine": "serie"}}


class Client:
    def __init__(self, websocket: aiohttp.ClientWebSocketResponse, key: str) -> None:
        self.ws = websocket
        self.key = key
        self.uid = device_id(key)
        self.handle = ""
        self.pending: deque[dict] = deque()

    async def send(self, **message) -> None:
        await self.ws.send_json(message)

    async def receive(self, kind: str, timeout: float = 3.0) -> dict:
        for i, message in enumerate(self.pending):
            if message.get("t") == kind:
                del self.pending[i]
                return message
        async with asyncio.timeout(timeout):
            while True:
                packet = await self.ws.receive()
                if packet.type != WSMsgType.TEXT:
                    raise AssertionError(f"Expected {kind}; socket state: {packet.type}")
                message = json.loads(packet.data)
                if message.get("t") == kind:
                    return message
                self.pending.append(message)


class RelayIntegration(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.app = make_app(start_delay_ms=30)
        self.server = TestServer(self.app)
        await self.server.start_server()
        self.http = aiohttp.ClientSession()
        self.clients: list[Client] = []

    async def asyncTearDown(self) -> None:
        for client in self.clients:
            await client.ws.close()
        await self.http.close()
        await self.server.close()

    async def connect(self, alias: str, key: str | None = None) -> Client:
        client = Client(await self.http.ws_connect(self.server.make_url("/ws")), key or secrets.token_hex(32))
        self.clients.append(client)
        await client.send(t="hello", v=1, alias=alias, key=client.key)
        welcome = await client.receive("welcome")
        self.assertEqual(welcome["id"], client.uid)
        self.assertNotIn("key", welcome)
        client.handle = welcome["handle"]
        return client

    async def invite_pair(self) -> tuple[Client, Client, dict]:
        first, second = await self.connect("LumoAlpha"), await self.connect("LumoBeta")
        await first.send(t="invite", to=second.handle, track="sonnenhafen", info=INFO)
        invitation = await second.receive("invitation")
        sent = await first.receive("invite_sent")
        self.assertEqual(invitation["invite"], sent["invite"])
        self.assertEqual(invitation["from"], first.handle)
        return first, second, invitation

    async def room_pair(self) -> tuple[Client, Client]:
        first, second, invitation = await self.invite_pair()
        await second.send(t="accept", invite=invitation["invite"], info=INFO)
        a, b = await first.receive("room"), await second.receive("room")
        self.assertEqual(a, b)
        self.assertEqual(a["track"], "sonnenhafen")
        self.assertEqual({p["id"] for p in a["players"]}, {first.uid, second.uid})
        return first, second

    async def racing_pair(self) -> tuple[Client, Client]:
        first, second = await self.room_pair()
        await first.send(t="ready")
        await second.send(t="ready")
        await first.receive("prepare")
        await second.receive("prepare")
        for client in (first, second):
            await client.send(t="loaded", version="test:route:1", length=200.0, laps=1)
        a, b = await first.receive("start"), await second.receive("start")
        self.assertEqual(a["start_ms"], b["start_ms"])
        self.assertGreater(a["start_ms"], a["server_ms"])
        await asyncio.sleep(0.05)
        return first, second

    async def send_pose(self, client: Client, seq: int, distance: float, checkpoint: int, **changes) -> None:
        pose = {"t": "state", "seq": seq, "p": [distance, 1.0, 0.0],
                "q": [0.0, 0.0, 0.0, 1.0], "speed": 60.0, "steer": 0.2,
                "distance": distance, "checkpoint": checkpoint}
        pose.update(changes)
        await client.ws.send_json(pose)

    async def test_health_discloses_no_players_or_credentials(self) -> None:
        async with self.http.get(self.server.make_url("/health")) as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(await response.json(),
                             {"service": "lumo-kart-online", "protocol": 1, "status": "ok"})

    async def test_same_alias_has_distinct_stable_device_identity(self) -> None:
        first, second = await self.connect("SameAlias"), await self.connect("SameAlias")
        self.assertNotEqual(first.handle, second.handle)
        self.assertEqual(first.uid, hashlib.sha256(bytes.fromhex(first.key)).hexdigest()[:16])
        key, old_handle = first.key, first.handle
        await first.ws.close()
        await asyncio.sleep(0.02)
        again = await self.connect("SameAlias", key)
        self.assertEqual(again.handle, old_handle)

    async def test_live_identity_cannot_be_taken_over(self) -> None:
        first = await self.connect("LumoAlpha")
        duplicate = Client(await self.http.ws_connect(self.server.make_url("/ws")), first.key)
        self.clients.append(duplicate)
        await duplicate.send(t="hello", v=1, alias="Imposter", key=first.key)
        error = await duplicate.receive("error")
        self.assertEqual(error["code"], "identity_already_online")
        self.assertEqual(self.app[APP_RELAY].peers[first.uid].handle, first.handle)

    async def test_pre_authentication_commands_are_rejected(self) -> None:
        client = Client(await self.http.ws_connect(self.server.make_url("/ws")), secrets.token_hex(32))
        self.clients.append(client)
        await client.send(t="invite", to="Name#0000000000000000", track="sonnenhafen", info=INFO)
        self.assertEqual((await client.receive("error"))["code"], "authentication_required")

    async def test_online_names_invitation_accept_and_course_barrier(self) -> None:
        first, second = await self.room_pair()
        await first.send(t="ready")
        self.assertEqual((await first.receive("ready"))["ids"], [first.uid])
        self.assertEqual(next(iter(self.app[APP_RELAY].rooms.values())).state, "lobby")
        await second.send(t="ready")
        await first.receive("prepare")
        await second.receive("prepare")
        await first.send(t="loaded", version="test:v1", length=1000.0, laps=2)
        await first.send(t="ping", client_ms=123)
        await first.receive("pong")
        self.assertEqual(next(iter(self.app[APP_RELAY].rooms.values())).state, "loading")
        await second.send(t="loaded", version="test:v1", length=1000.0, laps=2)
        a, b = await first.receive("start"), await second.receive("start")
        self.assertEqual(a["start_ms"], b["start_ms"])

    async def test_decline_never_creates_a_room(self) -> None:
        first, second, invitation = await self.invite_pair()
        await second.send(t="decline", invite=invitation["invite"])
        self.assertEqual((await first.receive("declined"))["handle"], second.handle)
        self.assertFalse(self.app[APP_RELAY].rooms)

    async def test_only_invited_identity_can_accept(self) -> None:
        first, second, invitation = await self.invite_pair()
        stranger = await self.connect("Stranger")
        await stranger.send(t="accept", invite=invitation["invite"], info=INFO)
        self.assertEqual((await stranger.receive("error"))["code"], "invitation_expired")
        self.assertFalse(self.app[APP_RELAY].rooms)
        self.assertIn(invitation["invite"], self.app[APP_RELAY].invites)

    async def test_expired_invitation_is_removed_and_cannot_be_replayed(self) -> None:
        first, second, invitation = await self.invite_pair()
        self.app[APP_RELAY].invites[invitation["invite"]].expiry = time.monotonic() - 1
        await self.app[APP_RELAY].sweep()
        self.assertEqual((await second.receive("invitation_expired"))["invite"], invitation["invite"])
        await second.send(t="accept", invite=invitation["invite"], info=INFO)
        self.assertEqual((await second.receive("error"))["code"], "invitation_expired")
        self.assertFalse(self.app[APP_RELAY].rooms)

    async def test_mismatched_courses_abort_before_start(self) -> None:
        first, second = await self.room_pair()
        for client in (first, second):
            await client.send(t="ready")
        await first.receive("prepare")
        await second.receive("prepare")
        await first.send(t="loaded", version="old:v1", length=1000.0, laps=2)
        await second.send(t="loaded", version="new:v2", length=1000.0, laps=2)
        self.assertEqual((await first.receive("error"))["code"], "course_mismatch")
        await second.receive("room_closed")
        self.assertFalse(self.app[APP_RELAY].rooms)

    async def test_pose_is_live_bidirectional_and_quaternion_preserved(self) -> None:
        first, second = await self.racing_pair()
        q = [0.0, 0.0, 1.0, 0.0]  # upside down in a real loop
        await self.send_pose(first, 1, 0.0, 0, q=q)
        a = await second.receive("state")
        self.assertEqual(a["id"], first.uid)
        self.assertEqual(a["q"], q)
        await self.send_pose(second, 1, 0.0, 0)
        b = await first.receive("state")
        self.assertEqual(b["id"], second.uid)
        self.assertNotIn("key", b)
        self.assertGreaterEqual(b["k"], 0.0)

    async def test_replayed_pose_cannot_change_progress(self) -> None:
        first, second = await self.racing_pair()
        await self.send_pose(first, 5, 10.0, 0)
        await second.receive("state")
        await self.send_pose(first, 5, 199.0, 8)
        await first.send(t="ping", client_ms=1)
        await first.receive("pong")
        room = next(iter(self.app[APP_RELAY].rooms.values()))
        self.assertEqual(room.last[first.uid]["distance"], 10.0)
        with self.assertRaises(TimeoutError):
            await second.receive("state", timeout=0.08)

    async def test_invalid_numbers_quaternion_and_finish_cannot_win(self) -> None:
        first, second = await self.racing_pair()
        await self.send_pose(first, 1, 0.0, 0, p=[10**600, 0, 0])
        self.assertEqual((await first.receive("error"))["code"], "invalid_state")
        await self.send_pose(first, 2, 0.0, 0, q=[0, 0, 0, 0])
        self.assertEqual((await first.receive("error"))["code"], "invalid_state")
        await first.send(t="finish", time=0.001)
        self.assertEqual((await first.receive("error"))["code"], "finish_not_verified")
        self.assertFalse(next(iter(self.app[APP_RELAY].rooms.values())).finishes)

    async def test_two_real_clients_complete_and_receive_identical_result(self) -> None:
        first, second = await self.racing_pair()
        for i in range(9):
            for client in (first, second):
                await self.send_pose(client, i + 1, i * 25.0, i)
            await first.receive("state")
            await second.receive("state")
            await asyncio.sleep(0.18)
        await first.send(t="finish")
        finish = await first.receive("finish")
        self.assertEqual(finish["id"], first.uid)
        self.assertGreater(finish["time"], 1.4)
        await asyncio.sleep(0.07)
        await second.send(t="finish")
        a, b = await first.receive("result"), await second.receive("result")
        self.assertEqual(a, b)
        self.assertEqual(a["winner"], first.uid)
        self.assertGreater(a["times"][second.uid], a["times"][first.uid])
        await first.send(t="finish")
        await first.send(t="ping", client_ms=4)
        await first.receive("pong")
        self.assertEqual(len(next(iter(self.app[APP_RELAY].rooms.values())).finishes), 2)

    async def test_disconnect_removes_room_and_notifies_friend(self) -> None:
        first, second = await self.racing_pair()
        await first.ws.close()
        message = await second.receive("room_closed")
        self.assertEqual(message["reason"], "connection_lost")
        self.assertFalse(self.app[APP_RELAY].rooms)
        self.assertNotIn(first.uid, self.app[APP_RELAY].peers)
        self.assertEqual(self.app[APP_RELAY].peers[second.uid].room, "")

    async def test_control_rate_limit_is_enforced(self) -> None:
        client = await self.connect("RateTest")
        for i in range(35):
            await client.send(t="ping", client_ms=i)
        self.assertEqual((await client.receive("error"))["code"], "rate_limited")

    async def test_bad_track_type_is_a_protocol_error_not_a_server_crash(self) -> None:
        first, second = await self.connect("LumoAlpha"), await self.connect("LumoBeta")
        await first.send(t="invite", to=second.handle, track={}, info=INFO)
        self.assertEqual((await first.receive("error"))["code"], "invalid_invitation")
        await first.send(t="ping", client_ms=9)
        self.assertEqual((await first.receive("pong"))["client_ms"], 9)


class BoundaryTests(unittest.TestCase):
    def test_finite_rejects_boolean_nan_infinity_and_huge_integer(self) -> None:
        for value in (True, False, float("nan"), float("inf"), 10**600, "1", None):
            self.assertFalse(finite(value, -10, 10))
        self.assertTrue(finite(3.0, -10, 10))

    def test_loadout_only_accepts_small_identifier_maps(self) -> None:
        self.assertIsNotNone(clean_info(INFO))
        self.assertIsNone(clean_info({"driver": "../a", "kart": "comet"}))
        self.assertIsNone(clean_info({"driver": "fox", "kart": "comet", "look": {"engine": {}}}))
        self.assertIsNone(clean_info({"driver": "fox", "kart": "comet", "look": {str(i): "a" for i in range(25)}}))


if __name__ == "__main__":
    unittest.main(verbosity=2)
