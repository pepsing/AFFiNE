const fs = require('node:fs');
const path = require('node:path');

/** @type {import('.')} */
const loadNative = filename => {
  const target = path.join(__dirname, filename);
  if (!fs.existsSync(target)) {
    throw new Error(`Native binary missing: ${filename}`);
  }
  return require(target);
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
