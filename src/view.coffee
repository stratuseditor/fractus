{EventEmitter}  = require 'events'
{Point, Region} = require './buffer'
keyboard        = require 'stratus-keyboard'

char = _.memoize (c = "X") ->
  $div  = $("<div class='fractus'/>").css
    height:   "auto"
    position: "absolute"
    width:    "auto"
  $char = $ "<ul class='fractus-lines'><li><span>#{c}</span></li></ul>"
  $char = $char.find "span"
  $div.append($char).appendTo("body")
  size  =
    height: $char.height()
    width:  $char.width()
  $div.remove()
  return size

# The markup of the editor once all of the elements are in place looks
# something like this: (Jade)
# 
#   .fractus
#     textarea
#     .fractus-scroller
#     ul.fractus-lines
#       li The highlighted code
#       li goes in here.
#     .fractus-gutter
#       span 1
#       span 2
# 
# textarea          - See the Input class at the bottom of this file.
# .fractus-lines    - Contains the lines. Not all of the lines are here at a
#                     time (except for small documents).
# .fractus-scroller - Because the lines are buffered (so not all N line
#                     elements are in the DOM at once), this element
#                     is given the actual height of all these lines
#                     so that the editor has a scrollbar.
# .fractus-gutter   - Container for the line numbers. Note that line numbering
#                     is buffered along with the lines.
# 
# Events:
# 
#   * focus
#   * blur
# 
class View extends EventEmitter
  @sizeOf: char
  
  # Public: Initialize a View.
  # 
  # $el       - The element to be used as the editor's root.
  # buffer    - A Buffer.
  # cursor    - A Cursor.
  # renderRow - A function which receives the row index to be rendered,
  #             and returns the HTML of that row.
  # options   - scrollwheel, font-family, font-size
  # 
  constructor: (@$el, @buffer, @layout, @cursor, options) ->
    {@scrollwheel} = options
    # TODO: calculate the values dynamically
    charSize    = char()
    @colWidth   = charSize.width
    @lineHeight = charSize.height
    @cursorView = new CursorView this, @cursor
    @input      = new Input()
    
    # Setup the editor DOM.
    @$el.addClass("fractus")
      .append(@input.$el)
      .append(@$scrollView = $("<div/>", class: "fractus-scrollview"))
      .append(@$lines      = $("<ul/>",  class: "fractus-lines"))
      .append(@$gutter     = $("<div/>", class: "fractus-gutter"))
    # Set up the scroll.
    @$yScroller  = $ "<div/>", class: "fractus-scroller-y" 
    #@$yScrollBar = $ "<div/>", class: "fractus-scrollbar-y"
    @$scrollView.append @$yScroller
    @$scrollView.append @cursorView.$el
    @onResize()
    
    # ==== Layout events ====
    @layout.on "scrollY", (scrollTop) =>
      @$scrollView.scrollTop scrollTop
    @layout.on "render",             (html) => @onRender html
    @layout.on "render:line:change", (data) => @onLineChange data
    @layout.on "render:line:insert", (data) => @onLineInsert data
    @layout.on "render:line:delete", (data) => @onLineDelete data
    @layout.on "gutter:renumber", (range) =>
      @updateLineNumbers range.begin, range.end
    @layout.on "gutter:resize", (width) =>
      @resizeGutter width
    @layout.on "change:height", (height) =>
      @$yScroller.height height
    #@layout.on "change:width", =>
    #  @$xScroller.width @$lines.width()
    
    # ==== UI events ====
    #@$el.on "scroll",        (event) => @onScroll event
    @$el.on "mousewheel",    (event) => @onMousewheel event
    @$lines.on "mousedown",  (event) => @onMousedown event
    @$lines.on "mousemove",  (event) => @onMousemove event
    @$lines.on "mouseup",    (event) => @onMouseup event
    
    @$scrollView.on "scroll", (event) => @onScrollbar event
    
    ignoreClicks = ".fractus-selection, .hi-emphasize, .hi-search"
    @$el.on "mousedown",  ignoreClicks, (event) => @onMousedown event
    @$el.on "mousemove",  ignoreClicks, (event) => @onMousemove event
    @$el.on "mouseup",    ignoreClicks, (event) => @onMouseup event
    
    $("body").on "mouseup", => @dragging = false; return
    
    # ==== Clipboard events ====
    @input.on "copy",  (event) => @onCopy  event
    @input.on "cut",   (event) => @onCut   event
    @input.on "paste", (event) => @onPaste event
    
    @layout.ready()
    @onScroll()
    @cursorView.onMove()
    @focus()
    
    @input.$el.on "focus", => @emit "focus"
    @input.$el.on "blur",  => @emit "blur"
  
  # Public: Focus the editor.
  focus: ->
    @emit "focus"
    # Prevent the editor from scrolling to zero on focus.
    @layout.lockScroll()
    @input.focus()
    _.defer => @layout.unlockScroll()
  
  # Internal: Reposition the components of the editor.
  onResize: ->
    @layout.setHeight @$lines.height()
    @layout.setWidth @$lines.width()
  
  # Internal: Snap the scroll to the nearest row.
  onScroll: (event) ->
    # Scroll top/bottom.
    ###newScroll  = @$el.scrollTop() + 1
    if @layout.scrollLock
      @$el.scrollTop @scrollTop
      return false
    return false if newScroll == @scrollTop - 1
    @scrollTop = newScroll
    row        = Math.floor @scrollTop / @layout.sizeOf().height
    
    # Update the gutter and lines.
    coords = {top: @scrollTop - 1}
    @$gutter.css coords
    @$lines.css  coords
    
    # Oh, snap ???
    #@$el.scrollTop row * @layout.sizeOf().height
    @layout.scrollTo row###
    return true
  
  # Internal: Scroll when the scroll bar is spun.
  onMousewheel: (event) ->
    {wheelDelta} = event.originalEvent
    mod          = if wheelDelta < 1 then -1 else 1
    @layout.scrollTo @layout.topRow - mod*@scrollwheel
  
  # Internal: Called when the `$scrollView` scrolls.
  onScrollbar: (event) ->
    newScroll = @$scrollView.scrollTop()
    row       = Math.floor newScroll / @layout.sizeOf().height
    @layout.scrollTo row
    @$scrollView.scrollTop @layout.scrollTop(row)
  
  # ---------------------
  # Click events
  # ---------------------
  
  # Internal: Call the appropriate on<n>Click function.
  onMousedown: (event) ->
    return unless event.button == 0
    point      = @eventToPoint event
    point.round()
    @clickType = @multiClick point
    @dragging  = true
    switch @clickType
      when 1 then @on1Click point, event.shiftKey
      when 2 then @on2Click point, event.shiftKey
      when 3 then @on3Click point, event.shiftKey
    return false
  
  # Internal: (single click) Place the cursor and begin dragging.
  on1Click: (point, shift) ->
    @buffer.commitTransaction()
    @focus()
    # Select to the point.
    if shift
      @cursor.selectTo point
    else
      @cursorView.clearSelection()
      @cursor.moveTo point
  
  # Internal: (double click) Select the word
  on2Click: (point, shift) ->
    @anchorWord = @buffer.wordAt point
    @cursor.select @anchorWord
  
  # Internal: (triple click) Select the line.
  on3Click: (point, shift) ->
    {row}     = point
    @beginRow = row
    @cursor.selectRow row
  
  # Drag the cursor around.
  onMousemove: (event) ->
    return unless @dragging
    point = @eventToPoint event
    point.round()
    switch @clickType
      when 1 then @cursor.selectTo point
      when 2
        toWord = @buffer.wordAt(point)
        break unless toWord
        if toWord.end.isBefore @cursor.region.ordered().end
          @cursor.region.end.moveTo toWord.begin
          @cursor.region.begin.moveTo @anchorWord.end
        else if @cursor.region.ordered().begin.isBefore toWord.begin
          @cursor.region.begin.moveTo @anchorWord.begin
          @cursor.region.end.moveTo toWord.end
      when 3 then @cursor.selectRows @beginRow, point.row
    return false
  
  onMouseup: (event) ->
  
  
  # Internal: Keep track of single vs double vs triple clicks.
  # 
  # point - The Point that was clicked.
  # 
  # Returns Integer, the nth click. Single click is `1`, double click
  # is `2`, etc.
  multiClick: (point) ->
    {row, col} = point
    @_multi or= 0
    @_multi++
    # Double clicking on a different position doesn't count.
    if @_multiRow != row or @_multiCol != col
      @_multiRow = row
      @_multiCol = col
      @_multi    = 1
    setTimeout =>
      @_multi--
    , 500
    @_multi = 1 if @_multi > 3
    return @_multi
  
  # -------------------------------------------------------------------------
  
  # Integer: Render the line numbers, beginning with `row`.
  # The row is 0-based, but when displayed the line numbers are 1-based.
  # 
  # row - The index of the line.
  # 
  # Returns nothing.
  updateLineNumbers: _.debounce (beginRow, endRow) ->
    # When displayed, line numbers begin at 1 instead of 0.
    rows = [(beginRow + 1)..(endRow + 1)]
    html = "<span>#{ rows.join("</span><span>") }</span>"
    @$gutter.html html
    @highlightCurrentLines()
  , 10
  
  # Internal: Update the width of the gutter.
  # 
  # Returns nothing.
  resizeGutter: _.debounce (width) ->
    @$gutter.width width
    @$lines.css {left: width}
  , 100
  
  # Internal: Highlight the row numbers that currently have a cursor or
  # selection in their line.
  # 
  # Returns nothing.
  highlightCurrentLines: ->
    @clearCurrentLines()
    if @cursor.point
      {row} = @cursor.point
      @currentLine row
    else if @cursor.region
      {begin, end} = @cursor.region.ordered()
      if begin.row == end.row
        @currentLine begin.row
      else
        @currentLine begin.row, "current-top"
        @currentLine end.row, "current-bottom"
        for row in [(begin.row)..(end.row)]
          @currentLine row, "current-middle"
  
  # Internal: Highlight the given row as a current row.
  # 
  # row  - 
  # type - "current" (default), "current-top",
  #        "current-bottom", or "current-middle"
  # 
  # Returns nothing.
  currentLine: (row, type="current") ->
    @rowToGutterEl(row)?.addClass type
  
  # Internal: Unmark the current lines.
  clearCurrentLines: ->
    @$gutter.children(".current-top, .current-middle, .current-bottom, .current")
      .removeClass "current-top current-middle current-bottom current"
  
  # -----------------
  # Buffer events
  # -----------------
  onLineChange: (data) ->
    {row, html} = data
    @rowToEl(row).replaceWith html
  
  onLineInsert: (data) ->
    {row, html} = data
    if row > 0
      @rowToEl(row - 1).after html
    else
      @rowToEl(0).before html
  
  onLineDelete: (data) ->
    {row, html} = data
    @rowToEl(row).remove()
    @$lines.append html if html
  
  onRender: (html) ->
    @$lines.html html
  
  
  # Get the row's line element.
  # 
  # row - A 0-indexed row index.
  # 
  # Return a jQuery element, or `null` if it is not in the visible portion
  # of the buffer.
  rowToEl: (row) ->
    rowIndex = row - @layout.topRow + 1
    $line    = @$lines.children ":nth-child(#{rowIndex})"
    return if $line.length then $line else null
  
  # Get the line number from the gutter corresponding to the row.
  # 
  # row - A 0-indexed row index.
  # 
  # Return a jQuery element or `null` if that line number is not visible.
  rowToGutterEl: (row) ->
    return null unless row?
    rowIndex = row - @layout.topRow + 1
    $num     = @$gutter.children "span:nth-child(#{rowIndex})"
    return if $num.length then $num else null
  
  # -----------------
  # Clipboard stuff
  # -----------------
  onCopy: ->
    @buffer.commitTransaction()
    @input.setText @cursor.text()
    return true
  
  onCut: ->
    @buffer.commitTransaction()
    @input.setText @cursor.text()
    @cursor.deleteSelection()
    return true
  
  onPaste: (event) ->
    @buffer.commitTransaction()
    clipboardText = event.originalEvent.clipboardData.getData "text/plain"
    # TODO: Lock & unlock is a hack... for some reason the scroll jumps up when you paste.
    @layout.lockScroll()
    @cursor.insert clipboardText
    setTimeout =>
      @layout.unlockScroll()
    , 50
  
  # Use the event's coordinates to determine the closest point.
  # 
  # event - A jQuery normalized event object.
  # 
  # Return an instance of Point.
  eventToPoint: (event) ->
    offsetX = event.pageX - @$lines.offset().left
    offsetY = event.pageY - @$lines.offset().top
    return @layout.coordsToPoint offsetY, offsetX


class CursorView
  constructor: (@view, @cursor) ->
    {@layout} = @view
    @$el      = $ "<div/>", class: "fractus-cursor"
    @$el.height @view.lineHeight
    @cursor.on "move", => @onMove()
  
  onMove: ->
    @clearSelection()
    
    # A cursor.
    if @cursor.point
      [top, left] = @layout.pointToCoords @cursor.point
      @$el.css {top, left}
    # A selection.
    else
      @renderSelection()
      [top, left] = @layout.pointToCoords @cursor.region.end
      @$el.css {top, left}
    @view.highlightCurrentLines()
    
    setTimeout =>
      @scrollTo()
    , 0
  
  # Scroll the editor to make the cursor visible.
  scrollTo: ->
    point = @cursor.point || @cursor.region.end
    # Too far down
    if @layout.isTooFarDown point
      @layout.scrollBottom point.row
    # Too far up
    else if @layout.isTooFarUp point
      @layout.scrollTo point.row
  
  renderSelection: ->
    {begin, end} = @cursor.region.ordered()
    return unless @rect1 begin, end
    return unless @rect3 begin, end
    @rect2 begin, end
    
  $rect: ->
    return $ "<div/>", class: "fractus-selection"
  
  rect1: (begin, end) ->
    @$rect1     = @$rect()
    [top, left] = @layout.pointToCoords begin
    @$rect1.appendTo(@view.$scrollView).css
      height: @view.lineHeight
      top:    top
      left:   left
    if begin.row == end.row
      [___, endLeft] = @layout.pointToCoords end
      @$rect1.css width: endLeft - left
      return false
    else
      @$rect1.css right: 0
      return true
    
  rect2: (begin, end) ->
    @$rect2  =  @$rect()
    [beginTop, beginLeft] = @layout.pointToCoords begin
    [endTop,   endLeft]   = @layout.pointToCoords end
    @$rect2.appendTo(@view.$scrollView).css
      top:    beginTop + @view.lineHeight
      left:   @view.$gutter.width()
      right:  0
      height: endTop - beginTop - @view.lineHeight
  
  rect3: (begin, end) ->
    @$rect3     = @$rect()
    [top, left] = @layout.pointToCoords end
    @$rect3.appendTo(@view.$scrollView).css
      top:   top
      width: left - @view.$gutter.width()
      left:  @view.$gutter.width()
    if begin.row + 1 == end.row
      @$rect3.css height: @view.lineHeight
      return false
    else
      return true
  
  clearSelection: ->
    @$rect1?.remove()
    @$rect3?.remove()
    @$rect2?.remove()


# Whenever the editor is focused, the user's focus is actually in this
# textarea. This way, cut/copy/paste can all be simulated (since
# the browser does give JavaScript direct access to these APIs).
# 
# The textarea is kept offscreen, so it is never seen by the user.
# However, it cannot be given styles `display: none;` or `visibility: hidden;`,
# because for some reason (at least in Chromium 15.0.874.106 on Ubuntu 10.04)
# this prevents the "copy", "cut", or "paste" events from firing.
# 
# Events:
# copy  -
# cut   -
# paste -
class Input extends EventEmitter
  constructor: ->
    @$el = $ "<textarea></textarea>"
    keyboard.focus @$el, "fractus"
    @$el.on "copy",  (event) => @emit "copy",  event
    @$el.on "cut",   (event) => @emit "cut",   event
    @$el.on "paste", (event) => @emit "paste", event
  
  focus: -> @$el.focus()
  
  setText: (text) ->
    @$el.val text
    @$el[0].select()

module.exports = {View}
