/*
 * Writes the area option (contiArea2All) to NVRAM via lowlevelstorage/setData
 * (bypasses factorymanager geolock) and updates configd + settings DB for the
 * decoded region. Exit code 0 on success.
 *
 * Usage: node region-write.js <area>   (e.g. 22282 = US)
 */
var boot = require('./bootstrap.js');

var area = parseInt(process.argv[2] || '0', 10);
if (isNaN(area) || area <= 0 || area > 65535) {
  console.log('ERROR: invalid area code');
  process.exit(1);
}

var LC = [
  'NORDIC', 'NON NORDIC', 'EAST EU', 'WEST EU', 'ETC EU', 'AJ', 'JA', 'IL',
  'TW', 'CO', 'PA', 'CN', 'HK', 'KR', 'US', 'CA', 'MX', 'HN', 'BR', 'CL',
  'PE', 'AR', 'EC', 'JP', 'EU', 'IR', 'PH', 'BW', 'CS'
];
var HW = ['EU', 'AJ JA IL', 'TW CO', 'CN HK', 'KR', 'US', 'SA', 'JP'];
var COUNTRY = {
  US: 'USA', CA: 'CAN', MX: 'MEX', BR: 'BRA', AR: 'ARG', CL: 'CHL', PE: 'PER',
  CO: 'COL', EC: 'ECU', HN: 'HND', PA: 'PAN', CN: 'CHN', HK: 'HKG', TW: 'TWN',
  KR: 'KOR', JP: 'JPN', PH: 'PHL', IL: 'ISR', EU: 'DEU', AJ: 'AUS', JA: 'ZAF'
};
var LANGGRP = {
  US: 'langSelUS', CA: 'langSelUS', MX: 'langSelUS', BR: 'langSelBR',
  CN: 'langSelCN', HK: 'langSelHK', TW: 'langSelTW', KR: 'langSelKR',
  JP: 'langSelJP', EU: 'langSelEU'
};

var pb = require('palmbus');
var h = boot.createHandle(pb);

var RESP = { setData: true };

h.call(
  'luna://com.webos.service.lowlevelstorage/setData',
  JSON.stringify({
    dbgroups: [{ dbid: 'factory', items: { contiArea2All: String(area) } }]
  })
).on('response', function (m) {
  try {
    var r = JSON.parse(m.payload());
    if (r.returnValue) {
      console.log('[+] contiArea2All -> ' + area);
    } else {
      console.log('[-] setData failed: ' + m.payload());
      process.exit(1);
    }
  } catch (e) {
    console.log('[-] setData parse error: ' + e.message);
    process.exit(1);
  }
});

setTimeout(function () {
  var ci = area & 0x7f;
  var lc = (area >> 7) & 0x1f;
  var hw = (area >> 12) & 0xf;
  var lcName = LC[lc] || 'US';
  var hwName = HW[hw] || 'US';
  var cc = COUNTRY[lcName] || lcName;
  var lg = LANGGRP[lcName] || 'langSel' + lcName;
  console.log(
    '[+] decoded: continentIdx=' + ci +
    ' languageCountry=' + lcName +
    ' hwSettingGroup=' + hwName +
    ' country=' + cc +
    ' langGroup=' + lg
  );

  h.call(
    'luna://com.webos.service.config/setConfigs',
    JSON.stringify({
      configs: {
        'tv.model.languageCountrySel': lcName,
        'tv.model.hwSettingGroup': hwName,
        'tv.model.continentIndx': ci
      }
    })
  ).on('response', function (m) {
    try {
      var r = JSON.parse(m.payload());
      console.log('[+] configd: ' + (r.returnValue ? 'ok' : m.payload()));
    } catch (e) {}
  });

  setTimeout(function () {
    h.call(
      'luna://com.webos.service.settings/setSystemSettings',
      JSON.stringify({
        category: 'option',
        settings: {
          country: cc,
          smartServiceCountryCode3: cc,
          localeCountryGroup: lg
        }
      })
    ).on('response', function (m) {
      try {
        var r = JSON.parse(m.payload());
        console.log('[+] settings: ' + (r.returnValue ? 'ok' : m.payload()));
      } catch (e) {}
    });
  }, 500);

  setTimeout(function () {
    h.call(
      'luna://com.webos.service.lowlevelstorage/getData',
      JSON.stringify({ dbgroups: [{ dbid: 'factory', items: ['contiArea2All'] }] })
    ).on('response', function (m) {
      console.log('[+] verify: ' + m.payload());
      process.exit(0);
    });
  }, 1200);
}, 1000);

setTimeout(function () {
  console.log('[-] timeout');
  process.exit(1);
}, 8000);