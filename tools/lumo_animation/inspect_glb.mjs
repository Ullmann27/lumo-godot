// Read-only GLB structure and animation-storage audit; no external packages.
import {readFileSync, writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import assert from 'node:assert/strict';
const [input, output] = process.argv.slice(2);
assert(input && output, 'Usage: node inspect_glb.mjs input.glb output.json');
const bytes = readFileSync(input);
assert.equal(bytes.readUInt32LE(0), 0x46546c67);
assert.equal(bytes.readUInt32LE(4), 2);
assert.equal(bytes.readUInt32LE(8), bytes.length);
let json, bin;
for (let offset = 12; offset < bytes.length;) {
  const length = bytes.readUInt32LE(offset);
  const type = bytes.readUInt32LE(offset + 4);
  const data = bytes.subarray(offset + 8, offset + 8 + length);
  if (type === 0x4e4f534a) json = JSON.parse(data.toString('utf8'));
  if (type === 0x004e4942) bin = data;
  offset += 8 + length;
}
assert(json && bin);
const required = ['idle', 'greeting_wave', 'celebrate', 'point_portal', 'agree_nod',
  'kart_seated', 'kart_steer_left', 'kart_steer_right', 'kart_jump'];
for (const name of required) assert(json.animations.some(animation => animation.name === name));
const views = new Set();
const animations = json.animations.map(animation => {
  const accessors = new Set();
  for (const sampler of animation.samplers) {
    accessors.add(sampler.input);
    accessors.add(sampler.output);
  }
  for (const index of accessors) {
    const accessor = json.accessors[index];
    assert(accessor.bufferView !== undefined && !accessor.sparse);
    views.add(accessor.bufferView);
  }
  return {name: animation.name, channels: animation.channels.length,
    unique_accessors: accessors.size};
});
const animationBufferBytes = [...views].reduce((sum, index) => sum + json.bufferViews[index].byteLength, 0);
let triangles = 0;
let vertices = 0;
for (const mesh of json.meshes) {
  for (const primitive of mesh.primitives) {
    assert.equal(primitive.mode ?? 4, 4, 'Triangle primitives required');
    vertices += json.accessors[primitive.attributes.POSITION].count;
    triangles += json.accessors[primitive.indices ?? primitive.attributes.POSITION].count / 3;
    assert(primitive.attributes.JOINTS_0 !== undefined && primitive.attributes.WEIGHTS_0 !== undefined);
    assert.equal(primitive.attributes.JOINTS_1, undefined, 'At most four skin influences');
    assert.equal(primitive.targets, undefined, 'No invented facial morphs');
  }
}
const images = json.images.map(image => {
  const view = json.bufferViews[image.bufferView];
  const data = bin.subarray(view.byteOffset ?? 0, (view.byteOffset ?? 0) + view.byteLength);
  assert.equal(data.subarray(1, 4).toString(), 'PNG', 'PNG textures expected');
  return {mime: image.mimeType, bytes: data.length,
    width: data.readUInt32BE(16), height: data.readUInt32BE(20)};
});
assert.equal(json.skins.length, 1);
assert.equal(json.skins[0].joints.length, 65);
assert(triangles <= 30000);
assert(images.every(image => image.width <= 1024 && image.height <= 1024));
const result = {sha256: createHash('sha256').update(bytes).digest('hex'),
  bytes: bytes.length, meshes: json.meshes.length, triangles, vertices,
  skins: json.skins.length, bones: json.skins[0].joints.length, animations, images,
  animation_accessor_buffer_bytes: animationBufferBytes,
  animation_accessor_buffer_scope: 'Exported binary tracks only, not total runtime object memory',
  max_skin_influences: 4, facial_morphs: false, android_measured: false};
writeFileSync(output, JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result));
