# Fractus Editor

[![Build Status](https://secure.travis-ci.org/stratuseditor/fractus.png)](http://travis-ci.org/stratuseditor/fractus)

This is the editor component of [Stratus Editor](http://stratuseditor.com/).

# Standalone
Be sure you have
[stratus-bundle](https://github.com/stratuseditor/stratus-bundle)
installed, along with any syntaxes you plan on using.

To build the standalone editor:

    $ npm install fractus -g
    # Pass the languages you want to include,
    # and the paths to the JS and CSS files to write.
    $ fractus -l Ruby,JavaScript -j ./fractus.js -c ./fractus.css

Then, include the JavaScript and CSS files that it writes in your HTML.

This will turn `$("#some-element")` into an editor:

    jQuery(function($) {
      var fractus = require("fractus");
      var editor  = fractus($("#some-element"),
        { text:   "some\ntext"
        , syntax: window.fractusBundles["Ruby"]
      });
    });

# API
For Fractus' API, see the
[Stratus documentation](http://stratuseditor.com/plugins#Fractus).

## editor.text()

Get the editor's text:

    editor.text();
    // => "some\ntext"


# CLI

    Usage: fractus.coffee [options]
  
    Options:
  
      -h, --help           output usage information
      -V, --version        output the version number
      -l, --langs <langs>  Bundle the comma-separated syntaxes (required).
      -j, --js <file>      The JavaScript output file.
      -c, --css <file>     The CSS output file.
      -t, --theme <theme>  The theme name.
      -q, --jquery         Dont include the jQuery source

# License
See LICENSE.
