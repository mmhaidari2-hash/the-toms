import fs from 'node:fs';
import vm from 'node:vm';

export const scope = 'https://example.test/the-toms/';

export function worker({source, failAdd = false, fetcher} = {}) {
  source ??= fs.readFileSync(new URL('../service_worker.js', import.meta.url), 'utf8')
    .replace('__CACHE_VERSION__', 'test-shell')
    .replace('__AUDIO_VERSION__', 'test-audio')
    .replace('__PRECACHE_FILES__', JSON.stringify(['./', 'index.html', 'main.dart.js']));
  const handlers = {}, stores = new Map(), deleted = [], fetches = [], added = [];
  let skipped = false, claimed = false;
  const key = (request, ignore = false) => {
    const url = new URL(typeof request === 'string' ? request : request.url, scope);
    if (ignore) url.search = '';
    return url.href;
  };
  const cacheApi = name => {
    if (!stores.has(name)) stores.set(name, new Map());
    const store = stores.get(name);
    return {
      async add(request) {
        added.push(key(request));
        if (failAdd) throw new Error('Required download failed');
        store.set(key(request), new Response('cached file'));
      },
      async put(request, response) { store.set(key(request), response.clone()); },
      async match(request, options = {}) {
        const found = [...store.entries()].find(([url]) => key(url, options.ignoreSearch) === key(request, options.ignoreSearch));
        return found?.[1].clone();
      },
      async delete(request, options = {}) {
        let found = false;
        for (const url of store.keys()) {
          if (key(url, options.ignoreSearch) === key(request, options.ignoreSearch)) {
            store.delete(url); found = true;
          }
        }
        return found;
      },
    };
  };
  const context = {
    URL, Request, Response, Headers, console,
    self: {
      registration: {scope},
      addEventListener(type, fn) { handlers[type] = fn; },
      async skipWaiting() { skipped = true; },
      clients: {async claim() { claimed = true; }},
    },
    caches: {
      async open(name) { return cacheApi(name); },
      async keys() { return [...stores.keys()]; },
      async delete(name) { deleted.push(name); return stores.delete(name); },
    },
    async fetch(request, options) {
      fetches.push(key(request));
      if (fetcher) return fetcher(request, options);
      return new Response(Uint8Array.from({length: 10}, (_, i) => i), {
        headers: {'content-type': 'audio/mpeg', etag: '"v1"'},
      });
    },
  };
  vm.createContext(context);
  vm.runInContext(source + '\nglobalThis.ids = {CACHE, AUDIO_CACHE, PREFIX, FILES};', context);
  function event(type, properties = {}) {
    let response;
    const waits = [];
    handlers[type]({
      ...properties,
      waitUntil(promise) { waits.push(promise); },
      respondWith(promise) { response = Promise.resolve(promise); },
    });
    return {response, wait: () => Promise.all(waits)};
  }
  function request(path, {range, mode = 'cors', method = 'GET', ifRange} = {}) {
    return event('fetch', {request: {
      url: new URL(path, scope).href, method, mode,
      headers: new Headers({...range && {range}, ...ifRange && {'if-range': ifRange}}),
    }});
  }
  return {
    ...context.ids, event, request, stores, deleted, fetches, added,
    open: cacheApi,
    get skipped() { return skipped; },
    get claimed() { return claimed; },
  };
}
