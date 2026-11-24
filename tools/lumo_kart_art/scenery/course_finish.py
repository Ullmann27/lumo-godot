"""Shared 256 × 128 surface atlas for each course sculpture, including fine material relief."""
import math
import struct
import tempfile
import zlib
from pathlib import Path

import bpy

TILES = ('Glasur', 'Messing', 'Gusseisen', 'Sandstein', 'Elfenbeinlack', 'Lichtglas')
PALETTE = ('', 'e7ae55', '30475b', 'cbb99c', 'fff0d0', 'fff3af')
ROUGHNESS = (.33, .32, .53, .85, .42, .20)
METAL = (0, .64, .48, 0, 0, 0)
TILE = 64


def _png(path, rows):
    def chunk(label, data):
        return struct.pack('>I', len(data)) + label + data + struct.pack('>I', zlib.crc32(label + data))
    header = struct.pack('>2I5B', TILE * 4, TILE * 2, 8, 2, 0, 0, 0)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
                     + chunk(b'IDAT', zlib.compress(b''.join(b'\0' + row for row in rows)))
                     + chunk(b'IEND', b''))


def _relief(tile, x, y):
    u, v = math.tau * x / TILE, math.tau * y / TILE
    if tile == 1:  # brushed brass
        return .24 * math.sin(13*v + .18*math.cos(u))
    if tile in (2, 3):  # cast iron and sandstone grain
        return .35*math.sin(11*u+8*v)*math.cos(7*u-9*v) + .16*math.cos(3*u-4*v)
    return .10 * math.sin(4*u) * math.cos(4*v)


def _byte(value):
    return min(255, max(0, round(value)))


def make_atlas(track, color):
    colors = [bytes.fromhex(value or color) for value in PALETTE]
    images = {}
    with tempfile.TemporaryDirectory() as directory:
        maps = {key: [] for key in ('Color', 'Normal', 'ORM')}
        for y in range(2*TILE):
            rows = {key: bytearray() for key in maps}
            for x in range(4*TILE):
                tile = min(5, x//TILE + 4*(y//TILE))
                h = _relief(tile, x, y)
                dx = _relief(tile, x+1, y) - _relief(tile, x-1, y)
                dy = _relief(tile, x, y+1) - _relief(tile, x, y-1)
                normal_length = math.sqrt(dx*dx + dy*dy + 1)
                rows['Color'].extend(_byte(c*(1+.09*h)) for c in colors[tile])
                rows['Normal'].extend(_byte(127.5*(1+v/normal_length)) for v in (-dx, dy, 1))
                rows['ORM'].extend((_byte(255*(1+.10*min(0,h))), _byte(255*(ROUGHNESS[tile]+.07*h)), _byte(255*METAL[tile])))
            for key in maps:
                maps[key].append(rows[key])
        for key, rows in maps.items():
            path = Path(directory) / f'{track}_{key}.png'
            _png(path, rows)
            image = bpy.data.images.load(str(path))
            if key != 'Color':
                image.colorspace_settings.name = 'Non-Color'
            image.pack()
            images[key] = image
    return images


def assign(obj, images):
    mesh = obj.data
    uv = mesh.uv_layers.new(name='Oberflaeche')
    for polygon in mesh.polygons:
        tile = TILES.index(mesh.materials[polygon.material_index].name)
        axis = max(range(3), key=lambda k: abs(polygon.normal[k]))
        axes = [k for k in range(3) if k != axis]
        # Project each face within its own swatch; a two-texel gutter survives mipmapping.
        for index in polygon.loop_indices:
            point = mesh.vertices[mesh.loops[index].vertex_index].co
            u,v = (.5 + .46 * math.sin(.37 * point[k]) for k in axes)
            uv.data[index].uv = ((tile%4 + u)/4, 1 - (tile//4 + v)/2)
    for material in mesh.materials:
        nodes = material.node_tree.nodes
        if nodes.get('Atlas Color'):
            continue
        links = material.node_tree.links
        bsdf = nodes.get('Principled BSDF')
        def texture(key):
            node = nodes.new('ShaderNodeTexImage')
            node.name = 'Atlas ' + key
            node.image = images[key]
            return node.outputs['Color']
        links.new(texture('Color'), bsdf.inputs['Base Color'])
        bump = nodes.new('ShaderNodeNormalMap')
        links.new(texture('Normal'), bump.inputs['Color'])
        links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
        channels = nodes.new('ShaderNodeSeparateColor')
        links.new(texture('ORM'), channels.inputs[0])
        links.new(channels.outputs['Green'], bsdf.inputs['Roughness'])
        links.new(channels.outputs['Blue'], bsdf.inputs['Metallic'])
        group_name = 'glTF Material Output'
        group = bpy.data.node_groups.get(group_name)
        if group is None:
            group = bpy.data.node_groups.new(group_name, 'ShaderNodeTree')
            group.interface.new_socket(name='Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
        baked = nodes.new('ShaderNodeGroup')
        baked.node_tree = group
        links.new(channels.outputs['Red'], baked.inputs['Occlusion'])
    normals = obj.modifiers.new('Flächengewichtete Normalen', 'WEIGHTED_NORMAL')
    normals.keep_sharp = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=normals.name)
