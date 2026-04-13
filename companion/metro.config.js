const { getDefaultConfig } = require('expo/metro-config');
const path = require('path');

const config = getDefaultConfig(__dirname);

// base-rn is a local package symlinked from ../base-rn
const baseRnPath = path.resolve(__dirname, '../base-rn');

// Watch the base-rn source directory so changes hot-reload
config.watchFolders = [baseRnPath];

// Block base-rn's own node_modules — all deps must resolve from companion's
config.resolver.blockList = [
  new RegExp(path.resolve(baseRnPath, 'node_modules').replace(/[/\\]/g, '[/\\\\]') + '.*'),
];

// Ensure all shared deps resolve from companion's node_modules only
config.resolver.nodeModulesPaths = [
  path.resolve(__dirname, 'node_modules'),
];

config.resolver.extraNodeModules = new Proxy(
  {},
  { get: (_, name) => path.resolve(__dirname, 'node_modules', name) }
);

module.exports = config;
