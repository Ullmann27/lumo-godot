# Desktop Ultra und Cinematic in Godot 4.6.3

Beide Modi starten gezielt für eine Sitzung des eigenständigen Godot-Spiels. Das reguläre Android-Spiel nutzt seine bisherigen Profile. Die Flutter-Lern-App, Android-Sprachdienste und Sicherungen haben einen eigenen Host und benötigen für Windows und Linux noch eine Portierung.

## Start

Vom Godot-Projektverzeichnis aus:

```sh
godot --rendering-method forward_plus --resolution 2560x1440 res://scenes/games/kart_island.tscn -- --lumo-render=desktop-ultra
godot --rendering-method forward_plus --resolution 3840x2160 --write-movie /tmp/lumo-kart.avi --fixed-fps 30 res://scenes/games/kart_island.tscn -- --lumo-render=cinematic
```

Desktop Ultra verwendet die hohe Basis mit der zusätzlichen Kart-Szenerie, zeitlicher Kantenglättung und den Screen-Space-Reflexionen des aktuellen Environment. Cinematic ergänzt indirekte Beleuchtung im Bildraum. Das normale Spiel startet ohne diese Optionen. Mobile, Compatibility, Web und der Headless-Prozess ignorieren beide Optionen. Die Aktivierung verändert keine gespeicherten Grafikeinstellungen. Eine nachträgliche Reduktion auf das leichte Profil schaltet die zusätzlichen Beleuchtungseffekte aus. Ob ein Effekt im Spiel sichtbar wird, hängt von der Szenenumgebung, den Materialien und dem tatsächlich benutzten Viewport ab.

## Geprüfter Umfang

Unter Linux konnten beide Modi mit dem Vulkan-Softwareadapter llvmpipe in einem wirklichen Forward+-Fenster aktiviert und die zusätzlichen Effekte an einer neu geladenen Szene geprüft werden. Die Gegenproben mit tatsächlichem Vulkan Mobile und OpenGL Compatibility behielten ihren normalen Beleuchtungspfad bei. Ein veröffentlichter Windows-Build, physische Gaming-GPU-Messungen und die vollständige Flutter-Desktop-App sind offen.
