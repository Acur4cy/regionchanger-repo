/*
 * Reads the current NVRAM area option (contiArea2All) and prints the decoded
 * bit fields. Exit code 0 on success.
 */
var boot = require('./bootstrap.js');
var pb = require('palmbus');
var h = boot.createHandle(pb);

h.call(
  'luna://com.webos.service.lowlevelstorage/getData',
  JSON.stringify({ dbgroups: [{ dbid: 'factory', items: ['contiArea2All'] }] })
).on('response', function (m) {
  try {
    var r = JSON.parse(m.payload());
    if (r.returnValue) {
      var v = parseInt(r.dbgroups[0].items.contiArea2All, 10);
      console.log('AREA=' + v);
      console.log('continentIdx=' + (v & 0x7f));
      console.log('languageCountry=' + ((v >> 7) & 0x1f));
      console.log('hwSettingGroup=' + ((v >> 12) & 0xf));
      process.exit(0);
    } else {
      console.log('ERROR: ' + m.payload());
      process.exit(1);
    }
  } catch (e) {
    console.log('ERROR: ' + e.message);
    process.exit(1);
  }
});

setTimeout(function () {
  console.log('ERROR: timeout');
  process.exit(1);
}, 5000);