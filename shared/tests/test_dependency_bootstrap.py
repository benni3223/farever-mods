"""Real HashLink subprocess tests; set HAXE, HL and LD_LIBRARY_PATH as needed.

Uses harmless native fixtures instead of a game window or ImGui renderer.
The exact bootstrap arguments come from each mod's compile.hxml.
"""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODS = ["dps-meter", "minimap", "item-utilities", "more-settings", "fix-target-lock"]
HAXE = os.environ.get("HAXE", "haxe")
HL = os.environ.get("HL", "hl")


class BootstrapTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.base = Path(cls.temp.name)
        cls.compiled = cls.base / "compiled"
        cls.compiled.mkdir()
        (cls.compiled / "Payload.hx").write_text('''
class Payload {
    static function __init__() { sys.io.File.saveContent("initialized", "yes"); }
    static function main() { sys.io.File.saveContent("started", "yes"); }
}
''')
        for mod in MODS:
            payload = cls.compiled / f"build/{mod}/implementation/{mod}.hl"
            subprocess.run([HAXE, "-cp", ".", "-main", "Payload", "-hl", str(payload)],
                           cwd=cls.compiled, check=True, capture_output=True)
            args = []
            section = (ROOT / mod / "compile.hxml").read_text().split("--next\n")[1]
            for line in section.splitlines():
                parts = shlex.split(line, comments=True)
                if not parts:
                    continue
                if parts[0] == "-cp":
                    parts[1] = str((ROOT / mod / parts[1]).resolve())
                args.extend(parts)
            subprocess.run([HAXE, *args], cwd=cls.compiled, check=True, capture_output=True)

        # The signatures match the real HashLink primitives. Never call ImGui;
        # isPrimLoaded must inspect the binding without initializing a renderer.
        cls.libs = {}
        for lib, source in {
            "ui": r'''
#include <stdint.h>
#include <stdio.h>
static void text(const uint16_t *s) { while (*s) putchar((char)*s++); }
static int dialog(const uint16_t *title, const uint16_t *message, int flags) {
    printf("DIALOG[%d] ", flags); text(title); putchar('\n'); text(message); putchar('\n'); fflush(stdout); return 0;
}
void *hlp_ui_dialog(const char **signature) { *signature = "PBBi_i"; return (void*)dialog; }
''',
            "imgui": r'''
#include <stdlib.h>
static void *version(void) { abort(); }
void *hlp_igGetVersion(const char **signature) { *signature = "P_B"; return (void*)version; }
''',
        }.items():
            source_path = cls.base / (lib + ".c")
            source_path.write_text(source)
            directory = cls.base / lib
            directory.mkdir()
            library = directory / (lib + "64.hdll")
            subprocess.run(["cc", "-shared", "-fPIC", str(source_path), "-o", str(library)], check=True)
            shutil.copy2(library, directory / (lib + ".hdll"))
            cls.libs[lib] = directory

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def launch(self, mod, settings=True, alerts=True, imgui=True, ui=True, implementation="valid"):
        with tempfile.TemporaryDirectory(dir=self.base) as directory:
            game = Path(directory)
            module = game / "hlx/mods" / mod
            shutil.copytree(self.compiled / "build" / mod, module)
            if settings:
                bms = game / "hlx/mods/better-mod-settings"
                bms.mkdir()
                shutil.copy2(module / "implementation" / (mod + ".hl"), bms / "better-mod-settings.hl")
            if alerts:
                update_alerts = game / "hlx/mods/mod-update-alerts"
                update_alerts.mkdir()
                binary = update_alerts / "mod-update-alerts.hl"
                shutil.copy2(module / "implementation" / (mod + ".hl"), binary)
                if alerts == "disabled":
                    binary.rename(binary.with_suffix(".hl.disabled"))
                elif alerts == "empty":
                    binary.write_bytes(b"")
            payload = module / "implementation" / (mod + ".hl")
            if implementation == "missing":
                payload.unlink()
            elif implementation == "mismatched":
                payload.write_bytes(payload.read_bytes() + b"different version")
            env = dict(os.environ)
            env["LD_LIBRARY_PATH"] = ":".join(
                [str(self.libs[lib]) for lib, enabled in [("ui", ui), ("imgui", imgui)] if enabled]
                + [env.get("LD_LIBRARY_PATH", "")])
            result = subprocess.run([HL, str(module / (mod + ".hl"))], cwd=game, env=env,
                                    capture_output=True, text=True, timeout=15)
            ran = (game / "initialized").exists() or (game / "started").exists()
            return result.returncode, result.stdout + result.stderr, ran

    def test_all_five_stop_before_initializers_without_settings(self):
        for mod in MODS:
            with self.subTest(mod=mod):
                code, output, ran = self.launch(mod, settings=False)
                self.assertEqual(code, 1, output)
                self.assertIn("DIALOG[2] Farever mod dependency error", output)
                self.assertIn("- Better Mod Settings", output)
                self.assertFalse(ran)

    def test_all_five_load_matching_implementation(self):
        for mod in MODS:
            with self.subTest(mod=mod):
                code, output, ran = self.launch(mod, imgui=mod == "item-utilities")
                self.assertEqual(code, 0, output)
                self.assertNotIn("DIALOG", output)
                self.assertTrue(ran)

    def test_all_five_stop_without_update_alerts(self):
        for mod in MODS:
            for alerts in [False, "disabled", "empty"]:
                with self.subTest(mod=mod, alerts=alerts):
                    code, output, ran = self.launch(mod, alerts=alerts)
                    self.assertEqual(code, 1, output)
                    self.assertIn("DIALOG[2] Farever mod dependency error", output)
                    self.assertIn("- Mod Update Alerts", output)
                    self.assertIn("https://www.nexusmods.com/farever/mods/17", output)
                    self.assertNotIn("- Better Mod Settings", output)
                    self.assertNotIn("- Farever ImGui plugin", output)
                    self.assertFalse(ran)

    def test_missing_imgui_is_an_actionable_error_not_a_linker_crash(self):
        code, output, ran = self.launch("item-utilities", imgui=False)
        self.assertEqual(code, 1, output)
        self.assertIn("DIALOG[2]", output)
        self.assertIn("- Farever ImGui plugin", output)
        self.assertNotIn("- Better Mod Settings", output)
        self.assertFalse(ran)

    def test_reports_all_missing_dependencies(self):
        code, output, ran = self.launch("item-utilities", settings=False, alerts=False, imgui=False)
        self.assertEqual(code, 1, output)
        self.assertIn("- Better Mod Settings", output)
        self.assertIn("- Mod Update Alerts", output)
        self.assertIn("- Farever ImGui plugin", output)
        self.assertFalse(ran)

    def test_missing_or_mixed_implementation_cannot_start(self):
        for state in ["missing", "mismatched"]:
            with self.subTest(state=state):
                code, output, ran = self.launch("minimap", implementation=state)
                self.assertEqual(code, 1, output)
                self.assertIn("Reinstall or redeploy the complete mod archive", output)
                self.assertFalse(ran)

    def test_missing_dialog_library_still_logs_and_exits(self):
        code, output, ran = self.launch("minimap", settings=False, ui=False)
        self.assertEqual(code, 1, output)
        self.assertIn("Missing critical dependencies", output)
        self.assertFalse(ran)


if __name__ == "__main__":
    unittest.main()
