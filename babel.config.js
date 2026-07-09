module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    // Lets Drizzle inline generated .sql migration files at build time.
    plugins: [['inline-import', { extensions: ['.sql'] }]],
  };
};
