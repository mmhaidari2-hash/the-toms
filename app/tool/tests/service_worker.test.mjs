import test from 'node:test';
import assert from 'node:assert/strict';
import {worker, scope} from './worker_harness.mjs';

for (const [range, status, contentRange, values] of [
  ['bytes=0-1', 206, 'bytes 0-1/10', [0, 1]],
  ['bytes=-4', 206, 'bytes 6-9/10', [6, 7, 8, 9]],
  ['bytes=-99', 206, 'bytes 0-9/10', [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]],
  ['bytes=7-99', 206, 'bytes 7-9/10', [7, 8, 9]],
  ['bytes=7-', 206, 'bytes 7-9/10', [7, 8, 9]],
  ['bytes=20-', 416, 'bytes */10', []],
  ['bytes=6-2', 416, 'bytes */10', []],
  ['bytes=-0', 416, 'bytes */10', []],
]) {
  test(`audio ${range} returns a coherent ${status}`, async () => {
    const w = worker();
    const res = await w.request('assets/assets/audio/test.mp3', {range}).response;
    assert.equal(res.status, status);
    assert.equal(res.headers.get('content-range'), contentRange);
    const bytes = [...new Uint8Array(await res.arrayBuffer())];
    assert.deepEqual(bytes, values);
    if (status === 206) assert.equal(Number(res.headers.get('content-length')), bytes.length);
  });
}
for (const range of ['garbage', 'bytes=0-1,4-5', 'bytes=-', 'items=0-1', 'bytes=0-1trailing']) {
  test(`unsupported Range ${range} returns full 200`, async () => {
    const res = await worker().request('assets/assets/audio/test.mp3', {range}).response;
    assert.equal(res.status, 200);
    assert.equal((await res.arrayBuffer()).byteLength, 10);
  });
}
test('mismatched If-Range returns full audio', async () => {
  const res = await worker().request('assets/assets/audio/test.mp3', {range: 'bytes=0-1', ifRange: '"old"'}).response;
  assert.equal(res.status, 200);
});
test('audio plays from cache without network and respects suffix', async () => {
  const w = worker({fetcher() { throw new Error('offline'); }});
  await w.open(w.AUDIO_CACHE).put(scope + 'assets/assets/audio/test.mp3',
    new Response(Uint8Array.from({length: 10}, (_, i) => i)));
  const res = await w.request('assets/assets/audio/test.mp3?v=2', {range: 'bytes=-4'}).response;
  assert.deepEqual([...new Uint8Array(await res.arrayBuffer())], [6, 7, 8, 9]);
  assert.equal(w.fetches.length, 0);
});
test('partial network response is not stored as complete audio', async () => {
  const w = worker({fetcher: () => new Response('partial', {status: 206})});
  await w.request('assets/assets/audio/test.mp3').response;
  assert.equal(w.stores.get(w.AUDIO_CACHE).size, 0);
});
test('required download failure rejects install, preserves old caches and does not skip waiting', async () => {
  const w = worker({failAdd: true});
  w.open(w.PREFIX + 'shell:old');
  await assert.rejects(w.event('install').wait(), /download failed/);
  assert.equal(w.skipped, false);
  assert.ok(w.stores.has(w.PREFIX + 'shell:old'));
  assert.deepEqual(w.deleted, []);
});
test('successful install caches all required files before takeover', async () => {
  const w = worker();
  await w.event('install').wait();
  assert.equal(w.skipped, true);
  assert.equal(w.added.length, w.FILES.length);
});
test('activation removes only older caches for exactly this scope', async () => {
  const w = worker();
  const keep = [w.CACHE, w.AUDIO_CACHE, 'neighbor-progress',
    'thetoms:/another-app/:shell:old', 'thetoms-b38e69af3049'];
  for (const name of [...keep, w.PREFIX + 'shell:old', w.PREFIX + 'audio:old']) w.open(name);
  await w.event('activate').wait();
  assert.deepEqual(w.deleted.sort(), [w.PREFIX + 'audio:old', w.PREFIX + 'shell:old'].sort());
  for (const name of keep) assert.ok(w.stores.has(name), name);
  assert.equal(w.claimed, true);
});
test('offline navigation gets this scope shell, not another cache', async () => {
  const w = worker({fetcher() { throw new Error('offline'); }});
  await w.open('neighbor').put(scope + 'index.html', new Response('WRONG'));
  await w.open(w.CACHE).put(scope + 'index.html', new Response('RIGHT'));
  const res = await w.request('deep-link', {mode: 'navigate'}).response;
  assert.equal(await res.text(), 'RIGHT');
});
test('offline navigation prefers cached directory and strips encoded transfer headers', async () => {
  const w = worker({fetcher() { throw new Error('offline'); }});
  await w.open(w.CACHE).put(scope, new Response('DIRECTORY', {
    headers: {'content-encoding': 'gzip', 'content-length': '999'},
  }));
  await w.open(w.CACHE).put(scope + 'index.html', new Response('REDIRECT TARGET'));
  const res = await w.request('', {mode: 'navigate'}).response;
  assert.equal(await res.text(), 'DIRECTORY');
  assert.equal(res.headers.get('content-encoding'), null);
  assert.equal(res.headers.get('content-length'), null);
  assert.equal(res.redirected, false);
});
test('offline data failure never returns index HTML', async () => {
  const w = worker({fetcher() { throw new Error('offline'); }});
  await w.open(w.CACHE).put(scope + 'index.html', new Response('<html>'));
  await assert.rejects(w.request('missing.json').response, /offline/);
});
test('same-origin neighbors and external URLs are not intercepted', () => {
  const w = worker();
  assert.equal(w.request('/another-app/main.dart.js').response, undefined);
  assert.equal(w.request('https://external.test/a.mp3').response, undefined);
  assert.equal(w.request('main.dart.js', {method: 'POST'}).response, undefined);
});
test('prefetch is limited to our own audio URLs and clients', async () => {
  const w = worker();
  await w.event('message', {source: {url: scope}, data: {prefetch: [
    'assets/assets/audio/a.mp3', 'https://external.test/a.mp3',
    '/another-app/assets/audio/a.mp3', 'main.dart.js', null, 'http://[',
  ]}}).wait();
  assert.deepEqual(w.fetches, [scope + 'assets/assets/audio/a.mp3']);
  await w.event('message', {source: {url: 'https://external.test/'},
    data: {prefetch: ['assets/assets/audio/b.mp3']}}).wait();
  assert.equal(w.fetches.length, 1);
});
test('corrupt cached image is replaced with a real image', async () => {
  const w = worker({fetcher: () => new Response('picture', {headers: {'content-type': 'image/webp'}})});
  await w.open(w.CACHE).put(scope + 'assets/map.webp', new Response('<html>'));
  const res = await w.request('assets/map.webp').response;
  assert.equal(await res.text(), 'picture');
  assert.equal(w.fetches.length, 1);
});
