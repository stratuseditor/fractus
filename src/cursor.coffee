{EventEmitter}          = require 'events'
{Buffer, Point, Region} = require './buffer'

# Events:
# 
#   * move
# 
class Cursor extends EventEmitter
  constructor: (@buffer, row, col) ->
    @point = buffer.point row, col
    @point.on "move", => @emit "move"
    
    @buffer.on "line:change", => @point?.round()
    @buffer.on "line:insert", => @point?.round()
    @buffer.on "line:delete", => @point?.round()
  
  serialize: ->
    if @point
      { row: @point.row, col: @point.col }
    else
      begin:
        row: @region.begin.row
        col: @region.begin.col
      end:
        row: @region.end.row
        col: @region.end.col
  
  # Reposition the cursor.
  deserialize: (data) ->
    if data.row?
      @moveTo data.row, data.col
    else
      @select data
  
  toPoint: ->
    return if @point
    @point  = @region.end
    @region = null
    @point.on "move", => @emit "move"
  
  toRegion: ->
    return if @region
    @region = new Region @point, @point.clone()
    @point  = null
    
    @region.begin.removeAllListeners "move"
    @region.begin.on "move", => @emit "move"
    @region.end.on   "move", => @emit "move"
  
  # Public: 
  moveTo: (row, col) ->
    @toPoint()
    @point.moveTo row, col
    @point.round()
  
  # Public: 
  select: (region) ->
    @toRegion()
    @region.begin.moveTo region.begin
    @region.end.moveTo region.end
  
  # Public: 
  selectTo: (row, col) ->
    @toRegion()
    @region.end.moveTo row, col
    @region.end.round()
  
  extendTo: (region) ->
    @toRegion()
    @region.extendTo region
  
  # Public: Translate the point vertically.
  moveVertical: (amount) ->
    @toPoint()
    @point.moveVertical amount
    @point.round()
  
  # Public: Translate the point vertically.
  selectVertical: (amount) ->
    @toRegion()
    @region.end.moveVertical amount
    @region.end.round()
  
  selectAll: ->
    @toRegion()
    lastRow = @buffer.lineCount() - 1
    lastCol = @buffer.lineLength lastRow
    @region.begin.moveTo 0, 0
    @region.end.moveTo lastRow, lastCol
  
  
  selectRow: (row) ->
    @toRegion()
    @region.selectRow row
  
  selectRows: (r1, r2) ->
    @toRegion()
    @region.selectRows r1, r2
  
  # Public: Insert text from the cursor position, and move it to the end.
  insert: (text) ->
    @deleteSelection()
    @toPoint()
    @point.insert text
  
  # Public: Overwrite text from the cursor position, and move it to the end.
  overwrite: (text) ->
    @toPoint()
    @point.overwrite text
  
  # Public: Backspace.
  deleteBack: ->
    return if @deleteSelection()
    @toPoint()
    @point.deleteBack()
  
  # Public: Delete forward a character.
  deleteForward: ->
    return if @deleteSelection()
    @toPoint()
    @point.deleteForward()
  
  # Public: Delete backward until a /[^\w][\w]/ barrier is hit.
  deleteWordBack: ->
    @deleteSelection()
    @toPoint()
    @point.deleteWordBack()
  
  # Public: Delete forward until a /[\w][^\w]/ barrier is hit.
  deleteWordForward: ->
    @deleteSelection()
    @toPoint()
    @point.deleteWordForward()
  
  # Public: Create a newline at the point (like hitting enter).
  newLine: ->
    @toPoint()
    @point.newLine()
  
  # Return boolean: whether or not anything got deleted.
  deleteSelection: ->
    if !@region || @region.isEmpty()
      return false
    else
      @region.delete()
      @emit "move"
      return true
  
  deleteRows: ->
    @toRegion()
    {begin, end} = @region.ordered()
    @buffer.deleteLines begin.row, end.row
    @toPoint()
    @point.moveTo begin
    @point.round()
  
  # Public: Get the region's contents.
  text: ->
    @toRegion()
    return @region.text()
  
  # Public: Indent the selected rows.
  indent: (tab) ->
    if @point || @region.isEmpty()
      @insert tab
    else
      @region.indent tab
  
  # Public: Outdent the selected rows.
  outdent: (tab) ->
    @toRegion()
    @region.outdent tab
  
  # Public: Scroll up a page, and move the cursor the same distance.
  pageUp: ->
    @toPoint()
    # TODO
  
  pageDown: ->
    @toPoint()
    # TODO


pointMethods = [
  "moveToLineBegin", "moveToLineEnd"
  "moveToPrevWord",  "moveToNextWord"
  "moveToDocBegin",  "moveToDocEnd"
  "moveLeft",        "moveRight"
  "moveUp",          "moveDown"
]
for method in pointMethods
  do (method) ->
    # Add the cursor method.
    Cursor.prototype[method] = ->
      @toPoint()
      @point[method]()
      @point.round()
    
    # Add the selection method.
    Cursor.prototype[method.replace(/^move/, "select")] = ->
      @toRegion()
      @region.end[method]()
      @region.end.round()


regionMethods = ["shiftLinesDown", "shiftLinesUp"]
for method in regionMethods
  do (method) ->
    Cursor.prototype[method] = ->
      @toRegion()
      @region[method]()

module.exports = {Cursor}
