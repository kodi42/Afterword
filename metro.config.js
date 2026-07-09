const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);
// Allow Metro to treat Drizzle's generated .sql files as source.
config.resolver.sourceExts.push('sql');

module.exports = config;
