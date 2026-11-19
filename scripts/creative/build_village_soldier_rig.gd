extends RefCounted
## Gelenke der Blender-Soldaten (erzeugt von tools/lumo_village_art/build_soldier_models.py).
## village_soldier.gdshader dreht Körperteile um diese Punkte (Godot-Koordinaten, Meter).
const PIVOTS := {
	"soldier_bogen":
	{
		"hip": Vector3(0.095, 0.930, 0.000),
		"shoulder": Vector3(0.200, 1.420, -0.010),
		"neck": Vector3(0.000, 1.520, 0.005),
		"seated": false,
		"height": 1.805,
	},
	"soldier_reiter":
	{
		"hip": Vector3(0.100, 1.660, 0.000),
		"shoulder": Vector3(0.200, 2.140, -0.010),
		"neck": Vector3(0.000, 2.240, 0.005),
		"seated": true,
		"height": 2.525,
	},
	"soldier_schild":
	{
		"hip": Vector3(0.095, 0.930, 0.000),
		"shoulder": Vector3(0.200, 1.420, -0.010),
		"neck": Vector3(0.000, 1.520, 0.005),
		"seated": false,
		"height": 1.805,
	},
	"soldier_speer":
	{
		"hip": Vector3(0.095, 0.930, 0.000),
		"shoulder": Vector3(0.200, 1.420, -0.010),
		"neck": Vector3(0.000, 1.520, 0.005),
		"seated": false,
		"height": 1.805,
	},
}
