const nodeExternals = require('webpack-node-externals');

module.exports = function (options, webpack) {
  return {
    ...options,
    externals: [
      nodeExternals({
        allowlist: ['@mmo-rpg/shared'], // Bundle the shared library
      }),
    ],
  };
};
