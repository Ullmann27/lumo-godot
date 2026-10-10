import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';
import { makeMeshyFileInputExpression } from './meshy_file_input_bridge.mjs';

const path = new URL('../assets/characters/rivals/reference/inputs/lion-front.jpg', import.meta.url);
const bytes = readFileSync(path);
const sha = createHash('sha256').update(bytes).digest('hex');

test('checksum mismatch is rejected before browser upload', () => {
  assert.throws(() => makeMeshyFileInputExpression(path.pathname, 'input', 'wrong'), /checksum/);
});

test('the native input receives actual bytes, not a zero-byte file', () => {
  const input = { type: 'file', dispatchEvent(event) { assert.equal(event.type, 'change'); } };
  class File {
    constructor(parts, name, options) {
      this.name = name;
      this.type = options.type;
      this.size = parts.reduce((sum, part) => sum + part.length, 0);
    }
  }
  class DataTransfer {
    files = [];
    items = { add: (file) => this.files.push(file) };
  }
  class Event { constructor(type) { this.type = type; } }
  const expression = makeMeshyFileInputExpression(path.pathname, 'input', sha);
  const result = vm.runInNewContext(expression, {
    document: { querySelector() { return input; } },
    Uint8Array, atob, File, DataTransfer, Event,
  });
  assert.equal(result.bytes, bytes.length);
  assert.equal(input.files[0].size, bytes.length);
  assert.equal(result.mime, 'image/jpeg');
  assert.ok(!expression.includes('fetch('));
});
