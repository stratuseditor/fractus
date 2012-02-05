#!/usr/bin/env node
var commander = require('commander')
  , build     = require('../lib/build');

commander
  .version('0.0.1')
  .option('-l, --langs <langs>', 'Bundle the comma-separated syntaxes (required).')
  .option('-j, --js <file>',     'The JavaScript output file.')
  .option('-c, --css <file>',    'The CSS output file.')
  .option('-t, --theme <theme>', 'The theme name.')
  .option('-u, --underscore',    'Dont include the Underscore.js source')
  .option('-q, --jquery',        'Dont include the jQuery source');

commander.parse(process.argv);

if (!commander.langs) {
  console.log("");
  console.log("  Sample usage:");
  console.log("");
  console.log("  $ fractus -l Ruby,JavaScript,JSON -j fractus.js -c fractus.css -t Idlefingers");
  console.log("");
  process.exit();
}

var theme      = commander.theme
  , js         = commander.js  || "fractus.js"
  , css        = commander.css || "fractus.css"
  , langs      = commander.langs
  , jquery     = !commander.jquery
  , underscore = !commander.underscore;

var langs      = langs.split(",");


Build = build(
{ langs:      langs
, theme:      theme
, jquery:     jquery
, underscore: underscore
});

Build.js(js, function(err) {
  if (err) throw err;
  Build.css(css, function(err) {
    if (err) throw err;
    process.exit();
  });
});
