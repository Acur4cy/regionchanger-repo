/*
 * Monkey-patch needed so that the webOS system node process can load the
 * palmbus module from an unprivileged context (same trick as
 * lg-geolock-bypass). Must be required BEFORE require('palmbus').
 */
var Module = require('module');
var originalLoad = Module._load;

function noop() {}
function loggerFactory() {
  return { log: noop, info: noop, warning: noop, error: noop };
}

Module._load = function (request, parent, isMain) {
  if (request === 'pmloglib') {
    return {
      log: noop,
      info: noop,
      warning: noop,
      error: noop,
      Console: loggerFactory,
      Context: loggerFactory
    };
  }
  return originalLoad.apply(this, arguments);
};

exports.createHandle = function (pb) {
  try {
    return new pb.Handle('');
  } catch (e1) {
    try {
      return new pb.Handle('', true);
    } catch (e2) {
      throw new Error(
        'Unable to create palmbus Handle: ' + e1.message + ' / ' + e2.message
      );
    }
  }
};