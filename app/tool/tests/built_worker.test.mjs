import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';
import {worker} from './worker_harness.mjs';

const build = path.resolve(process.env.WEB_BUILD || 'build/web');
const source = fs.readFileSync(path.join(build, 'sw.js'), 'utf8');
test('generated worker installs every local shell resource', async () => {
  const w = worker({source});
  for (const file of w.FILES) {
    assert.ok(fs.existsSync(path.join(build, file === './' ? 'index.html' : file)), file);
    assert.doesNotMatch(file, /\.symbols$|skwasm|\/audio\/.*\.mp3$/);
  }
  await w.event('install').wait();
  assert.equal(w.skipped, true);
});
test('built bootstrap uses local CanvasKit and the shell includes its binaries', () => {
  const bootstrap = fs.readFileSync(path.join(build, 'flutter_bootstrap.js'), 'utf8');
  assert.match(bootstrap, /canvasKitBaseUrl: new URL\('canvaskit\/', document.baseURI\)/);
  const w = worker({source});
  assert.ok(w.FILES.includes('canvaskit/canvaskit.js'));
  assert.ok(w.FILES.includes('canvaskit/canvaskit.wasm'));
  assert.ok(w.FILES.includes('canvaskit/chromium/canvaskit.wasm'));
});
