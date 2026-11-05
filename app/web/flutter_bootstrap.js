{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({
  config: {
    renderer: 'canvaskit',
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href,
  },
  onEntrypointLoaded: async function (engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine({ hostElement: document.getElementById('app') });
    await appRunner.runApp();
  },
});
