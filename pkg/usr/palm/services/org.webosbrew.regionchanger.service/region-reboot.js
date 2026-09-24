/*
 * Reboots the TV through the sleep/shutdown service.
 */
var boot = require('./bootstrap.js');
var pb = require('palmbus');
var h = boot.createHandle(pb);

h.call(
  'luna://com.webos.service.sleep/shutdown/machineReboot',
  JSON.stringify({ reason: 'remoteKey' })
).on('response', function (m) {
  console.log('[+] reboot: ' + m.payload());
  process.exit(0);
});

setTimeout(function () {
  process.exit(0);
}, 3000);