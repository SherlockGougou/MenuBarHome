#!/usr/bin/env python3
"""`scripts/mijia` 的回归测试：只读临时快照、注入假的 open 与假时钟，不打开真实应用。

运行：python3 scripts/test_mijia_cli.py
"""

from __future__ import annotations

import contextlib
import importlib.machinery
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from urllib.parse import parse_qs, urlparse

# Loading the extension-less script would otherwise drop a __pycache__ entry next to it.
sys.dont_write_bytecode = True

SCRIPT = Path(__file__).resolve().with_name("mijia")
_loader = importlib.machinery.SourceFileLoader("mijia_cli", str(SCRIPT))
_spec = importlib.util.spec_from_loader(_loader.name, _loader)
mijia = importlib.util.module_from_spec(_spec)
_loader.exec_module(mijia)

TOKEN = "t" * 40


def make_snapshot() -> dict:
    return {
        "schemaVersion": 1,
        "updatedAt": "2026-11-06T08:00:00.000Z",
        "bridgeToken": TOKEN,
        "connectionSummary": "Home Assistant · 米家云端直连",
        "isStale": False,
        "devices": [
            {
                "id": "dev_living_light",
                "name": "客厅吸顶灯",
                "roomId": "living",
                "roomName": "客厅",
                "roomSortOrder": 0,
                "category": "light",
                "categoryTitle": "灯",
                "model": "yeelink.light.ceiling",
                "stateText": "已开 · 80%",
                "isOnline": True,
                "isActiveOn": True,
                "isPrimaryToggleable": True,
                "isFavorite": True,
                "pinyinInitials": "ktxdd",
                "pinyinFull": "",
                "roomPinyinInitials": "kt",
                "capabilities": {"canTogglePower": True},
            },
            {
                "id": "dev_study_lamp",
                "name": "书房台灯",
                "roomId": "study",
                "roomName": "书房",
                "roomSortOrder": 1,
                "category": "light",
                "categoryTitle": "灯",
                "model": "yeelink.light.lamp",
                "stateText": "已关",
                "isOnline": True,
                "isActiveOn": False,
                "isPrimaryToggleable": True,
                "isFavorite": False,
                "pinyinInitials": "sftd",
                "pinyinFull": "",
                "roomPinyinInitials": "sf",
                "capabilities": {"canTogglePower": True},
            },
            {
                "id": "dev_study_ac",
                "name": "书房空调",
                "roomId": "study",
                "roomName": "书房",
                "roomSortOrder": 1,
                "category": "climate",
                "categoryTitle": "空调",
                "model": "xiaomi.aircondition.mc5",
                "stateText": "制冷 · 25°C",
                "isOnline": True,
                "isActiveOn": True,
                "isPrimaryToggleable": True,
                "isFavorite": False,
                "pinyinInitials": "sfkt",
                "pinyinFull": "",
                "roomPinyinInitials": "sf",
                "capabilities": {"canTogglePower": True},
            },
            {
                "id": "dev_balcony_lamp",
                "name": "阳台灯",
                "roomId": "living",
                "roomName": "客厅",
                "roomSortOrder": 0,
                "category": "light",
                "categoryTitle": "灯",
                "model": "yeelink.light.color1",
                "stateText": "离线",
                "isOnline": False,
                "isActiveOn": False,
                "isPrimaryToggleable": False,
                "isFavorite": False,
                "pinyinInitials": "ytd",
                "pinyinFull": "",
                "roomPinyinInitials": "kt",
                "capabilities": {"canTogglePower": False},
            },
        ],
        "quickActions": [
            {"id": "lightsOff", "name": "全屋关灯", "subtitle": "", "icon": "lightbulb.slash",
             "isEnabled": True, "affectedCount": 2, "pinyinInitials": "qwgd"},
            {"id": "allOff", "name": "一键全关", "subtitle": "", "icon": "power",
             "isEnabled": True, "affectedCount": 3, "pinyinInitials": "yjqg"},
            {"id": "undo", "name": "撤销上一步", "subtitle": "", "icon": "arrow.uturn.backward",
             "isEnabled": False, "affectedCount": 0, "pinyinInitials": "cxydb"},
        ],
        "scenes": [
            {"id": "scene_movie", "name": "观影模式", "entityId": "scene.movie", "roomName": None,
             "icon": "film.fill", "visualCategory": "movie", "pinyinInitials": "gyms",
             "pinyinFull": ""}
        ],
        "climate": [],
        "environmentReadings": [
            {"id": "sensor_living", "label": "沙发温湿度计", "roomName": "客厅", "temperature": 24.5,
             "humidity": 52, "battery": 90, "updatedAt": "2026-11-06T08:00:00.000Z",
             "pinyinInitials": "sfsd"}
        ],
        "lastCommandFeedback": None,
    }


class FakeApp:
    """替身：记录打开的链接，并按其中的 requestId 写回一条结果。"""

    def __init__(self, path: Path, *, respond: bool = True, is_error: bool = False, message: str = "已执行"):
        self.path = path
        self.opened: list[str] = []
        self.respond = respond
        self.is_error = is_error
        self.message = message

    def opener(self, url: str) -> None:
        self.opened.append(url)
        if not self.respond:
            return
        request_id = parse_qs(urlparse(url).query).get("id", [""])[0]
        snapshot = json.loads(self.path.read_text(encoding="utf-8"))
        snapshot["lastCommandFeedback"] = {
            "requestId": request_id,
            "command": urlparse(url).netloc,
            "message": self.message,
            "isError": self.is_error,
            "completedAt": "2026-11-06T08:00:01.000Z",
        }
        self.path.write_text(json.dumps(snapshot, ensure_ascii=False), encoding="utf-8")

    def query(self, index: int = -1) -> dict:
        return {key: values[0] for key, values in parse_qs(urlparse(self.opened[index]).query).items()}


class MijiaCliTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.path = Path(self.temp_dir.name) / "raycast-snapshot.json"
        self.write_snapshot(make_snapshot())
        self.clock = 0.0

    def write_snapshot(self, snapshot: dict) -> None:
        self.path.write_text(json.dumps(snapshot, ensure_ascii=False), encoding="utf-8")

    def now(self) -> float:
        return self.clock

    def sleep(self, seconds: float) -> None:
        self.clock += seconds

    def run_cli(self, argv: list[str], app: FakeApp | None = None, env: dict | None = None):
        app = app or FakeApp(self.path)
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = mijia.main(
                argv + ["--snapshot", str(self.path)],
                opener=app.opener,
                now=self.now,
                sleep=self.sleep,
                env=env or {},
            )
        return code, out.getvalue(), err.getvalue(), app

    def test_list_groups_devices_by_room_and_marks_offline(self) -> None:
        code, out, _, app = self.run_cli(["list"])
        self.assertEqual(code, 0)
        self.assertEqual(app.opened, [])
        self.assertIn("客厅", out)
        self.assertIn("客厅吸顶灯", out)
        self.assertIn("已开 · 80%", out)
        self.assertIn("阳台灯", out)
        self.assertIn("离线", out)
        # 收藏的设备带星标，房间按 roomSortOrder 排：客厅在书房前面。
        self.assertIn("★", out)
        self.assertLess(out.index("客厅"), out.index("书房"))

    def test_list_filters_by_room_name_and_id(self) -> None:
        for room in ("书房", "study"):
            code, out, _, _ = self.run_cli(["list", "--room", room])
            self.assertEqual(code, 0, room)
            self.assertIn("书房台灯", out)
            self.assertNotIn("客厅吸顶灯", out)

    def test_list_rejects_unknown_room(self) -> None:
        code, _, err, _ = self.run_cli(["list", "--room", "车库"])
        self.assertEqual(code, mijia.EXIT_LOCAL_ERROR)
        self.assertIn("书房", err)

    def test_list_json_contains_full_device_rows(self) -> None:
        code, out, _, _ = self.run_cli(["list", "--json", "--room", "study"])
        self.assertEqual(code, 0)
        payload = json.loads(out)
        self.assertEqual([device["id"] for device in payload["devices"]], ["dev_study_lamp", "dev_study_ac"])
        self.assertEqual(payload["devices"][0]["capabilities"]["canTogglePower"], True)

    def test_status_reports_connection_counts_and_readings(self) -> None:
        code, out, _, _ = self.run_cli(["status"])
        self.assertEqual(code, 0)
        self.assertIn("Home Assistant", out)
        self.assertIn("4 台", out)
        self.assertIn("沙发温湿度计", out)
        self.assertIn("24.5°C", out)
        self.assertIn("52%", out)

    def test_toggle_sends_device_id_token_and_request_id_then_reports_result(self) -> None:
        code, out, _, app = self.run_cli(["toggle", "书房台灯"])
        self.assertEqual(code, 0)
        self.assertEqual(len(app.opened), 1)
        url = app.opened[0]
        self.assertTrue(url.startswith("menumijia://toggle?"))
        query = app.query()
        self.assertEqual(query["device"], "dev_study_lamp")
        self.assertEqual(query["token"], TOKEN)
        self.assertEqual(len(query["id"]), 32)
        self.assertIn("已执行", out)

    def test_toggle_accepts_room_prefix_and_pinyin_initials(self) -> None:
        _, _, _, app = self.run_cli(["toggle", "书房书房台灯"])
        self.assertEqual(app.query()["device"], "dev_study_lamp")
        _, _, _, app = self.run_cli(["toggle", "sftd"])
        self.assertEqual(app.query()["device"], "dev_study_lamp")

    def test_toggle_refuses_a_device_without_a_power_switch(self) -> None:
        code, _, err, app = self.run_cli(["toggle", "阳台灯"])
        self.assertEqual(code, mijia.EXIT_LOCAL_ERROR)
        self.assertIn("没有可直接开关", err)
        self.assertEqual(app.opened, [])

    def test_toggle_errors_on_an_ambiguous_name(self) -> None:
        snapshot = make_snapshot()
        snapshot["devices"][1]["name"] = "台灯"
        snapshot["devices"][2]["name"] = "台灯"
        snapshot["devices"][2]["pinyinInitials"] = "td"
        self.write_snapshot(snapshot)
        code, _, err, app = self.run_cli(["toggle", "台灯"])
        self.assertEqual(code, mijia.EXIT_LOCAL_ERROR)
        self.assertIn("匹配到多个设备", err)
        self.assertEqual(app.opened, [])

    def test_on_and_off_send_explicit_power_state(self) -> None:
        code, _, _, app = self.run_cli(["on", "书房台灯"])
        self.assertEqual(code, 0)
        self.assertTrue(app.opened[0].startswith("menumijia://power?"))
        self.assertEqual(app.query()["on"], "true")

        code, _, _, app = self.run_cli(["off", "客厅吸顶灯"])
        self.assertEqual(code, 0)
        self.assertEqual(app.query()["on"], "false")
        self.assertEqual(app.query()["device"], "dev_living_light")

    def test_scene_uses_quick_prefix_for_builtin_and_id_for_remote_scenes(self) -> None:
        code, _, _, app = self.run_cli(["scene", "全屋关灯"])
        self.assertEqual(code, 0)
        self.assertEqual(app.query()["name"], "quick:lightsOff")

        code, _, _, app = self.run_cli(["scene", "观影模式"])
        self.assertEqual(code, 0)
        self.assertEqual(app.query()["name"], "scene_movie")

        code, _, _, app = self.run_cli(["scene", "undo"])
        self.assertEqual(code, 0)
        self.assertEqual(app.query()["name"], "quick:undo")

    def test_exact_quick_action_name_beats_a_scene_that_only_contains_it(self) -> None:
        snapshot = make_snapshot()
        snapshot["scenes"].append(
            {
                "id": "scene_room_off",
                "name": "全屋关灯客厅",
                "entityId": "scene.room_off",
                "roomName": "客厅",
                "icon": "lightbulb",
                "visualCategory": "light",
                "pinyinInitials": "",
                "pinyinFull": "",
            }
        )
        self.write_snapshot(snapshot)
        code, _, _, app = self.run_cli(["scene", "全屋关灯"])
        self.assertEqual(code, 0)
        self.assertEqual(app.query()["name"], "quick:lightsOff")

    def test_a_partial_scene_name_resolves_when_it_is_unique(self) -> None:
        code, _, _, app = self.run_cli(["scene", "观影"])
        self.assertEqual(code, 0)
        self.assertEqual(app.query()["name"], "scene_movie")

    def test_ask_and_command_percent_encode_the_sentence(self) -> None:
        for subcommand in ("ask", "command"):
            code, out, _, app = self.run_cli([subcommand, "把客厅灯调到 40%"])
            self.assertEqual(code, 0)
            self.assertTrue(app.opened[0].startswith("menumijia://ask?"))
            # 空格编码成 %20，应用才按原样收到文本（"+" 会被当成字面加号）。
            self.assertIn("text=%E6%8A%8A%E5%AE%A2%E5%8E%85%E7%81%AF%E8%B0%83%E5%88%B0%2040%25", app.opened[0])
            self.assertEqual(app.query()["text"], "把客厅灯调到 40%")
            self.assertIn("已执行", out)

    def test_a_failed_command_exits_with_one(self) -> None:
        app = FakeApp(self.path, is_error=True, message="设备当前离线")
        code, out, _, _ = self.run_cli(["toggle", "书房台灯"], app)
        self.assertEqual(code, mijia.EXIT_COMMAND_FAILED)
        self.assertIn("设备当前离线", out)

    def test_a_missing_feedback_times_out(self) -> None:
        app = FakeApp(self.path, respond=False)
        code, _, err, _ = self.run_cli(["toggle", "书房台灯", "--timeout", "1.5"], app)
        self.assertEqual(code, mijia.EXIT_TIMEOUT)
        self.assertIn("没收到执行结果", err)
        self.assertGreaterEqual(self.clock, 1.5)

    def test_stale_feedback_from_an_earlier_command_is_ignored(self) -> None:
        snapshot = make_snapshot()
        snapshot["lastCommandFeedback"] = {
            "requestId": "older-request",
            "command": "toggle",
            "message": "上一次的结果",
            "isError": False,
            "completedAt": "2026-11-06T07:59:00.000Z",
        }
        self.write_snapshot(snapshot)
        app = FakeApp(self.path, respond=False)
        code, out, _, _ = self.run_cli(["toggle", "书房台灯", "--timeout", "0.3"], app)
        self.assertEqual(code, mijia.EXIT_TIMEOUT)
        self.assertNotIn("上一次的结果", out)

    def test_dry_run_prints_the_link_with_a_masked_token(self) -> None:
        code, out, _, app = self.run_cli(["toggle", "书房台灯", "--dry-run"])
        self.assertEqual(code, 0)
        self.assertEqual(app.opened, [])
        self.assertIn("menumijia://toggle?", out)
        self.assertIn("device=dev_study_lamp", out)
        self.assertNotIn(TOKEN, out)

    def test_no_wait_opens_the_link_without_polling(self) -> None:
        app = FakeApp(self.path, respond=False)
        code, _, _, _ = self.run_cli(["toggle", "书房台灯", "--no-wait"], app)
        self.assertEqual(code, 0)
        self.assertEqual(len(app.opened), 1)
        self.assertEqual(self.clock, 0)

    def test_missing_snapshot_points_at_the_settings_switch(self) -> None:
        self.path.unlink()
        code, _, err, app = self.run_cli(["list"])
        self.assertEqual(code, mijia.EXIT_LOCAL_ERROR)
        self.assertIn("Raycast 集成", err)
        self.assertEqual(app.opened, [])

    def test_unknown_schema_version_is_rejected(self) -> None:
        snapshot = make_snapshot()
        snapshot["schemaVersion"] = 99
        self.write_snapshot(snapshot)
        code, _, err, _ = self.run_cli(["list"])
        self.assertEqual(code, mijia.EXIT_LOCAL_ERROR)
        self.assertIn("99", err)

    def test_empty_bridge_token_is_reported(self) -> None:
        snapshot = make_snapshot()
        snapshot["bridgeToken"] = ""
        self.write_snapshot(snapshot)
        code, _, err, app = self.run_cli(["toggle", "书房台灯"])
        self.assertEqual(code, mijia.EXIT_LOCAL_ERROR)
        self.assertIn("本机令牌", err)
        self.assertEqual(app.opened, [])

    def test_snapshot_path_comes_from_the_environment_variable(self) -> None:
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = mijia.main(
                ["list"],
                opener=lambda url: None,
                now=self.now,
                sleep=self.sleep,
                env={mijia.SNAPSHOT_ENV: str(self.path)},
            )
        self.assertEqual(code, 0)
        self.assertIn("客厅吸顶灯", out.getvalue())

    def test_build_url_escapes_spaces_and_keeps_the_token_last(self) -> None:
        url = mijia.build_url("ask", [("text", "开 灯")], TOKEN, "req1")
        self.assertEqual(url, f"menumijia://ask?text=%E5%BC%80%20%E7%81%AF&id=req1&token={TOKEN}")


if __name__ == "__main__":
    sys.exit(unittest.main())
