# Sonnenhafen original mineral kit

Six original silhouettes authored through local Blender 4.3.2 mesh operations:
four strata per shelf, a split projecting ledge, a layered hanging canopy, and
crystal fan/spire/rosette groups. The stone edges have real applied bevels.
Crystals use independent shoulder rings and asymmetrical tips. Meshes include
flat normals, UVs, grayscale facet colors, a ground pivot and one material
surface each. No external asset, provider, downloaded texture, collision,
animation, road or gameplay geometry is included. These are project-original
assets under the same license as this repository.

The runtime reuses each mesh through MultiMesh and applies the shared cinema
material. Mobile variants reduce actual topology and minor crystal shards,
while retaining each silhouette's height and main feature arrangement. No
physical-device frame-rate claim is made.

| Mesh | High triangles | Mobile triangles |
| --- | ---: | ---: |
| Strata shelf | 768 | 252 |
| Split ledge | 604 | 192 |
| Hanging canopy | 800 | 260 |
| Crystal fan | 322 | 110 |
| Crystal spire | 230 | 66 |
| Crystal rosette | 414 | 110 |

The JSON manifest records exact buffers, bounds, hashes and source provenance.
The independent Blender receipt verifies fresh imports rather than inspecting
the generator's in-memory objects. Grayscale pigment range is checked in the
Blender source, actual GLB color buffers, independent Blender import, and Godot
import. Creating color layers can invalidate earlier Blender UV-layer handles;
the generator resolves both handles after layer creation to keep them separate.

Generate from the repository root:

```sh
blender --background --threads 1 --python tools/art/generate_kart_mineral_kit.py -- assets/kart/cavern/mineral_kit
python3 tools/art/verify_kart_mineral_kit.py
blender --background --threads 1 --python tools/art/verify_kart_mineral_kit_blender.py -- assets/kart/cavern/mineral_kit
python3 -m unittest tools.tests.test_kart_mineral_kit -v
```

After the normal Godot editor import, run the asset contract without graphics:

```sh
godot --headless --audio-driver Dummy --path . --script scripts/tests/kart_cavern_mineral_kit_regression.gd
```

Run the actual MultiMesh placement and corridor regression with a real display
(a virtual X display with Mesa is sufficient):

```sh
godot --rendering-method gl_compatibility --audio-driver Dummy --path . --script scripts/tests/kart_cavern_detail_regression.gd
```

The latter deliberately requires a renderer because Godot's headless dummy
backend returns identity transforms for all MultiMesh readbacks. Construction
metrics apply the exact submitted transforms to imported mesh bounds; the
rendered regression independently checks uploaded transforms, real shoulder
and roof bounds, draw surfaces, and deterministic placement in both LODs.
