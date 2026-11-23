{{flutter_js}}
{{flutter_build_config}}

// Run the app inside #app-host (the phone frame on wide screens), then
// remove the loading screen once the first frame is drawn.
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    const host = document.querySelector('#app-host');
    const appRunner = await engineInitializer.initializeEngine({
      hostElement: host,
    });
    await appRunner.runApp();
  },
});
window.addEventListener('flutter-first-frame', function () {
  const splash = document.querySelector('#splash');
  if (splash) {
    splash.classList.add('gone');
    setTimeout(function () { splash.remove(); }, 400);
  }
});
