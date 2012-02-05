{EventEmitter}          = require 'events'
color                   = require 'stratus-color'
keyboard                = require 'stratus-keyboard'

{Buffer, Point, Region} = require './buffer'
{Cursor}                = require './cursor'
{View}                  = require './view'
{Layout}                = require './layout'

InsertMode = require './modes/insert_mode'

# Public: Create an editor.
# 
# $el     - The element to use as the root of the editor.
# options - See Editor#constructor (optional).
# 
# Examples
# 
#   fractus = require 'fractus'
#   fractus $("#el"),
#     text:   "def foo\n  return 'hi'\nend"
#     syntax: "Ruby"
#     tab:    "  "
# 
# Return an instance of Editor.
module.exports = fractus = ($el, options) ->
  return new Editor $el, (options || {})

fractus.InsertMode = InsertMode
fractus.current    = null

# Public: Convert a textarea to a fractus editor.
# 
# Same parameters as `fractus()`, except the `$el`
# should be a textarea element.
# 
# Returns Editor.
fractus.textarea = ($textarea, options) ->
  width  = $textarea.width()
  height = $textarea.height()
  name   = $textarea.attr "name"
  
  $el    = $ "<div/>"
  $el.css {width, height}
  
  $textarea.replaceWith $el
  ed = new Editor $el, (options || {})
  ed.view.input.$el.attr {name}
  return ed

# Properties:
# 
#   * mode
#   * syntax
#   * tab
# 
# Events:
# 
#   * focus
#   * blur
# 
fractus.Editor = class Editor extends EventEmitter
  # options -
  #   
  #   * text        - String - the initial editor text
  #   * syntax      - Object - a bundle object
  #   * tab         - String - the tab characters (such as "    " or "\t").
  #   * mode        - Defaults to InsertMode. (Object or Function)
  #   * scrollwheel - Integer: The number of rows to scroll at a time.
  # 
  constructor: ($el, options) ->
    { text, syntax, @tab, mode
    , scrollwheel, @wrap} = options
    
    text        ?= ""
    scrollwheel ?= 4
    @tab        ?= syntax?.tab || "    "
    @setMode mode || InsertMode
    
    @buffer = new Buffer text, =>
      return @cursor.serialize()
    , (data) =>
      @cursor.deserialize data
    @cursor = new Cursor @buffer, 0, 0
    @layout = new Layout @buffer, View.sizeOf, null, null, @syntax
    
    @view   = new View $el, @buffer, @layout, @cursor, {scrollwheel}
    @view.on "focus", =>
      fractus.current = this
      @emit "focus"
    @view.on "blur", =>
      @emit "blur"
    
    fractus.current = this
    @setSyntax options.syntax if options.syntax
  
  setMode: (@mode) ->
  setSyntax: (@syntax) ->
    @layout.syntax = @syntax.name
    if @syntax.name == "Text"
      @layout.syntax = null
    @layout.onReset()
  
  # Public: Get the editor's text.
  # 
  # Returns String.
  text: -> @buffer.text()
  
  # Public: Focus the editor.
  # 
  # Returns nothing.
  focus: ->
    @view.focus()
  
  # Public: Refresh the rendered portion.
  refresh: ->
    @layout.scrollTo @layout.topRow, true
  
  # Public: This must be called whenever the size of the editor element
  # is changed.
  # 
  # Returns nothing.
  resize: ->
    @view.onResize()
    @layout.scrollTo @layout.topRow, true
  
  # Public: Highlight the given region of text.
  # 
  # region   - A Region.
  # cssClass - String css class, to make it easy to reset the emphasis.
  # 
  # Returns nothing.
  emphasize: (region, cssClass) ->
    coords = @layout.regionToCoords region
    $("<div></div>", class: "hi-emphasize #{cssClass}")
      .appendTo(@view.$scrollView)
      .css(coords)
    return

keyboard "fractus", (key) ->
  edt    = fractus.current
  {mode} = edt
  if typeof mode == "function"
    val = mode edt, key
  else if action = mode[key]
    action edt
    val = false
  else
    val = mode["otherwise"]? edt, key
  return val


