fs         = require 'fs'
path       = require 'path'
{exec}     = require 'child_process'
stylus     = require 'stylus'
browserify = require 'browserify'
nib        = require 'nib'
_          = require 'underscore'
bundle     = require 'stratus-bundle'
color      = require 'stratus-color'

# The directory containing dependencies such as jQuery.
VENDOR = "#{__dirname}/../vendor"

# Public: Build the Fractus JavaScript.
# 
# options -
#         * langs  - Array of String (required).
#         * theme  - String (optional).
#         * jquery - Whether or not to include the jQuery source (optional).
# 
# Returns nothing.
module.exports = build = (options) ->
  return new FractusBuild options


build.path = "#{__dirname}/../styl"

class FractusBuild
  constructor: (options) ->
    {@langs, @theme, @jquery, @underscore} = options
    @bundles = {}
    for lang in @langs.slice()
      @addLang lang
    
    @theme     ||= "Idlefingers"
    @jquery     ?= true
    @underscore ?= true
  
  # Internal: Add the language and it's dependencies to the languages
  # to be included in the Fractus build.
  # 
  # lang - String bundle name.
  # 
  # Returns nothing.
  addLang: (lang) ->
    @bundles[lang] ?= bundle lang
    langBundle      = @bundles[lang]
    @addLang langBundle.extends if langBundle.extends
    for sublang in (langBundle.require || [])
      @addLang sublang
    
    if !~@langs.indexOf(lang)
      @langs.push lang
    return
  
  # Public: Load the JavaScript into a file, or return it.
  # 
  # file     - The path of the JavaScript file to write to (optional).
  # callback - If the `file` is given, this is called on completion (optional).
  # 
  # Returns the JavaScript String, unless a file is passed.
  js: (file, callback) ->
    jsCode = """
        window.fractusBundles = {};
      """
    
    if @jquery
      jsCode += fs.readFileSync("#{VENDOR}/jquery-1.7.1.min.js").toString()
    if @underscore
      jsCode += fs.readFileSync(require.resolve("underscore")).toString()
    
    browserBundle = browserify()
    #browserBundle.addEntry "#{__dirname}/../../nothing.coffee"
    browserBundle.require require.resolve("./")
    
    jsCode += browserBundle.bundle()
    
    jsCode += """
        require.modules.fractus = require.modules["/index.js"];
        !function() {
          var color = require("/node_modules/stratus-color/lib/highlight.js");
      """
    for lang in @langs
      bund         = @bundles[lang].toJSONSync()
      bundleString = JSON.stringify bund
      jsCode      += """
          window.fractusBundles['#{lang}'] = #{bundleString};
          color.addScopes(window.fractusBundles['#{lang}'].syntax);
        """
    jsCode += """
        }()
      """
    
    if file
      fs.writeFile file, jsCode, (err) ->
        return callback err
    else
      return jsCode
  
  # Public: Load the CSS into a file, or return it.
  # 
  # file     - The path of the CSS file to write to (optional).
  # callback - If the `file` is given, this is called on completion. Otherwise
  #            it is called with `(err, css)`.
  # 
  # Returns nothing.
  css: (file, callback) ->
    if file && !callback
      [callback, file] = [file, callback]
    cssCode = color.css @theme,
      root:      "fractus"
      cursor:    "fractus-cursor"
      selection: "fractus-selection"
    cssCode += "\n"
    styl     = fs.readFileSync("#{__dirname}/../styl/fractus.styl").toString()
    stylus(styl)
      .set("filename", "fractus.styl")
      .include(nib.path)
      .render (err, css) ->
        cssCode += css unless err
        if file
          fs.writeFile file, cssCode, (err) ->
            return callback err
        else
          return callback err, cssCode

