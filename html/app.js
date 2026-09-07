// Opens the vote link in the player's default browser. FiveM shows its own
// "open this link?" confirmation for gtaservers.org, once per player; the
// chat line the server printed is the fallback if they decline. Only links
// on gtaservers.org are opened; nothing else reaches the browser from here.
window.addEventListener("message", function (event) {
  var data = event.data || {};
  if (data.action !== "open" || typeof data.url !== "string") {
    return;
  }
  if (!/^https:\/\/gtaservers\.org\//.test(data.url) && !/^http:\/\/127\.0\.0\.1:\d+\//.test(data.url)) {
    return;
  }
  if (typeof window.invokeNative === "function") {
    window.invokeNative("openUrl", data.url);
  }
});
