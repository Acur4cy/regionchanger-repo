/*
 * Region Changer - Luna service for LG webOS TV
 *
 * Reads/writes the NVRAM area option (contiArea2All) via the
 * lowlevelstorage service, bypassing factorymanager's geolock.
 *
 * Parts based on https://github.com/lennylxx/lg-geolock-bypass (MIT).
 */
var child_process = require('child_process');
var path = require('path');
var Service = require('webos-service');

var SERVICE_ID = 'org.webosbrew.regionchanger.service';
var service = new Service(SERVICE_ID);

var NODE_PATH = '/usr/lib/nodejs:/usr/lib/node_modules';

function envWithNodePath() {
  var env = {};
  var k;
  for (k in process.env) {
    if (Object.prototype.hasOwnProperty.call(process.env, k)) {
      env[k] = process.env[k];
    }
  }
  env.NODE_PATH = NODE_PATH;
  env.PATH = '/usr/bin:/bin:/usr/local/bin';
  return env;
}

function runScript(scriptName, args, callback) {
  var script = path.join(__dirname, scriptName);
  child_process.execFile(
    'node',
    [script].concat(args || []),
    {
      env: envWithNodePath(),
      timeout: 20000,
      maxBuffer: 4 * 1024 * 1024
    },
    function (err, stdout, stderr) {
      callback(err, stdout || '', stderr || '');
    }
  );
}

service.register('read', function (message) {
  var extra = { returnValue: true, output: '' };
  runScript('region-read.js', [], function (err, stdout, stderr) {
    if (err) {
      message.respond({
        returnValue: false,
        errorText: err.message || String(err),
        output: stdout,
        stderr: stderr
      });
      return;
    }
    extra.output = stdout;
    var m = stdout.match(/^AREA=(\d+)$/m);
    if (m) {
      extra.area = parseInt(m[1], 10);
    }
    var fields = {};
    var re = /^(\w+)=(\d+)$/gm;
    var mm;
    while ((mm = re.exec(stdout))) {
      if (mm[1] !== 'AREA') {
        fields[mm[1]] = parseInt(mm[2], 10);
      }
    }
    extra.fields = fields;
    message.respond(extra);
  });
});

service.register('verify', function (message) {
  runScript('region-verify.js', [], function (err, stdout, stderr) {
    if (err) {
      message.respond({
        returnValue: false,
        errorText: err.message || String(err),
        output: stdout,
        stderr: stderr
      });
    } else {
      message.respond({ returnValue: true, output: stdout });
    }
  });
});

service.register('change', function (message) {
  var raw = message.payload && message.payload.area;
  var area = String(raw === undefined ? '' : raw).replace(/[^0-9]/g, '');
  if (!area) {
    message.respond({
      returnValue: false,
      errorText: 'Missing valid numeric "area" (e.g. 22282 = US, 19461 = EU)'
    });
    return;
  }
  runScript('region-write.js', [area], function (err, stdout, stderr) {
    if (err) {
      message.respond({
        returnValue: false,
        errorText: err.message || String(err),
        output: stdout,
        stderr: stderr
      });
    } else {
      message.respond({ returnValue: true, output: stdout });
    }
  });
});

service.register('reboot', function (message) {
  // The bus may die while the TV shuts down; answer optimistically.
  runScript('region-reboot.js', [], function (err, stdout, stderr) {
    var text = (stdout + ' ' + (stderr || '')).trim();
    message.respond({
      returnValue: true,
      output: text || 'Reboot command sent (reply may be lost while the TV shuts down).'
    });
  });
});