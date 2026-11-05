import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';
import assert from 'node:assert/strict';

const html = fs.readFileSync(new URL('../../web/index.html', import.meta.url), 'utf8');
const resetScript = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)]
  .map(m => m[1]).find(s => s.includes('var appScope'));

async function run(reset, failure) {
  const removedWorkers = [], removedCaches = [], listeners = {};
  const own = 'https://example.test/the-toms/';
  const workers = [
    {scope: own, active: {scriptURL: own + 'flutter_service_worker.js'}, unregister: async () => removedWorkers.push('own')},
    {scope: 'https://example.test/neighbor/', active: {scriptURL: 'https://example.test/neighbor/old.js'}, unregister: async () => removedWorkers.push('neighbor')},
  ];
  const sw = {
    controller: null,
    getRegistrations: async () => {
      if (failure === 'lookup') throw new Error('unavailable');
      return workers;
    },
    addEventListener() {},
    register: async () => {
      if (failure === 'register') throw new Error('denied');
      if (failure === 'undefined') return undefined;
      return {update() {
        if (failure === 'update') return Promise.reject(new Error('offline'));
      }};
    },
  };
  const cacheNames = ['thetoms:/the-toms/:shell:old', 'thetoms:/neighbor/:shell:old', 'neighbor-progress'];
  const context = {
    URL, console: {warn() {}}, navigator: {serviceWorker: sw}, document: {baseURI: own, addEventListener() {}},
    window: {caches: true, addEventListener(type, fn) { listeners[type] = fn; }},
    caches: {keys: async () => cacheNames, delete: async name => removedCaches.push(name)},
    location: {href: own + (reset ? '?reset' : ''), pathname: '/the-toms/', replace() {}},
  };
  vm.createContext(context);
  vm.runInContext(resetScript, context);
  if (!reset) listeners.load();
  await new Promise(resolve => setImmediate(resolve));
  return {removedWorkers, removedCaches};
}
test('reset preserves neighbor registrations and caches', async () => {
  const result = await run(true);
  assert.deepEqual(result.removedWorkers, ['own']);
  assert.deepEqual(result.removedCaches, ['thetoms:/the-toms/:shell:old']);
});
test('legacy worker cleanup is restricted to this app registration', async () => {
  const result = await run(false);
  assert.deepEqual(result.removedWorkers, ['own']);
  assert.deepEqual(result.removedCaches, []);
});
test('viewport permits user zoom', () => {
  assert.doesNotMatch(html, /user-scalable=no|maximum-scale=1/);
});
for (const mode of ['lookup', 'register', 'undefined', 'update']) {
  test(`unavailable service worker (${mode}) does not cause an unhandled error`, async () => {
    await run(false, mode);
  });
}
