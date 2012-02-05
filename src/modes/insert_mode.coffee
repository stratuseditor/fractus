# Insert mode should behave like a standard text editor.
module.exports =
  # Navigation
  Right:           (edt) -> edt.cursor.moveRight(); ct(edt)
  "Control-Right": (edt) -> edt.cursor.moveToNextWord(); ct(edt)
  Up:              (edt) -> edt.cursor.moveUp(); ct(edt)
  Left:            (edt) -> edt.cursor.moveLeft(); ct(edt)
  "Control-Left":  (edt) -> edt.cursor.moveToPrevWord(); ct(edt)
  Down:            (edt) -> edt.cursor.moveDown(); ct(edt)
  Home:            (edt) -> HomeHome(edt); ct(edt)
  End:             (edt) -> edt.cursor.moveToLineEnd();  ct(edt)
  "Control-Home":  (edt) -> edt.cursor.moveToDocBegin(); ct(edt)
  "Control-End":   (edt) -> edt.cursor.moveToDocEnd();   ct(edt)
  PageUp:          (edt) -> edt.cursor.pageUp();   ct(edt)
  PageDown:        (edt) -> edt.cursor.pageDown(); ct(edt)
  
  # Selection
  "Control-a":     (edt) -> edt.cursor.selectAll(); ct(edt)
  "Shift-Right":   (edt) -> edt.cursor.selectRight(); ct(edt)
  "Control-Shift-Right": (edt) -> edt.cursor.selectToNextWord(); ct(edt)
  "Shift-Up":    (edt) -> edt.cursor.selectUp(); ct(edt)
  "Shift-Left":  (edt) -> edt.cursor.selectLeft(); ct(edt)
  "Control-Shift-Left":  (edt) -> edt.cursor.selectToPrevWord(); ct(edt)
  "Shift-Down":  (edt) -> edt.cursor.selectDown(); ct(edt)
  "Shift-Home":  (edt) -> HomeHome(edt, "select"); ct(edt)
  "Shift-End":   (edt) -> edt.cursor.selectToLineEnd(); ct(edt)
  "Control-Shift-Home": (edt) -> edt.cursor.selectToDocBegin(); ct(edt)
  "Control-Shift-End":  (edt) -> edt.cursor.selectToDocEnd(); ct(edt)
  "Shift-PageUp":       (edt) -> #edt.cursor.selectVertical -edt.visibleLineCount(); ct(edt)
  "Shift-PageDown":     (edt) -> #edt.cursor.selectVertical  edt.visibleLineCount(); ct(edt)
  
  # Deletion
  Backspace:           (edt) -> edt.cursor.deleteBack()
  Delete:              (edt) -> edt.cursor.deleteForward()
  "Control-Backspace": (edt) -> edt.cursor.deleteWordBack(); ct(edt)
  "Control-Delete":    (edt) -> edt.cursor.deleteWordForward(); ct(edt)
  "Control-d":         (edt) -> edt.cursor.deleteRows(); ct(edt)
  
  # Line manipulation
  "Alt-Up":   (edt) -> edt.cursor.shiftLinesUp()
  "Alt-Down": (edt) -> edt.cursor.shiftLinesDown()
  
  # Undo/redo
  "Control-z":       (edt) -> edt.buffer.undo()
  "Control-Shift-z": (edt) -> edt.buffer.redo()
  
  # Indentation
  "\t":       (edt) -> edt.cursor.indent edt.tab
  "Shift-\t": (edt) -> edt.cursor.outdent edt.tab
  
  otherwise: (edt, key) ->
    if key.length == 1
      edt.cursor.insert key
      ct edt if /\s/.test key
      return false
    else
      return true
  

ct = (edt) ->
  edt.buffer.commitTransaction()

HomeHome = (edt, method="move") ->
  point = edt.cursor.point || edt.cursor.region.end
  if point.col == 0
    whitespace = /^\s*/.exec edt.buffer.text(point.row)
    edt.cursor["#{method}To"] null, whitespace[0].length
  else
    edt.cursor["#{method}ToLineBegin"]()

