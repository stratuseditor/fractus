{EventEmitter}          = require 'events'
{Buffer, Point, Region} = require './buffer'
_                       = require 'underscore'
color                   = require 'stratus-color'

# The layout:
# 
#   * connects the syntax highlighter to the buffer
#   * performs positioning calculations for
#     - lines
#     - cursors
#     - selections
#   * determines which lines are visible
# 
# Events:
# 
#   * render - {html}      - Re-render all of the visiblelines.
#     * render:line:change - {row, html} - Re-render the given line.
#     * render:line:insert - {row, html} - Insert a new row in.
#     * render:line:delete - {row, html} - Delete the line at `row`
#                                          and append the line with `html`.
#   * scrollY         - scrollTop
#   * gutter:renumber - {begin, end}
#   * gutter:resize   - width
#   * change:width    - The maximum width of the editor.
#   * change:height   - height
# 
# Public properties:
# 
#    * scrollLock (Boolean)
# 
module.exports.Layout = class Layout extends EventEmitter
  # Public: Initialize a Layout.
  # 
  # buffer       - A Buffer
  # sizeOf       - A function which receives a character and returns
  #                an array [width, height] of that character.
  # height       - The height in pixels of the editor.
  # width        - The height in pixels of the editor.
  # syntax       - The string bundle name to use.
  # uniform      - `false` if the text is variable-width
  #                (i.e. unicode stuff or hard tabs).
  # 
  constructor: (@buffer, @sizeOf, @height, @width, @syntax=null, @uniform=false) ->
    @buffer.on "reset",              => @onReset()
    @buffer.on "line:change", (data) => @onLineChange data
    @buffer.on "line:insert", (data) => @onLineInsert data
    @buffer.on "line:delete", (data) => @onLineDelete data
    @syntax  = null if @syntax == "Text"
    @hardTab = 8
  
  ready: ->
    @onReset()
  
  # Public: Scroll to the given row.
  # 
  # row   - The row that will be at the top of the visible
  #         portion of the editor.
  # col   - The column that will be at the far left of the visible content.
  # force - Re-render even if it is already at the row.
  # 
  # Returns Boolean: whether or not the scroll changed.
  scrollTo: (row, force=false) ->
    return false if !force && @scrollLock
    return false if !force && row == @topRow
    visibleRows = @visibleRows()
    {row}       = row if row instanceof Point
    row         = 0   if row < 0
    row         = max if row > max = @buffer.lineCount() - visibleRows + 1
    row         = 0   if visibleRows >= @buffer.lineCount()
    return false if !force && row == @topRow
    
    @topRow = row
    @_renderVisible()
    @emit "scrollY", @scrollTop(row)
    @renumber()
    return true
  
  # Public: Get the pixels scrollTop value if the given `row` were
  # scrolled to.
  # 
  # Returns Integer (pixels).
  scrollTop: (row) ->
    return row * @sizeOf().height
  
  # Public: Rather than `row` becoming the top visible line, it is
  # the bottom.
  # 
  # Returns nothing.
  scrollBottom: (row) ->
    @scrollTo row - @visibleRows() + 1
  
  # Public: Prevent the editor from scrolling.
  # 
  # Examples
  # 
  #   layout.scrollTo 100
  #   layout.lockScroll()
  #   # Does nothing, the scroll is still at row 100.
  #   layout.scrollTo 5
  #   # Allow scrolling to resume.
  #   layout.unlockScroll()
  # 
  # Returns nothing.
  lockScroll: ->
    @scrollLock = true
  
  # Public: Allow scrolling again.
  # 
  # Returns nothing.
  unlockScroll: ->
    @scrollLock = false
  
  # Public: Get the total height of **all** of the lines (not just the
  # visible ones). This can be used to fake the size of the scroll bar.
  # 
  # Returns Integer (pixels).
  totalHeight: ->
    return (@buffer.lineCount() + 1) * @sizeOf().height
  
  # Public: Get the height of the given row.
  # 
  # Returns Integer (pixels).
  lineHeight: (row) ->
    return @sizeOf().height
  
  # Public: Set the width of the visible portion of the editor
  # (excluding the gutter).
  setWidth: (@width) ->
  
  # Public: Set the height of the visible portion of the editor.
  setHeight: (@height) ->
  
  # Internal: The number of rows to be rendered at a time.
  visibleRows: -> Math.floor @height / @sizeOf().height
  
  # Public: Get whether or not the given line is being rendered.
  # 
  # row -
  # 
  # Returns Boolean.
  isVisible: (row) ->
    return @topRow <= row <= @topRow + @visibleRows()
  
  # Internal: Get the html for the given row.
  # 
  # Returns an HTML String.
  renderRow: (row) ->
    return "" unless row < @buffer.lineCount()
    return lineHtml if lineHtml = @lineCache[row]
    if @syntax
      tokens          = @tokenize row
      @lineCache[row] = "<li>#{ color.html(tokens) }</li>"
    else
      line            = @buffer.text row
      @lineCache[row] = "<li>#{ color.escape(line) }</li>" if line?
    return @lineCache[row]
  
  # Internal: Get the tokens for the given row.
  # 
  # Returns an Array of tokens.
  tokenize: (row) ->
    return lineTokens if lineTokens = @tokenCache[row]
    lineText = "\n#{ @buffer.text(row) }\n"
    # Highlight everything up to the necessary point.
    if !@contexts[row]
      @tokenize row - 1
    oldState           = @contexts[row + 1]?.slice() || []
    {tokens, stack}    = color.tokenize lineText, @contexts[row].slice()
    @contexts[row + 1] = stack
    
    if _.last(stack) != _.last(oldState)
      @lineCache[row + 1]  = null
      @tokenCache[row + 1] = null
    
    return @tokenCache[row] = tokens
  
  # ----------------
  # Buffer events
  # ----------------
  
  # Internal: 
  onLineChange: (data) ->
    {row, text}      = data
    # Invalidate the cache for the given row.
    @lineCache[row]  = null
    @tokenCache[row] = null
    oldState         = @contexts[row + 1].slice() if @syntax
    
    if @isVisible row
      @emit "render:line:change", {row, html: @renderRow(row)}
    else
      @lineCache[row + 1]  = null
      @tokenCache[row + 1] = null
    
    if @syntax
      newState = @contexts[row + 1]
      # Update the following lines.
      @_updateRow row + 1 unless _.last(newState) == _.last(oldState)
  
  # Internal: 
  onLineInsert: (data) ->
    @onRowCountChange()
    {row, text} = data
    @lineCache.splice row, 0, null
    @tokenCache.splice row, 0, null
    if @syntax
      oldState = @contexts[row].slice()
      @contexts.splice row, 0, oldState.slice()
    
    if @isVisible row
      @emit "render:line:insert", {row, html: @renderRow(row)}
    
    if @syntax
      newState = @contexts[row + 1]
      @_updateRow row + 1 unless _.last(newState) == _.last(oldState)
  
  # Internal: 
  onLineDelete: (data) ->
    @onRowCountChange()
    {row, text} = data
    @lineCache.splice row, 1
    @tokenCache.splice row, 1
    if @syntax
      oldState = @contexts[row].slice()
      @contexts.splice row + 1, 1
      @contexts[0] = [@syntax]
    
    if @isVisible row
      nextRow = @topRow + @visibleRows() - 1
      @emit "render:line:delete", {row, html: @renderRow(nextRow)}
    
    if @syntax
      newState = @contexts[row]
      @_updateRow row# unless _.last(newState) == _.last(oldState)
  
  # Internal: 
  onReset: ->
    @onRowCountChange()
    @tokenCache = []
    @lineCache  = []
    @contexts   = [[@syntax]]
    @scrollTo 0, 0
    @_renderVisible()
  
  # Internal: Rehighlight the given row.
  _updateRow: (row) ->
    return if row == @buffer.lineCount()
    @onLineChange {row, text: @buffer.text(row)}
  
  # Internal: Rerender all of the visible lines.
  _renderVisible: ->
    {topRow}     = this
    visibleLines = [topRow..(topRow + @visibleRows() + 4)]
    visibleLines = _.map visibleLines, (r) => @renderRow(r)
    @emit "render", visibleLines.join("")
  
  # ----------------
  # Coordinates
  # ----------------
  
  # Public: Convert a point to coordinates.
  # The `left` value **does** take into account the gutter's offset.
  # 
  # point - The point to convert.
  # 
  # Examples
  # 
  #   layout.pointToCoords buffer.point(0, 2)
  #   # => [0, 30]
  # 
  # Returns [top, left].
  pointToCoords: (point) ->
    {row, col} = point
    top        = @sizeOf().height * row
    # Uniform width:
    if @uniform
      left = @widthOf row, 0, col
    # Variable width:
    else
      line = @buffer.text(row)
      if !line
        left = @sizeOf().width * col
      else
        left = @widthOf row, 0, col
    left += @gutterWidth
    return [top, left]
  
  # Public: Convert a region to coordinates.
  # 
  # region - A Region to convert.
  # 
  # Return Object: {top, left, height, width}.
  regionToCoords: (region) ->
    {begin, end}          = region.ordered()
    [beginTop, beginLeft] = @pointToCoords begin
    [endTop, endLeft]     = @pointToCoords end
    return {
      top:    beginTop
      left:   beginLeft
      width:  endLeft - beginLeft
      height: @lineHeight(begin.row)
    }
  
  # Public: Get the closest point to the coordinates.
  # 
  # top  - The Integer y offset.
  # left - The Integer x offset.
  # 
  # Returns Point.
  coordsToPoint: (top, left) ->
    row  = Math.floor top / @sizeOf().height + @topRow
    # Uniform width:
    if @uniform
      col = Math.round left / @sizeOf().width
    # Empty line.
    else if !(line = @buffer.text(row)) || !line.length
      col = 0
    # Variable width:
    else
      carat    = 0
      colCarat = 0
      for char, i in line
        if char == "\t"
          tabCols   = @tabWidth colCarat
          width     = tabCols * @sizeOf().width
          colCarat += tabCols
        else
          {width} = @sizeOf char
          colCarat++
        carat += width
        
        # Exact match.
        if carat == left
          col = i + 1
          break
        # Rounding is needed.
        else if carat > left
          # Round up.
          if left > carat - (width / 2)
            col = i + 1
          # Round down.
          else
            col = i
          break
      col ?= line.length
    return @buffer.point row, col
  
  # Public: Get the width of the region of text between `colBegin` and
  # `colEnd`.
  # 
  # row      -
  # colBegin - The column to begin measuring from.
  # colEnd   - The column to stop measuring at.
  # 
  # Returns Integer pixels.
  widthOf: (row, colBegin, colEnd) ->
    if @uniform
      return @sizeOf().width * col
    else
      line  = @buffer.text(row).substr(colBegin, colEnd)
      width = 0
      carat = colBegin
      for char, i in line
        if char == "\t"
          tabCols = @tabWidth carat
          width  += tabCols * @sizeOf().width
          carat  += tabCols
        else
          width += @sizeOf(char).width
          carat++
      return width
  
  # Internal: Calculate the column width of the _hard_ tab, assuming that
  # it begins at the given column.
  # 
  # Returns Integer columns.
  tabWidth: (col) ->
    return @hardTab - (col % @hardTab)
  
  # Public: Whether or not the given Top coordinate exactly matches
  # the top of a row.
  # 
  # Examples
  # 
  #   layout.isRowTop 15
  #   # => true
  # 
  #   layout.isRowTop 14
  #   # => false
  # 
  # Returns boolean.
  isRowTop: (top) ->
    return Math.floor(top / @sizeOf().height) < @buffer.lineCount()
  
  # Public: Get whether or not the point is above the visible lines.
  # 
  # point - A Point.
  # 
  # Returns boolean.
  isTooFarUp: (point) ->
    return point.row < @topRow
  
  # Public: Get whether or not the point is below the visible lines.
  # 
  # point - A Point.
  # 
  # Returns boolean.
  isTooFarDown: (point) ->
    return point.row + 1 > @topRow + @visibleRows()
  
  # ----------------
  # Gutter
  # ----------------
  
  # Internal: The number of digits in the highest line number.
  # For example, if the buffer has 5 lines, it returns 1.
  # If the buffer has 1000 lines, it returns 4.
  # 
  # Returns Integer.
  gutterChars: ->
    return ("" + @buffer.lineCount()).length
  
  # Internal: Update the width of the gutter, if it has changed.
  updateGutterWidth: ->
    return if @gutterWidth == gw = @calcGutterWidth()
    @emit "gutter:resize", @gutterWidth = gw
  
  # Internal: Calculate what the gutter width should be.
  calcGutterWidth: ->
    return @sizeOf().width * (@gutterChars() + 1)
  
  # Internal: Called when the total number of lines is changed.
  onRowCountChange: ->
    @updateGutterWidth()
    @renumber()
    @emit "change:height", @totalHeight()
  
  # Internal: Emit the `gutter:renumber` event, indicating
  # that the line numbers need to be changed.
  renumber: ->
    end = @topRow + @visibleRows()
    end = max if end > max = @buffer.lineCount() - 1
    @emit "gutter:renumber",
      begin: @topRow
      end:   end


