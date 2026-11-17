extends RefCounted
## Optional isolated integration helper. It does not modify any live race code.
## Preserve constant pose channels across idle, seated, steering and jump clips.

static func load_model(path: String) -> Node3D:
	if not FileAccess.file_exists(path):
		push_error("LUMO art model does not exist: " + path)
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		push_error("LUMO art import failed (%s): %s" % [error_string(error), path])
		return null
	return document.generate_scene(state, 30.0, false, false) as Node3D


static func connect_modules(previous: Node3D, following: Node3D) -> bool:
	var outlet := previous.find_child("SocketOut", true, false) as Node3D
	var inlet := following.find_child("SocketIn", true, false) as Node3D
	if outlet == null or inlet == null:
		return false
	var local_inlet := following.global_transform.affine_inverse() * inlet.global_transform
	following.global_transform = outlet.global_transform * local_inlet.affine_inverse()
	return true


static func create_tunnel_collision(proxy: Node3D) -> StaticBody3D:
	# Add the returned body to the same parent as the proxy. Local transforms
	# work before insertion into a SceneTree as well as after world placement.
	var body := StaticBody3D.new()
	body.name = "LumoTunnelCollision"
	body.transform = proxy.transform
	for child in proxy.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var collision := CollisionShape3D.new()
		collision.shape = instance.mesh.create_trimesh_shape()
		var local_shape := instance.transform
		var ancestor := instance.get_parent()
		while ancestor != proxy and ancestor is Node3D:
			local_shape = ancestor.transform * local_shape
			ancestor = ancestor.get_parent()
		collision.transform = local_shape
		body.add_child(collision)
	return body
