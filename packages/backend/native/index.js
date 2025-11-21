const fs = require('node:fs');
const path = require('node:path');

const getRequire = () =>
  typeof __non_webpack_require__ === 'function'
    ? __non_webpack_require__
    : require;

const resolveNativePath = filename => {
  const req = getRequire();
  const pkgRoot = path.dirname(req.resolve('@affine/server-native'));
  const target = path.join(pkgRoot, filename);
  if (!fs.existsSync(target)) {
    throw new Error(`Native binary missing: ${filename}`);
  }
  return { req, target };
};

/** @type {import('.')} */
const loadNative = filename => {
  const { req, target } = resolveNativePath(filename);
  return req(target);
};

const binding = (() => {
  try {
    return loadNative('server-native.node');
  } catch {
    const archSpecific =
      process.arch === 'arm64'
        ? 'server-native.arm64.node'
        : process.arch === 'arm'
          ? 'server-native.armv7.node'
          : 'server-native.x64.node';
    return loadNative(archSpecific);
  }
})();

module.exports = binding;
