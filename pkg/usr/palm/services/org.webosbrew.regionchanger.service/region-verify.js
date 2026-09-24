/*
 * Prints the three layers of region configuration: NVRAM, configd and the
 * user-facing settings DB. Exit code 0 on success.
 */
var boot = require('./bootstrap.js');
var pb = require('palmbus');
var h = boot.createHandle(pb);

function step1() {
  h.call(
    'luna://com.webos.service.lowlevelstorage/getData',
    JSON.stringify({ dbgroups: [{ dbid: 'factory', items: ['contiArea2All'] }] })
  ).on('response', function (m) {
    console.log('NVRAM: ' + m.payload());
    setTimeout(step2, 300);
  });
}

function step2() {
  h.call(
    'luna://com.webos.service.config/getConfigs',
    JSON.stringify({
      configNames: [
        'tv.model.languageCountrySel',
        'tv.model.hwSettingGroup',
        'tv.model.continentIndx'
      ]
    })
  ).on('response', function (m) {
    console.log('config: ' + m.payload());
    setTimeout(step3, 300);
  });
}

function step3() {
  h.call(
    'luna://com.webos.service.settings/getSystemSettings',
    JSON.stringify({
      category: 'option',
      keys: ['country', 'smartServiceCountryCode3', 'localeCountryGroup']
    })
  ).on('response', function (m) {
    console.log('settings: ' + m.payload());
    process.exit(0);
  });
}

setTimeout(function () {
  console.log('ERROR: timeout');
  process.exit(1);
}, 8000);

step1();