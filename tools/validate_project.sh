#!/usr/bin/env bash
set -euo pipefail
GODOT="${GODOT_BIN:-godot}"

# A PASS marker cannot approve engine errors emitted during teardown.
godot_log_ok() {
  local log=$1
  local pass=$2
  if ! grep -qE "$pass" "$log"; then
    echo "missing PASS marker '$pass' in $log" >&2
    return 1
  fi
  if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' "$log"; then
    echo "errors in $log" >&2
    return 1
  fi
  return 0
}

timeout 120s "$GODOT" --headless --editor --import --quit 2>&1 | tee /tmp/lumo-import.log
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' /tmp/lumo-import.log; then exit 1; fi
timeout 120s "$GODOT" --headless --script scripts/tests/kart_regression.gd 2>&1 | tee /tmp/lumo-kart-tests.log
godot_log_ok /tmp/lumo-kart-tests.log '\[KartTests\] PASS' || exit 1
timeout 120s "$GODOT" --headless --script scripts/tests/host_bridge_regression.gd 2>&1 | tee /tmp/lumo-host-tests.log
godot_log_ok /tmp/lumo-host-tests.log '\[HostBridgeTests\] PASS' || exit 1
timeout 120s "$GODOT" --headless --script scripts/tests/jump_regression.gd 2>&1 | tee /tmp/lumo-jump-tests.log
godot_log_ok /tmp/lumo-jump-tests.log '\[JumpTests\] PASS' || exit 1
timeout 120s "$GODOT" --headless --script scripts/tests/lumo_gait_regression.gd 2>&1 | tee /tmp/lumo-gait-tests.log
godot_log_ok /tmp/lumo-gait-tests.log '\[LumoGait\] PASS' || exit 1
timeout 120s "$GODOT" --headless --script scripts/tests/lumo_renderkit_regression.gd 2>&1 | tee /tmp/lumo-renderkit-tests.log
godot_log_ok /tmp/lumo-renderkit-tests.log '\[LumoRenderKit\] PASS' || exit 1
timeout 120s "$GODOT" --headless --script scripts/tests/lumo_environment_apply_presets_regression.gd 2>&1 | tee /tmp/lumo-env-apply-tests.log
godot_log_ok /tmp/lumo-env-apply-tests.log '\[LumoEnvironmentApply\] PASS' || exit 1
timeout 180s "$GODOT" --headless --script scripts/tests/lumo_environment_creative_presets_regression.gd 2>&1 | tee /tmp/lumo-creative-presets-tests.log
godot_log_ok /tmp/lumo-creative-presets-tests.log '\[CreativePresets\] PASS' || exit 1

timeout 120s "$GODOT" --headless --audio-driver Dummy --script scripts/tests/lumo_dream_ambience_regression.gd 2>&1 | tee /tmp/lumo-dream-ambience-tests.log
godot_log_ok /tmp/lumo-dream-ambience-tests.log '^\[DreamAmbience\] [1-9][0-9]* checks, 0 failures$' || exit 1
timeout 180s "$GODOT" --headless --audio-driver Dummy --script scripts/tests/dream_garden_props_regression.gd 2>&1 | tee /tmp/lumo-dream-garden-tests.log
godot_log_ok /tmp/lumo-dream-garden-tests.log '^\[DreamGarden\] checks=[1-9][0-9]* failures=0$' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/kart_race_bridge_regression.gd 2>&1 | tee /tmp/lumo-kart-race-bridge-tests.log
godot_log_ok /tmp/lumo-kart-race-bridge-tests.log '\[KartRaceBridge\] PASS' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/kart_physics_regression.gd 2>&1 | tee /tmp/lumo-kart-physics-tests.log
godot_log_ok /tmp/lumo-kart-physics-tests.log '\[KartPhysics\] PASS' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/kart_jump_regression.gd 2>&1 | tee /tmp/lumo-kart-jump-tests.log
godot_log_ok /tmp/lumo-kart-jump-tests.log '\[KartJump\] PASS' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/kart_touch_regression.gd 2>&1 | tee /tmp/lumo-kart-touch-tests.log
godot_log_ok /tmp/lumo-kart-touch-tests.log '\[KartTouchTests\] PASS' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/kart_reference_landing_fit_regression.gd 2>&1 | tee /tmp/lumo-landing-fit-tests.log
godot_log_ok /tmp/lumo-landing-fit-tests.log '\[KartLandingFit\] PASS' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/lumo_character_regression.gd 2>&1 | tee /tmp/lumo-character-tests.log
godot_log_ok /tmp/lumo-character-tests.log '\[LumoCharacterTests\] PASS' || exit 1

# Real GPU state (MultiMesh colours and transforms) needs a rendering server.
if [[ -n "${DISPLAY:-}" ]] || command -v xvfb-run >/dev/null 2>&1; then
  render_command=("$GODOT")
  if [[ -z "${DISPLAY:-}" ]]; then
    render_command=(xvfb-run -a -s '-screen 0 1920x2560x24' "$GODOT")
  fi
  timeout 120s "${render_command[@]}" --audio-driver Dummy --rendering-method gl_compatibility --script scripts/tests/kart_world_regression.gd 2>&1 | tee /tmp/lumo-world-tests.log
  godot_log_ok /tmp/lumo-world-tests.log '\[KartWorldTests\] PASS' || exit 1
  timeout 180s "${render_command[@]}" --verbose --audio-driver Dummy --rendering-method gl_compatibility --script scripts/tests/kart_pause_layout_regression.gd 2>&1 | tee /tmp/lumo-pause-layout-tests.log
  godot_log_ok /tmp/lumo-pause-layout-tests.log '\[KartPauseLayoutTests\] PASS' || exit 1
fi

timeout 120s "$GODOT" --headless --script scripts/tests/kart_vehicle_regression.gd 2>&1 | tee /tmp/lumo-vehicle-tests.log
godot_log_ok /tmp/lumo-vehicle-tests.log '\[KartVehicle\] Geometry/colours' || exit 1

timeout 180s "$GODOT" --headless --script scripts/tests/kart_ai_behavior_regression.gd 2>&1 | tee /tmp/lumo-kart-ai-tests.log
godot_log_ok /tmp/lumo-kart-ai-tests.log '\[KartAI\] PASS' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/kart_garage_touch_targets_regression.gd 2>&1 | tee /tmp/lumo-garage-targets-tests.log
godot_log_ok /tmp/lumo-garage-targets-tests.log '\[GarageTargets\] PASS' || exit 1

timeout 120s "$GODOT" --headless --script scripts/tests/kart_compact_selection_regression.gd 2>&1 | tee /tmp/lumo-compact-selection-tests.log
godot_log_ok /tmp/lumo-compact-selection-tests.log '\[CompactKartSelection\] PASS' || exit 1
