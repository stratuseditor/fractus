###
Vocab:
* `row` - the 0-based index of a line.
* `col` - the 0-based index of a column.

Keeping points synchronized
* when text is inserted at point A
  - point B must be moved down (if A contains newlines)
  - point B must be moved right (if A is on the same line)
* when text is deleted forward at A
  - point B is moved up (if !same line and line was joined)
  - point B is moved left (if on same line)
* when text is deleted backward at A
  - point B is moved up (if !same line and line was joined)
  - point B is moved left (if on same line)


###

{EventEmitter} = require 'events'

# Events:
# line:change - {row, text}
# line:insert - {row, text}
# line:delete - {row}
# reset       - {}
class Buffer extends EventEmitter
  # 
  # text        - The initial text of the Buffer (String).
  # saveCursor  - A function which should return some cursor data.
  # placeCursor - A function which is passed the cursor data to
  #               restore the position.
  constructor: (text, @saveCursor=null, @placeCursor=null) ->
    @lines        = [""]
    # Eliminate the Windows line-endings.
    @setText text.replace(/\r/g, "")
    @undoStack    = []
    @redoStack    = []
    @currentSteps = []
  
  # Public: Create a point on this Buffer.
  # 
  # row    -
  # col    -
  # anchor - (optional).
  # 
  # Return an instance of Point.
  point: (row, col, anchor) ->
    return new Point this, row, col, anchor
  
  # Public: Get the text of the whole editor, a line, or a character.
  # 
  # row - Fetch a line of text (optional).
  # col - Fetch a character from the text. If given, `row` must
  #       also be specified (optional).
  # 
  # Examples
  # 
  #   buffer.text()
  #   # => "Hello,\nworld"
  # 
  #   buffer.text 0
  #   # => "Hello,"
  # 
  #   buffer.text 0, 0
  #   # => "H"
  # 
  # Returns string.
  text: (row=null, col=null) ->
    if row? && col?
      return @lines[row]?[col]
    else if row?
      return @lines[row]
    else
      return @lines.join "\n"
  
  # Public: Get the number of lines.
  # Always >=1.
  # 
  # Examples
  # 
  #   buffer.lineCount()
  #   # => 2
  # 
  # Return integer.
  lineCount: ->
    return @lines.length
  
  # Public: Get the length of the given row.
  # Always >= 0
  # 
  # row -
  # 
  # Examples
  # 
  #   buffer.lineLength 0
  #   # => 6
  # 
  # Return integer.
  lineLength: (row) ->
    throw new Error "Buffer#lineLength() needs a row number" unless row?
    return @text(row)?.length
  
  # Public: Search for a sub-string within the document text.
  # The text searched for cannot span multiple lines.
  # Also, the search does not wrap around.
  # 
  # text     - The string sub-text to search for, or a regular expression.
  # startRow - A row to begin searching from (optional).
  # startCol - A column to begin searching from (optional).
  # 
  # Examples
  # 
  #   buffer.search "world"
  #   # => #<Region>
  # 
  #   buffer.search "green eggs & ham"
  #   # => null
  # 
  #   buffer.search /hello/i
  #   # => #<Region>
  # 
  # Return an instance of Region is a match is found, otherwise null.
  search: (match, startRow=0, startCol=0) ->
    if match instanceof RegExp
      return @searchRegex match, startRow, startCol
    else
      return @searchText match, startRow, startCol
  
  # Internal: Search for a String.
  # 
  # Returns Region or `null`.
  searchText: (subText, startRow, startCol) ->
    text   = @text(startRow).substr startCol
    maxRow = @lineCount()
    while startRow < maxRow
      result = text.indexOf subText
      if ~result
        {length} = subText
        begin    = @point startRow, startCol + result
        end      = @point startRow, startCol + result + length
        return new Region begin, end
      startCol = 0
      text     = @text ++startRow
    return null
  
  # Internal: Search for a RegExp.
  # 
  # Returns Region or `null`. The region has an additional
  # `captures` property.
  searchRegex: (regex, startRow, startCol) ->
    text   = @text(startRow).substr startCol
    maxRow = @lineCount()
    while startRow < maxRow
      result = regex.exec text
      if result
        {length} = result[0]
        {index}  = result
        begin    = @point startRow, startCol + index
        end      = @point startRow, startCol + index + length
        region   = new Region begin, end
        region.captures = result
        return region
      startCol = 0
      text     = @text ++startRow
    return null
  
  
  # Public: Find all instances of the search term, beginning the search
  # at (0, 0).
  # 
  # match - A String or RegExp.
  # 
  # Returns an Array of Region.
  searchAll: (match) ->
    regions = []
    row     = 0
    col     = 0
    while region = @search(match, row, col)
      regions.push region
      row = region.end.row
      col = region.end.col
    return regions
  
  
  # Replace the first instance in the document of `text` with `newText`.
  # The same restrictions apply as for Buffer#search.
  # 
  # text     - The string sub-text to search for, or a regular expression.
  # newText  - The replacement text. If `text` was a RegExp, substitutions
  #            are done with $0, $1.. $0 is the matched text. $1.. are the
  #            captures.
  # startRow - A row to begin searching from (optional).
  # startCol - A column to begin searching from (optional).
  # 
  # Examples
  # 
  #   buffer.replace "Hello", "Hello!"
  #   # => #<Region>
  # 
  #   buffer.replace /hello/i, "$0!"
  #   # => #<Region>
  # 
  # Return an instance of Region, where the replacement is.
  # Return `null` if no replacement is made.
  replace: (match, newText, startRow=0, startCol=0) ->
    matchRegion = @search match, startRow, startCol
    return null if !matchRegion
    if matchRegion.captures
      for capture, i in matchRegion.captures
        newText = newText.replace (new RegExp("[$]#{i}", "g")), capture
    matchRegion.replaceWith newText
    return matchRegion
  
  # Same as Buffer#replace, but replaces all occurences (beginning
  # at `startRow` and `startCol`).
  # 
  # Examples
  # 
  #   buffer.setText "! ! ! !"
  #   buffer.replaceAll "!", "."
  #   # => 4
  #   buffer.text()
  #   # => ". . . ."
  # 
  # Returns Integer: the number of replacements made.
  replaceAll: (match, newText, startRow=0, startCol=0) ->
    replacementCount = 0
    while matchRegion = @replace(match, newText, startRow, startCol)
      startRow = matchRegion.end.row
      startCol = matchRegion.end.col
      replacementCount++
    return replacementCount
  
  # Public: Delete the given line.
  # 
  # row -
  # 
  # Examples
  # 
  #   buffer.deleteLine 0
  #   # => "Hello,"
  #   
  #   buffer.text()
  #   # => "world"
  # 
  # Return string: the contents of the line deleted.
  deleteLine: (row) ->
    line = @text row
    if row == 0 && @lineCount() == 1
      @setLine 0, ""
    else
      @lines.splice row, 1
      
      unless @noHistory
        @currentSteps.push
          type:    "delete"
          row:     row
          oldText: line
      
      @emit "line:delete", {row}
    return line
  
  # Public: Set the text of the given line.
  # 
  # row  -
  # text - The new text of the line (String).
  # 
  # Examples
  # 
  #   buffer.setLine 0, "See ya,"
  #   
  #   buffer.text()
  #   # => "See ya,\nworld"
  # 
  setLine: (row, text) ->
    oldText     = @text row
    @lines[row] = text
    
    unless @noHistory
      @currentSteps.push
        type:    "change"
        row:     row
        oldText: oldText
        newText: text
    
    @emit "line:change", {row, text}
    return
  
  # Public: Create a new line and place it at `row`, moving the old
  # `row` and everything after down one.
  # 
  # row  -
  # text -
  # 
  # Examples
  # 
  #   buffer.insertLine 2, "Good bye"
  #   buffer.text()
  #   # => "Hello,\nworld\nGood bye"
  # 
  insertLine: (row, text) ->
    @lines.splice row, 0, text
    
    unless @noHistory
      @currentSteps.push
        type:    "insert"
        row:     row
        newText: text
    
    @emit "line:insert", {row, text}
    return
  
  # Public: Reset the text of the editor and replace it with the
  # given string.
  # 
  # text - The new editor text.
  # 
  # Examples
  # 
  #   buffer.setText "Good day, sir!"
  #   buffer.text()
  #   # => "Good day, sir!"
  # 
  setText: (text) ->
    @lines = text.split "\n"
    @emit "reset"
  
  # Public: Step back.
  undo: ->
    @commitTransaction()
    steps = @undoStack.pop()
    return unless steps
    @redoStack.push steps
    
    @noHistory = true
    for step in steps.slice().reverse()
      switch step.type
        when "change"
          @setLine step.row, step.oldText
        when "delete"
          @insertLine step.row, step.oldText
        when "insert"
          @deleteLine step.row
    
    # Reposition the cursor.
    if (prev = @undoStack[@undoStack.length - 1]) && prev.cursor
      @placeCursor prev.cursor
    
    @noHistory = false
  
  # Public: Step forward.
  redo: ->
    steps = @redoStack.pop()
    return unless steps
    @undoStack.push steps
    
    @noHistory = true
    for step in steps.slice()
      switch step.type
        when "change"
          @setLine step.row, step.newText
        when "delete"
          @deleteLine step.row
        when "insert"
          @insertLine step.row, step.newText
    @placeCursor steps.cursor if steps.cursor
    @noHistory = false
  
  # Public: Mark the end of an undo group.
  commitTransaction: ->
    return unless @currentSteps.length
    @currentSteps.cursor = @saveCursor() if @saveCursor
    @undoStack.push @currentSteps
    @currentSteps = []
  
  # Public: Insert `text` at the given row and column.
  # 
  # text -
  # row  -
  # col  -
  # 
  # Examples
  # 
  #   buffer.insert "CHEESE", 0, 0
  #   # => #<Point>
  #   buffer.text()
  #   # => "CHEESEHello,\nworld"
  # 
  #   buffer.insert "CHEESE\nis the best", 0, 0
  #   #<Point>
  #   buffer.text()
  #   # => "CHEESE\nis the bestHello,\nworld"
  # 
  # Return an instance of Point that points to the end of the inserted text.
  insert: (text, row, col) ->
    line       = @text row
    textBefore = line.substr 0, col
    textAfter  = line.substr col
    
    # Single line
    if !~text.indexOf("\n")
      @setLine row, textBefore + text + textAfter
      return @point row, textBefore.length + text.length
    # Multiple lines
    else
      insertedLines     = text.split "\n"
      insertedLineCount = insertedLines.length
      @setLine row, textBefore + insertedLines[0]
      for line, i in insertedLines[1..-2]
        @insertLine row + i + 1, line
      
      lastRow  = row + insertedLineCount - 1
      lastLine = insertedLines[insertedLineCount - 1]
      @insertLine lastRow, lastLine + textAfter
      return @point lastRow, lastLine.length
  
  # Public: Overwrite the text beginning at the given position.
  # This does *not* handle newlines in `text`.
  # 
  # text -
  # row  -
  # col  -
  # 
  # Examples
  # 
  #   buffer.overwrite "CHEESE!", 0, 0
  #   # => #<Point>
  #   buffer.text()
  #   # => "CHEESE!\nworld"
  # 
  overwrite: (text, row, col) ->
    line       = @text row
    textBefore = line.substr 0, col
    textAfter  = line.substr col + text.length
    @setLine row, textBefore + text + textAfter
    return @point row, textBefore.length + text.length
  
  
  # Public: Split the given row into 2 rows at the given column.
  # 
  # row -
  # col -
  # 
  # Examples
  # 
  #   buffer.insertNewLine 0, 1
  #   buffer.text()
  #   # => "H\nello,\nworld"
  # 
  insertNewLine: (row, col) ->
    line       = @text row
    textBefore = line.substr 0, col
    textAfter  = line.substr col
    @setLine row, textBefore
    @insertLine row + 1, textAfter
  
  # Public: Join the given row with the next.
  # 
  # row -
  # 
  joinLines: (row) ->
    line  = @text row
    line2 = @text row + 1
    @setLine row, line + line2
    @deleteLine row + 1
  
  
  # Public: Get the word at the given position.
  # 
  # Also accepts a point as the first argument.
  # 
  # row    -
  # col    -
  # wordRe - A string that will be converted to a regexp which matches
  #          a word (optional).
  # 
  # Examples
  # 
  #   buffer.setText "Hello,\nworld"
  #   region = buffer.wordAt 0, 2
  #   # #<Region
  #   #   begin:
  #   #     row: 0
  #   #     col: 0
  #   #   end:
  #   #     row: 0
  #   #     col: 5
  #   #   isSolid: true
  #   # >
  # 
  # Return an instance of Region with an additional
  # boolean property: `isSolid`.
  wordAt: (row, col, wordRe="\\w+") ->
    {row, col} = row if row instanceof Point
    line       = @text row
    regex      = new RegExp "(#{wordRe})|(.)", "g"
    isNext     = false
    # "(Hello)( )|(world)"
    # col = 6
    while match = regex.exec line
      text     = match[1] || match[2]
      {index}  = match
      {length} = text
      if isNext || (col <= index + length)
        region = new Region @point(row, index),
                            @point(row, index + length)
        region.isSolid = !!match[1]
        if !isNext && !region.isSolid && index + 1 != line.length
          isNext = true
          continue
        return region
    return new Region @point(row, col), @point(row, col)
  
  # Public: Shift the given range of lines up one.
  # 
  # Examples
  # 
  #   b = new Buffer "0123456789".split("").join("\n")
  #   b.shiftLinesUp 3, 5
  #   # => true
  #   b.text()
  #   # => == "0134526789".split("").join("\n")
  # 
  # Return Boolean: whether or not the lines were moved.
  shiftLinesUp: (beginRow, endRow) ->
    return false unless beginRow
    prevLine = @deleteLine beginRow - 1
    @insertLine endRow, prevLine
    return true
  
  # Public: Shift the given range of lines down one.
  # 
  # Examples
  # 
  #   b = new Buffer "0123456789".split("").join("\n")
  #   b.shiftLinesDown 3, 5
  #   # => true
  #   b.text()
  #   # => == "0126345789".split("").join("\n")
  # 
  # Return Boolean: whether or not the lines were moved.
  shiftLinesDown: (beginRow, endRow) ->
    return false if endRow == @lineCount() - 1
    nextLine = @deleteLine endRow + 1
    @insertLine beginRow, nextLine
    return true
  
  # Public: Delete all of the rows from `beginRow` to `endRow`, inclusive.
  # 
  # Examples
  # 
  #   b = new Buffer "0123456789".split("").join("\n")
  #   b.deleteLines 1, 5
  #   # => == "06789".split("").join("\n")
  # 
  deleteLines: (beginRow, endRow) ->
    for i in [beginRow..endRow]
      @deleteLine beginRow
    return


# Events:
# * move
class Point extends EventEmitter
  constructor: (@buffer, @row, @col, @anchor=true) ->
  
  # Public: Set the row and column of the Point.
  # 
  # Alternatively, you can pass a Point as the argument.
  # 
  # If values of `null` or `undefined` are passed, that value will not
  # be updated.
  # 
  # Examples
  # 
  #   pt = buffer.point 0, 2
  #   
  #   pt.moveTo 3, 4
  #   pt.row
  #   # => 3
  #   pt.col
  #   # => 4
  #   
  #   pt.moveTo null, 10
  #   pt.row
  #   # => 3
  #   pt.col
  #   # => 10
  #   
  #   pt2 = buffer.point 10, 100
  #   pt.moveTo pt2
  #   pt.row
  #   # => 10
  #   pt.col
  #   # => 100
  # 
  # Returns nothing.
  moveTo: (row, col) ->
    if row instanceof Point
      @row = row.row
      @col = row.col
      @emit "move"
    else
      @row = row if row?
      @col = col if col?
      @emit "move"
  
  # Public: Get whether or not this Point and `point` are at the same
  # row and column.
  # 
  # Examples
  # 
  #   p1 = buffer.point 1, 2
  #   p2 = buffer.point 2, 2
  #   p1.equals p2
  #   # => false
  #   
  #   p3 = buffer.point 1, 2
  #   p1.equals p3
  #   # => true
  # 
  # Return boolean.
  equals: (point) ->
    return @row == point.row && @col == point.col
  
  # Public: Get whether or not this Point is before `point` in the document.
  # 
  #   pt  = buffer.point 0, 2
  #   pt2 = buffer.point 1, 3
  #   pt.isBefore pt2
  #   # => true
  #   
  #   pt2.isBefore bt
  #   # => false
  # 
  # Returns Boolean.
  isBefore: (point) ->
    sameRow = @row == point.row
    return @row < point.row || (sameRow && @col < point.col)
  
  # Public: Whether or not the given `point` is after this point.
  # 
  # Returns Boolean.
  isAfter: (point) ->
    return !@isBefore(point) && !@equals(point)
  
  # Public: Get a point with the same properties.
  # 
  # Returns Point.
  clone: ->
    return new Point @buffer, @row, @col, @anchor
  
  # Public: Get a pretty-printable representation of the point.
  # 
  # Examples
  # 
  #   pt = buffer.point 1, 3
  #   pt.toString()
  #   # => "(1, 3)"
  # 
  # Returns String.
  toString: ->
    return "(#{@row}, #{@col})"
  
  # Public: Move the point to the closest actual location on the buffer.
  # 
  # Examples
  # 
  #   buffer = new Buffer "Hello\nworld"
  #   point  = buffer.point 0, 1000000
  #   point.round()
  #   
  #   point.row
  #   # => 0
  #   point.col
  #   # => 5
  # 
  # Returns nothing.
  round: ->
    newRow  = null
    newCol  = null
    lastRow = @buffer.lineCount() - 1
    lastCol = @buffer.lineLength @row
    newRow  = 0 if @row < 0
    newCol  = 0 if @col < 0
    if @row > lastRow
      newRow = lastRow
    if @col > lastCol
      newCol = lastCol
    @moveTo newRow, newCol if newRow? || newCol?
  
  # Public: Find the point in the buffer just previous to this one.
  # 
  # To visualize it, imagine placing your cursor in the buffer
  # and pressing the left arrow key.
  # 
  # Return an instance of Point.
  prevLoc: ->
    if @col == 0
      if @row == 0
        return @buffer.point 0, 0
      else
        return @buffer.point @row - 1, @buffer.lineLength(@row - 1)
    else
      return @buffer.point @row, @col - 1
  
  # Public: Find the point in the buffer just after to this one.
  # 
  # To visualize it, imagine placing your cursor in the buffer
  # and pressing the right arrow key.
  # 
  # Return an instance of Point.
  nextLoc: ->
    if @col == @buffer.lineLength(@row)
      if @row == @buffer.lineCount() - 1
        return @buffer.point @row, @col
      else
        return @buffer.point @row + 1, 0
    else
      return @buffer.point @row, @col + 1
  
  # Public: Move the column of the point to the beginning of its line.
  moveToLineBegin: ->
    @idealCol = 0
    @moveTo null, 0
  
  # Public: Move the column of the point to the end of its line.
  moveToLineEnd: ->
    @idealCol = 0
    @moveTo null, @buffer.lineLength(@row)
  
  # Public: Arrow key left.
  moveLeft: ->
    return if @isAtDocBegin()
    @idealCol = 0
    if @col == 0
      @moveTo @row - 1, @buffer.lineLength(@row - 1) if @row
    else
      @moveTo null, @col - 1
  
  # Public: Arrow key right.
  moveRight: ->
    return if @isAtDocEnd()
    @idealCol = 0
    if @col == @buffer.lineLength(@row)
      @moveTo @row + 1, 0 if @row < @buffer.lineCount()
    else
      @moveTo null, @col + 1
  
  # Public: Arrow key down.
  moveDown: ->
    if @isAtLastLine()
      @moveToLineEnd()
    else
      @moveVertical 1
  
  # Public: Arrow key up.
  moveUp: ->
    if @row == 0
      @moveToLineBegin()
    else
      @moveVertical -1
  
  # Public: Translate the point vertically.
  moveVertical: (amount) ->
    if !@idealCol || @col >= @idealCol
      @idealCol = @col
    
    newRow = @row + amount
    newCol = @col
    if @idealCol > @col
      newCol = @idealCol
    if @col > (limit = @buffer.lineLength(newRow))
      newCol = limit
    @moveTo newRow, newCol
  
  # Public: Move the point to the beginning of the previous word.
  moveToPrevWord: ->
    return if @isAtDocBegin()
    carat = @prevLoc()
    char  = @buffer.text carat.row, carat.col
    while !char || !/\w/.test(char)
      carat = carat.prevLoc()
      return @moveToDocBegin() if carat.isAtDocBegin()
      char  = @buffer.text carat.row, carat.col
    
    @moveTo @buffer.wordAt(carat).begin
  
  # Public: Move the point to the end of the next word.
  moveToNextWord: ->
    return if @isAtDocEnd()
    carat = @clone()
    char  = @buffer.text carat.row, carat.col
    while !char || !/\w/.test(char)
      carat = carat.nextLoc()
      return @moveToDocEnd() if carat.isAtDocEnd()
      # Wrap around at the end of a line.
      carat = carat.nextLoc() if carat.isAtLineEnd()
      char  = @buffer.text carat.row, carat.col
    
    carat.moveRight()
    @moveTo @buffer.wordAt(carat).end
  
  # Public: Move the point to the start of the document, (0, 0).
  moveToDocBegin: ->
    @moveTo 0, 0
  
  # Public: Move the point to the last column of the last row
  # of the document.
  moveToDocEnd: ->
    lastRow = @buffer.lineCount() - 1
    @moveTo lastRow, @buffer.lineLength(lastRow)
  
  isAtDocBegin: ->
    return !@row and !@col
  
  isAtDocEnd: ->
    lastRow = @buffer.lineCount() - 1
    return @row == lastRow and @col == @buffer.lineLength(lastRow)
  
  isAtLineEnd: ->
    return @col == @buffer.lineLength(@row)
  
  isAtLastLine: ->
    lastRow = @buffer.lineCount() - 1
    return @row == lastRow
  
  # Public: Insert text from the cursor position, and move it to the end.
  insert: (text) ->
    @moveTo @buffer.insert(text, @row, @col)
  
  # Public: Overwrite text from the cursor position, and move it to the end.
  overwrite: (text) ->
    @moveTo @buffer.overwrite(text, @row, @col)
  
  # Public: Backspace.
  deleteBack: ->
    return if @isAtDocBegin()
    {row, col} = this
    @moveLeft()
    if col == 0
      @buffer.joinLines row - 1
    else
      line = @buffer.text row
      @buffer.setLine row, line.substr(0, col - 1) + line.substr(col)
  
  # Public: Delete forward a character.
  deleteForward: ->
    return if @isAtDocEnd()
    if @isAtLineEnd()
      @buffer.joinLines @row
    else
      line = @buffer.text @row
      @buffer.setLine @row, line.substr(0, @col) + line.substr(@col + 1)
  
  # Public: Delete backward until a /[^\w][\w]/ barrier is hit.
  deleteWordBack: ->
    rowBegin = @row
    colBegin = @col
    @moveToPrevWord()
    
    ptBegin = @buffer.point @row, @col
    ptEnd   = @buffer.point rowBegin, colBegin
    (new Region ptBegin, ptEnd).delete()
  
  # Public: Delete forward until a /[\w][^\w]/ barrier is hit.
  deleteWordForward: ->
    rowBegin = @row
    colBegin = @col
    @moveToNextWord()
    
    ptBegin = @buffer.point rowBegin, colBegin
    (new Region ptBegin, this).delete()
  
  # Public: Create a newline at the point (like hitting enter).
  newLine: ->
    @buffer.insertNewLine @row, @col
    @moveTo @row + 1, 0


class Region
  constructor: (@begin, @end) ->
    {@buffer} = @begin
  
  # Public: Get a region where the begin and end points are in order.
  # (They may be already, but this ensures it).
  # 
  # Return an instance of Region.
  ordered: ->
    # Already ordered.
    if @begin.isBefore @end
      return new Region @begin, @end
    else
      return new Region @end, @begin
  
  # Public: Check whether or not `begin` and `end` are the same point.
  isEmpty: ->
    return @begin.equals @end
  
  # Public: Get the string contents of the region.
  # 
  # Return a string.
  text: ->
    {begin, end} = @ordered()
    if begin.row == end.row
      return @buffer.text(begin.row).substring begin.col, end.col
    
    lines = []
    lines.push @buffer.text(begin.row).substring begin.col
    if end.row - 1 >= begin.row + 1
      for row in [(begin.row + 1)..(end.row - 1)]
        lines.push @buffer.text(row)
    
    lines.push @buffer.text(end.row).substring 0, end.col
    return lines.join "\n"
  
  # Public: Replace the contents of the region with some new text.
  # 
  # The end point of the region is updated to surround the new text.
  # 
  # text - String
  # 
  replaceWith: (text) ->
    {begin, end} = @ordered()
    line         = @buffer.text begin.row
    beforeText   = line.substr 0, begin.col
    if begin.row == end.row
      afterText  = line.substr end.col
    else
      lastLine  = @buffer.text(end.row)
      afterText = lastLine.substr end.col
    
    if begin.row != end.row
      delRow = begin.row + 1
      for row in [delRow..(end.row)]
        @buffer.deleteLine delRow
    
    @buffer.setLine begin.row, beforeText
    end.moveTo @buffer.insert(text, begin.row, begin.col)
    @buffer.insert afterText, end.row, end.col
    return
  
  # Public: Delete the range, and update the end point.
  delete: ->
    @replaceWith ""
  
  # Public: Select the given row.
  selectRow: (row) ->
    @selectRows row, row
  
  # Public: Select all of the rows in the range.
  selectRows: (rowBegin, rowEnd) ->
    [rowBegin, rowEnd] = [rowEnd, rowBegin] if rowBegin > rowEnd
    @begin.moveTo rowBegin, 0
    @end.moveTo rowEnd, @buffer.lineLength(rowEnd)
  
  # Public: Shift all of the selected lines up a row.
  shiftLinesUp: ->
    {begin, end} = @ordered()
    return if !@buffer.shiftLinesUp begin.row, end.row
    begin.moveUp()
    end.moveUp()
  
  # Public: Shift all of the selected lines down a row.
  shiftLinesDown: ->
    {begin, end} = @ordered()
    return if !@buffer.shiftLinesDown begin.row, end.row
    begin.moveDown()
    end.moveDown()
  
  # Public: Indent the selected lines.
  indent: (tabChars) ->
    {begin, end} = @ordered()
    for row in [(begin.row)..(end.row)]
      @buffer.setLine row, tabChars + @buffer.text(row)
    begin.moveTo null, begin.col + tabChars.length
    end.moveTo null, end.col + tabChars.length
    return
  
  # Public: Outdent the selected lines (decrease the indentation).
  outdent: (tabChars) ->
    {begin, end} = @ordered()
    re           = new RegExp "^#{ tabChars.replace(/(.)/g, "[$1]?") }"
    changed      = false
    for row in [(begin.row)..(end.row)]
      oldLine = @buffer.text row
      line    = oldLine.replace re, ""
      @buffer.setLine row, line
      changed = true if line != oldLine
    
    return unless changed
    beginCol = begin.col - tabChars.length
    beginCol = 0 if beginCol < 0
    endCol   = end.col - tabChars.length
    endCol   = 0 if endCol < 0
    begin.moveTo null, beginCol
    end.moveTo null, endCol


module.exports = {Buffer, Point, Region}
