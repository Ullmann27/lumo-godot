import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { basename } from 'node:path';

/**
 * Builds a native file-input change for a verified, user-approved reference.
 * The caller must observe the selector and obtain provider-upload approval.
 * No cookies, keys, fetch calls, generation calls or billing actions are used.
 */
export function makeMeshyFileInputExpression(path, selector, expectedSha256) {
  const bytes = readFileSync(path);
  const sha256 = createHash('sha256').update(bytes).digest('hex');
  if (sha256 !== expectedSha256) throw new Error('Reference checksum mismatch.');
  if (bytes.length === 0 || bytes.length > 20 * 1024 * 1024) {
    throw new Error('Reference size is outside the supported upload range.');
  }
  const name = basename(path);
  const mime = /\.png$/i.test(name) ? 'image/png'
    : /\.jpe?g$/i.test(name) ? 'image/jpeg' : null;
  if (!mime) throw new Error('Only verified JPEG/PNG reference files are supported.');
  return `(() => {
    const input = document.querySelector(${JSON.stringify(selector)});
    if (!input || input.type !== "file") throw new Error("Observed file input missing.");
    const bytes = Uint8Array.from(atob(${JSON.stringify(bytes.toString('base64'))}), c => c.charCodeAt(0));
    const file = new File([bytes], ${JSON.stringify(name)}, {type:${JSON.stringify(mime)}});
    if (file.size !== ${bytes.length}) throw new Error("Empty or incomplete browser file.");
    const transfer = new DataTransfer();
    transfer.items.add(file);
    input.files = transfer.files;
    input.dispatchEvent(new Event("change", {bubbles:true}));
    return {name:file.name, bytes:file.size, mime:file.type};
  })()`;
}
