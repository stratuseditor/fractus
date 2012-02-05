should                  = require 'should'
{Buffer, Point, Region} = require '../src/buffer'

describe "Buffer", ->
  describe "new", ->
    it "sets the initial text", ->
      b = new Buffer "Initial\ntext"
      b.text().should.eql "Initial\ntext"
    
    describe "when using Windows-style line endings", ->
      it "cleans them up into regular \\n ending", ->
        b = new Buffer "Bla\r\nbla\r\n"
        b.text().should.eql "Bla\nbla\n"
  
  
  describe "#point", ->
    it "returns an instance of Point", ->
      b     = new Buffer "Hello,\nworld"
      point = b.point(1, 2)
      point.should.be.an.instanceof Point
      point.buffer.should.eql b
      point.row.should.eql 1
      point.col.should.eql 2
  
  
  describe "#text", ->
    b = new Buffer "Hello,\nworld"
    describe "of the document", ->
      it "returns the entire document", ->
        b.text().should.eql "Hello,\nworld"
    
    describe "of a row", ->
      it "returns the given line", ->
        b.text(0).should.eql "Hello,"
        b.text(1).should.eql "world"
    
    describe "of a nonexistant line", ->
      it "returns undefined", ->
        should.not.exist b.text 100
    
    describe "of a column", ->
      it "returns the given character", ->
        b.text(0, 0).should.eql "H"
        b.text(0, 1).should.eql "e"
        b.text(1, 0).should.eql "w"
        b.text(1, 1).should.eql "o"
    
    describe "of a nonexistant column", ->
      it "returns undefined", ->
        should.not.exist b.text(0, 100)
        should.not.exist b.text(100, 100)
  
  
  describe "#lineCount", ->
    it "is the number of lines", ->
      b = new Buffer "Hello,\nworld"
      b.lineCount().should.eql 2
    
    it "is 1 for an empty document", ->
      b = new Buffer ""
      b.lineCount().should.eql 1
  
  
  describe "#lineLength", ->
    b = new Buffer "Hello,\nworld"
    it "is the length of the line", ->
      b.lineLength(0).should.eql 6
      b.lineLength(1).should.eql 5
    
    it "is undefined for a nonexistant row", ->
      should.not.exist b.lineLength 100
  
  
  describe "#search", ->
    b = new Buffer "Hello,\nworld"
    describe "for a String", ->
      region = b.search "Hello"
      it "is a Region", ->
        region.should.be.an.instanceof Region
      
      describe "the region", ->
        it "begins at (0, 0)", ->
          region.begin.row.should.eql 0
          region.begin.col.should.eql 0
        
        it "ends at (0, 5)", ->
          region.end.row.should.eql 0
          region.end.col.should.eql 5
    
    describe "for a RegExp", ->
      region = b.search /hello/i
      it "is a Region", ->
        region.should.be.an.instanceof Region
      
      describe "the region", ->
        it "begins at (0, 0)", ->
          region.begin.row.should.eql 0
          region.begin.col.should.eql 0
        
        it "ends at (0, 5)", ->
          region.end.row.should.eql 0
          region.end.col.should.eql 5
    
    describe "from a start position", ->
      b2     = new Buffer "Hello Hello"
      region = b2.search "Hello", 0, 1
      describe "the region", ->
        it "begins at (0, 6)", ->
          region.begin.row.should.eql 0
          region.begin.col.should.eql 6
    
    describe "a failed search", ->
      it "returns null", ->
        should.not.exist b.search("XXX")
  
  
  describe "#searchAll", ->
    describe "a simple search", ->
      b       = new Buffer "Hi!!\nhi hi"
      regions = b.searchAll /hi/i
      
      it "returns an Array of Regions", ->
        regions.should.be.an.instanceof Array
        regions[0].should.be.an.instanceof Region
      
      it "returns regions highlighting the terms", ->
        for begin, i in [[0, 0], [1, 0], [1, 3]]
          regions[i].begin.row.should.eql begin[0]
          regions[i].begin.col.should.eql begin[1]
        for end, i in [[0, 2], [1, 2], [1, 5]]
          regions[i].end.row.should.eql end[0]
          regions[i].end.col.should.eql end[1]
      
      it "highlights all of the terms", ->
        regions.length.should.eql 3
    
    describe "no results", ->
      b       = new Buffer "bla bla bla"
      regions = b.searchAll "!!!"
      it "returns an empty array", ->
        regions.should.eql []
    
    describe "results with no spacing in between", ->
      b       = new Buffer "------"
      regions = b.searchAll "-"
      it "finds them all", ->
        regions.length.should.eql 6
  
  
  describe "#replace", ->
    describe "text", ->
      b      = new Buffer "Hello, world"
      region = b.replace "world", "planet"
      it "replaces the text", ->
        b.text().should.eql "Hello, planet"
      
      it "returns a Region", ->
        region.should.be.an.instanceof Region
    
    describe "RegExp", ->
      describe "no captures", ->
        b      = new Buffer "Hello, world"
        region = b.replace /WORLD/i, "planet"
        it "replaces the text", ->
          b.text().should.eql "Hello, planet"
      
      describe "capture $0", ->
        b      = new Buffer "Hello, world"
        region = b.replace /WORLD/i, "$0!"
        it "replaces the text", ->
          b.text().should.eql "Hello, world!"
      
      describe "capture $1", ->
        b      = new Buffer "Hello, world"
        region = b.replace /WO(RL)D/i, "$1!"
        it "replaces the text", ->
          b.text().should.eql "Hello, rl!"
      
      describe "multiple captures", ->
        b      = new Buffer "33 is true!"
        region = b.replace /(33) is true/, "$1='$1'"
        it "replaces the text", ->
          b.text().should.eql "33='33'!"
    
    describe "when no changes are made", ->
      b      = new Buffer "Hello, world"
      region = b.replace "......", "planet"
      it "returns null", ->
        should.not.exist region
  
  
  describe "#replaceAll", ->
    describe "text", ->
      b       = new Buffer "Hello, world\nworld world"
      changes = b.replaceAll "world", "!"
      it "replaces all occurences", ->
        b.text().should.eql "Hello, !\n! !"
      
      it "replaces the number of changes made", ->
        changes.should.eql 3
  
  
  describe "#deleteLine", ->
    it "deletes the line", ->
      b = new Buffer "Hello,\nworld"
      b.deleteLine 0
      b.text(0).should.eql "world"
      b.text().should.eql "world"
    
    describe "deleting the last line", ->
      b = new Buffer "one line"
      b.deleteLine 0
      it "changes the line text to ''", ->
        b.text(0).should.eql ""
      
      it "leaves the line count at 1", ->
        b.lineCount().should.eql 1
  
  
  describe "#setLine", ->
    b = new Buffer "Hello,\nworld"
    b.setLine 0, "See ya,"
    it "sets the text of the line", ->
      b.text(0).should.eql "See ya,"
      b.text().should.eql "See ya,\nworld"
  
  
  describe "#insertLine", ->
    b = new Buffer "Hello,\nworld"
    b.insertLine 2, "Good bye"
    it "inserts the line at the given index", ->
      b.text().should.eql "Hello,\nworld\nGood bye"
  
  
  describe "#setText", ->
    b = new Buffer "Hello,\nworld"
    b.setText "Good day, sir!"
    it "sets the text", ->
      b.text().should.eql "Good day, sir!"
  
  
  describe "#undo", ->
    describe "change", ->
      b = new Buffer "Hello,\nworld"
      b.setLine 0, "Bye"
      it "reverts the change", ->
        b.undo()
        b.text().should.eql "Hello,\nworld"
    
    describe "deletion of a line", ->
      b = new Buffer "Hello,\nworld"
      b.deleteLine 0
      it "reverts the change", ->
        b.undo()
        b.text().should.eql "Hello,\nworld"
    
    describe "insertion of a line", ->
      b = new Buffer "Hello,\nworld"
      b.insertLine 2, "See ya"
      it "reverts the change", ->
        b.undo()
        b.text().should.eql "Hello,\nworld"
    
    describe "multiple steps", ->
      b = new Buffer "Hello,\nworld"
      b.setLine 0, "Bye"
      b.setLine 0, "Bye2"
      it "reverts the changes", ->
        b.undo()
        b.text().should.eql "Hello,\nworld"
  
  describe "#redo", ->
    describe "change", ->
      b = new Buffer "Hello,\nworld"
      b.setLine 0, "Bye"
      b.undo()
      it "reverts the change", ->
        b.redo()
        b.text().should.eql "Bye\nworld"
    
    describe "deletion of a line", ->
      b = new Buffer "Hello,\nworld"
      b.deleteLine 0
      b.undo()
      it "reverts the change", ->
        b.redo()
        b.text().should.eql "world"
    
    describe "insertion of a line", ->
      b = new Buffer "Hello,\nworld"
      b.insertLine 2, "See ya"
      b.undo()
      it "reverts the change", ->
        b.redo()
        b.text().should.eql "Hello,\nworld\nSee ya"
    
    describe "multiple steps", ->
      b = new Buffer "Hello,\nworld"
      b.setLine 0, "Bye"
      b.setLine 0, "Bye2"
      b.undo()
      it "reverts the changes", ->
        b.redo()
        b.text().should.eql "Bye2\nworld"
  
  
  describe "#commitTransaction", ->
    b = new Buffer "Hello,\nworld"
    it "marks undo steps", ->
      b.setLine 0, "Bye"
      b.commitTransaction()
      b.setLine 0, "Bye2"
      b.commitTransaction()
      b.setLine 0, "Bye3"
      b.commitTransaction()
      b.undo()
      b.undo()
      b.text().should.eql "Bye\nworld"
  
  
  describe "#insert", ->
    describe "a single line", ->
      b  = new Buffer "Hello,\nworld"
      pt = b.insert "CHEESE", 0, 0
      it "inserts the text", ->
        b.text().should.eql "CHEESEHello,\nworld"
      
      it "returns the end point", ->
        pt.row.should.eql 0
        pt.col.should.eql 6
    
    describe "multiple lines", ->
      b  = new Buffer "Hello,\nworld"
      pt = b.insert "CHEESE\nis the best", 0, 0
      it "inserts the text", ->
        b.text().should.eql "CHEESE\nis the bestHello,\nworld"
      
      it "returns the end point", ->
        pt.row.should.eql 1
        pt.col.should.eql 11
  
  
  describe "#overwrite", ->
    b  = new Buffer "Hello,\nworld"
    pt = b.overwrite "CHEESE!", 0, 0
    it "inserts the text", ->
      b.text().should.eql "CHEESE!\nworld"
    
    it "returns a point", ->
      pt.should.be.an.instanceof Point
    
    it "returns a point positioned at the end of the update", ->
      pt.row.should.eql 0
      pt.col.should.eql 7
  
  
  describe "#insertNewLine", ->
    it "inserts the newline character", ->
      b = new Buffer "Hello,\nworld"
      b.insertNewLine 0, 1
      b.text().should.eql "H\nello,\nworld"
  
  
  describe "#joinLines", ->
    b = new Buffer "Hello,\nworld"
    it "joins the lines", ->
      b.joinLines 0
      b.text().should.eql "Hello,world"
  
  
  describe "#wordAt", ->
    describe "solid word", ->
      b      = new Buffer "Hello,\nworld"
      region = b.wordAt 0, 2
      it "returns the correct region", ->
        region.begin.row.should.eql 0
        region.begin.col.should.eql 0
        region.end.row.should.eql 0
        region.end.col.should.eql 5
      
      it "is solid", ->
        region.isSolid.should.be.true
    
    describe "non-solid word", ->
      b      = new Buffer "Hello,\nworld"
      region = b.wordAt 0, 6
      it "returns the correct region", ->
        region.begin.row.should.eql 0
        region.begin.col.should.eql 5
        region.end.row.should.eql 0
        region.end.col.should.eql 6
      
      it "is not solid", ->
        region.isSolid.should.be.false
    
    describe "custom word regex", ->
      b      = new Buffer "Hello-world"
      region = b.wordAt 0, 2, "[a-zA-Z-]+"
      it "returns the correct region", ->
        region.begin.row.should.eql 0
        region.begin.col.should.eql 0
        region.end.row.should.eql 0
        region.end.col.should.eql 11
      
      it "is solid", ->
        region.isSolid.should.be.true
    
    describe "at the beginning of a word", ->
      b      = new Buffer "Hello world"
      region = b.wordAt 0, 6, "[a-zA-Z-]+"
      it "is solid", ->
        region.isSolid.should.be.true
      
      it "returns the correct region", ->
        region.begin.col.should.eql 6
        region.end.col.should.eql 11
    
    describe "at the end of a word", ->
      b      = new Buffer "Hello world"
      region = b.wordAt 0, 5, "[a-zA-Z-]+"
      it "is solid", ->
        region.isSolid.should.be.true
      
      it "returns the correct region", ->
        region.begin.col.should.eql 0
        region.end.col.should.eql 5
  
  
  describe "#shiftLinesUp", ->
    describe "in the middle of the text", ->
      b = new Buffer "0123456789".split("").join("\n")
      b.shiftLinesUp 3, 5
      it "shifts the included lines up", ->
        b.text().should.eql "0134526789".split("").join("\n")
    
    describe "to the beginning of the document", ->
      b = new Buffer "0123456789".split("").join("\n")
      b.shiftLinesUp 1, 3
      it "shifts the included lines up", ->
        b.text().should.eql "1230456789".split("").join("\n")
    
    describe "at the beginning of the document", ->
      b = new Buffer "0123456789".split("").join("\n")
      b.shiftLinesUp 0, 3
      it "does not shift the lines", ->
        b.text().should.eql "0123456789".split("").join("\n")
  
  
  describe "#shiftLinesDown", ->
    describe "in the middle of the text", ->
      b = new Buffer "0123456789".split("").join("\n")
      b.shiftLinesDown 3, 5
      it "shifts the included lines down", ->
        b.text().should.eql "0126345789".split("").join("\n")
    
    describe "to the end of the document", ->
      b = new Buffer "0123456789".split("").join("\n")
      b.shiftLinesDown 6, 8
      it "shifts the included lines down", ->
        b.text().should.eql "0123459678".split("").join("\n")
    
    describe "at the end of the document", ->
      b = new Buffer "0123456789".split("").join("\n")
      b.shiftLinesDown 7, 9
      it "does not shift the lines", ->
        b.text().should.eql "0123456789".split("").join("\n")
  
  
  describe "#deleteLines", ->
    it "deletes all of the included rows", ->
      b = new Buffer "0123456789".split("").join("\n")
      b.deleteLines 1, 5
      b.text().should.eql "06789".split("").join("\n")



describe "Point", ->
  describe "new", ->
    b  = new Buffer "Hello\nworld"
    pt = new Point b, 0, 1, false
    for prop in ["buffer", "row", "col", "anchor"]
      it "assigns @#{prop}", ->
        pt.should.have.property prop
  
  
  describe "#moveTo", ->
    b  = new Buffer "Hello\nworld"
    describe "moving both values", ->
      pt = b.point 0, 1
      pt.moveTo 2, 3
      it "updates Buffer#row", ->
        pt.row.should.eql 2
      
      it "updates Buffer#col", ->
        pt.col.should.eql 3
    
    describe "moving only the row", ->
      pt = b.point 0, 2
      pt.moveTo 1, null
      it "updates the `row`", ->
        pt.row.should.eql 1
      
      it "does not update `col`", ->
        pt.col.should.eql 2
    
    describe "moving only the col", ->
      pt = b.point 0, 1
      pt.moveTo null, 3
      it "does not update the row", ->
        pt.row.should.eql 0
      
      it "updates the col", ->
        pt.col.should.eql 3
    
    describe "move to another point", ->
      pt  = b.point 0, 1
      pt2 = b.point 0, 3
      pt.moveTo pt2
      it "moves the point", ->
        pt.col.should.eql 3
  
  
  describe "#equals", ->
    b = new Buffer "Hello\nworld"
    describe "when the points are equal", ->
      it "returns true", ->
        b.point(0, 0).equals(b.point(0, 0)).should.be.true
    
    describe "when the points are not equal", ->
      it "returns false", ->
        b.point(0, 0).equals(b.point(0, 1)).should.be.false
  
  
  describe "#isBefore", ->
    b = new Buffer "Hello\nworld"
    describe "when the argument is after", ->
      describe "same rows", ->
        it "returns true", ->
          b.point(0, 0).isBefore(b.point(0, 2)).should.be.true
      
      describe "different rows", ->
        it "returns true", ->
          b.point(0, 1).isBefore(b.point(1, 0)).should.be.true
    
    describe "when the argument is before", ->
      describe "same rows", ->
        it "returns false", ->
          b.point(0, 2).isBefore(b.point(0, 0)).should.be.false
      
      describe "different rows", ->
        it "returns false", ->
          b.point(1, 0).isBefore(b.point(0, 1)).should.be.false
    
    describe "the same points", ->
      it "returns false", ->
        b.point(0, 2).isBefore(b.point(0, 2)).should.be.false
  
  
  describe "#isAfter", ->
    b = new Buffer "Hello\nworld"
    describe "when the argument is after", ->
      it "is true", ->
        b.point(0, 4).isAfter(b.point(0, 2)).should.be.true
    
    describe "the same points", ->
      it "returns false", ->
        b.point(0, 2).isAfter(b.point(0, 2)).should.be.false
  
  
  describe "#clone", ->
    b  = new Buffer "Hello\nworld"
    pt = b.point 0, 1
    it "copies the properties", ->
      clone = pt.clone()
      clone.buffer.should.eql b
      clone.row.should.eql 0
      clone.col.should.eql 1
    
    it "is not the same object", ->
      pt.clone().should.not.equal pt
  
  
  describe "#toString", ->
    b  = new Buffer "Hello"
    pt = b.point 0, 1
    it "is a string representation of the point", ->
      pt.toString().should.eql "(0, 1)"
  
  
  describe "#round", ->
    describe "round column", ->
      b  = new Buffer "Hello"
      pt = b.point 0, 1000
      it "goes to the closest column", ->
        pt.round()
        pt.col.should.eql 5
    
    describe "round row", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 5, 3
      it "goes to the closest row", ->
        pt.round()
        pt.row.should.eql 1
    
    describe "when no rounding is necessary", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 3
      it "doesnt change anything", ->
        pt.row.should.eql 1
        pt.col.should.eql 3
  
  
  describe "#prevLoc", ->
    describe "in the middle of a line", ->
      b    = new Buffer "Hello\nworld"
      pt   = b.point 0, 2
      prev = pt.prevLoc()
      it "is on the same row", ->
        prev.row.should.eql 0
      
      it "is one column to the left", ->
        prev.col.should.eql 1
    
    describe "at the beginning of a line", ->
      b    = new Buffer "Hello\nworld"
      pt   = b.point 1, 0
      prev = pt.prevLoc()
      it "is on the previous row", ->
        prev.row.should.eql 0
      
      it "is at the end of the row", ->
        prev.col.should.eql 5
    
    describe "at the beginning of the document", ->
      b    = new Buffer "Hello\nworld"
      pt   = b.point 0, 0
      prev = pt.prevLoc()
      it "is on the same row", ->
        prev.row.should.eql 0
      
      it "is on the same column", ->
        prev.col.should.eql 0
  
  
  describe "#nextLoc", ->
    describe "in the middle of a line", ->
      b    = new Buffer "Hello\nworld"
      pt   = b.point 0, 2
      next = pt.nextLoc()
      it "is on the same row", ->
        next.row.should.eql 0
      
      it "is one column to the right", ->
        next.col.should.eql 3
    
    describe "at the end of a line", ->
      b    = new Buffer "Hello\nworld"
      pt   = b.point 0, 5
      next = pt.nextLoc()
      it "is on the next row", ->
        next.row.should.eql 1
      
      it "is at the end of the row", ->
        next.col.should.eql 0
    
    describe "at the end of the document", ->
      b    = new Buffer "Hello\nworld"
      pt   = b.point 1, 5
      next = pt.nextLoc()
      it "is on the same row", ->
        next.row.should.eql 1
      
      it "is on the same column", ->
        next.col.should.eql 5
  
  
  describe "#moveToLineBegin", ->
    it "moves the point to the beginning of the line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 3
      pt.moveToLineBegin()
      pt.col.should.eql 0
    
    it "resets the ideal column", ->
      b  = new Buffer "12345\n67890"
      pt = b.point 1, 3
      pt.moveVertical -1
      pt.moveToLineBegin()
      pt.moveVertical 1
      pt.col.should.eql 0
  
  
  describe "#moveToLineEnd", ->
    b  = new Buffer "Hello\nworld"
    pt = b.point 1, 3
    it "moves the point to the end of the line", ->
      pt.moveToLineEnd()
      pt.col.should.eql 5
  
  
  describe "#moveLeft", ->
    it "moves left", ->
      b = new Buffer "Hello\nworld"
      pt = b.point 0, 2
      pt.moveLeft()
      pt.row.should.eql 0
      pt.col.should.eql 1
    
    it "wraps at the beginning of a line", ->
      b = new Buffer "Hello\nworld"
      pt = b.point 1, 0
      pt.moveLeft()
      pt.row.should.eql 0
      pt.col.should.eql 5
    
    it "resets the ideal column", ->
      b  = new Buffer "123456789\n123\n123456"
      pt = b.point 0, 9
      pt.moveVertical 1
      pt.moveLeft()
      pt.moveVertical 1
      pt.col.should.eql 2
  
  
  describe "#moveRight", ->
    it "moves right", ->
      b = new Buffer "Hello\nworld"
      pt = b.point 0, 2
      pt.moveRight()
      pt.row.should.eql 0
      pt.col.should.eql 3
    
    it "wraps at the end of a line", ->
      b = new Buffer "Hello\nworld"
      pt = b.point 0, 5
      pt.moveRight()
      pt.row.should.eql 1
      pt.col.should.eql 0
  
  
  describe "#moveDown", ->
    it "moves down", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 0, 2
      pt.moveDown()
      pt.row.should.eql 1
      pt.col.should.eql 2
    
    it "moves to the end of the line if is on the last line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 2
      pt.moveDown()
      pt.row.should.eql 1
      pt.col.should.eql 5
  
  
  describe "#moveUp", ->
    it "moves up", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 2
      pt.moveUp()
      pt.row.should.eql 0
      pt.col.should.eql 2
    
    it "moves to the beginning of the line if is on the first line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 0, 2
      pt.moveUp()
      pt.row.should.eql 0
      pt.col.should.eql 0
  
  
  describe "#moveVertical", ->
    describe "normal", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 3
      it "moves the point `amount` rows", ->
        pt.moveVertical -1
        pt.row.should.eql 0
    
    describe "when an in-between line is too short", ->
      b  = new Buffer "123\n4\n567"
      pt = b.point 2, 3
      it "remembers the ideal column", ->
        pt.moveVertical -1
        pt.row.should.eql 1
        pt.col.should.eql 1
        pt.moveVertical -1
        pt.row.should.eql 0
        pt.col.should.eql 3
  
  describe "#moveToPrevWord", ->
    describe "across one character", ->
      b  = new Buffer "Hello world"
      pt = b.point 0, 7
      pt.moveToPrevWord()
      it "moves to the beginning of the word", ->
        pt.row.should.eql 0
        pt.col.should.eql 6
    
    describe "within one line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 3
      pt.moveToPrevWord()
      it "moves to the beginning of the previous word", ->
        pt.row.should.eql 1
        pt.col.should.eql 0
    
    describe "multiple lines", ->
      b  = new Buffer "Hello\n, world"
      pt = b.point 1, 2
      pt.moveToPrevWord()
      it "moves to the beginning of the previous word", ->
        pt.row.should.eql 0
        pt.col.should.eql 0
    
    describe "at the beginning of the document", ->
      b  = new Buffer "Hello\n, world"
      pt = b.point 0, 0
      pt.moveToPrevWord()
      it "does not move the point", ->
        pt.row.should.eql 0
        pt.col.should.eql 0
    
    describe "to the beginning of the document", ->
      b  = new Buffer "   Hello\n, world"
      pt = b.point 0, 2
      pt.moveToPrevWord()
      it "moves the point to the document start", ->
        pt.row.should.eql 0
        pt.col.should.eql 0
  
  
  describe "#moveToNextWord", ->
    describe "across one character", ->
      b  = new Buffer "Hello world"
      pt = b.point 0, 4
      pt.moveToNextWord()
      it "moves to the end of the word", ->
        pt.row.should.eql 0
        pt.col.should.eql 5
    
    describe "within one line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 3
      pt.moveToNextWord()
      it "moves to the end of the next word", ->
        pt.row.should.eql 1
        pt.col.should.eql 5
    
    describe "multiple lines", ->
      b  = new Buffer "Hello, \n.. world"
      pt = b.point 0, 5
      pt.moveToNextWord()
      it "moves to the end of the next word", ->
        pt.row.should.eql 1
        pt.col.should.eql 8
    
    describe "at the end of the document", ->
      b  = new Buffer "Hello\n, world"
      pt = b.point 1, 7
      pt.moveToNextWord()
      it "does not move the point", ->
        pt.row.should.eql 1
        pt.col.should.eql 7
    
    describe "to the beginning of the document", ->
      b  = new Buffer "   Hello\n, world  "
      pt = b.point 1, 4
      pt.moveToNextWord()
      it "moves the point to the document end", ->
        pt.row.should.eql 1
        pt.col.should.eql 7
  
  describe "#moveToDocBegin", ->
    b  = new Buffer "   Hello\n, world  "
    pt = b.point 1, 4
    pt.moveToDocBegin()
    it "moves to (0, 0)", ->
      pt.row.should.eql 0
      pt.col.should.eql 0
  
  describe "#moveToDocEnd", ->
    b  = new Buffer "   Hello\n, world  "
    pt = b.point 0, 4
    pt.moveToDocEnd()
    it "moves to the last column of the last row", ->
      pt.row.should.eql 1
      pt.col.should.eql 9
  
  
  describe "#isAtDocBegin", ->
    b = new Buffer "Hello"
    describe "when at the document beginning", ->
      it "is true", ->
        b.point(0, 0).isAtDocBegin().should.be.true
    
    describe "when in the middle of the document", ->
      it "is false", ->
        b.point(0, 2).isAtDocBegin().should.be.false
  
  describe "#isAtDocEnd", ->
    b = new Buffer "Hello"
    describe "when at the document end", ->
      it "is true", ->
        b.point(0, 5).isAtDocEnd().should.be.true
    
    describe "when in the middle of the document", ->
      it "is false", ->
        b.point(0, 2).isAtDocEnd().should.be.false
  
  
  describe "#insert", ->
    b  = new Buffer "Hello"
    pt = b.point 0, 0
    pt.insert "!!"
    it "inserts the text", ->
      b.text().should.eql "!!Hello"
    
    it "moves the point", ->
      pt.col.should.eql 2
  
  
  describe "#overwrite", ->
    b  = new Buffer "Hello"
    pt = b.point 0, 0
    pt.overwrite "!!"
    it "inserts the text", ->
      b.text().should.eql "!!llo"
    
    it "moves the point", ->
      pt.col.should.eql 2
  
  
  describe "#deleteBack", ->
    describe "in the middle of a line", ->
      b  = new Buffer "Hello"
      pt = b.point 0, 4
      pt.deleteBack()
      it "deletes a character", ->
        b.text().should.eql "Helo"
      
      it "repositions the point", ->
        pt.row.should.eql 0
        pt.col.should.eql 3
    
    describe "at the beginning of a line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 0
      pt.deleteBack()
      it "joins the line", ->
        b.text().should.eql "Helloworld"
      
      it "repositions the point", ->
        pt.row.should.eql 0
        pt.col.should.eql 5
    
    describe "at the beginning of the document", ->
      b  = new Buffer "Hello"
      pt = b.point 0, 0
      pt.deleteBack()
      it "does not change the text", ->
        b.text().should.eql "Hello"
      
      it "does not move the point", ->
        pt.row.should.eql 0
        pt.col.should.eql 0
  
  
  describe "#deleteForward", ->
    describe "in the middle of a line", ->
      b  = new Buffer "Hello"
      pt = b.point 0, 4
      pt.deleteForward()
      it "deletes a character", ->
        b.text().should.eql "Hell"
    
    describe "at the end of a line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 0, 5
      pt.deleteForward()
      it "joins the line", ->
        b.text().should.eql "Helloworld"
    
    describe "at the end of the document", ->
      b  = new Buffer "Hello"
      pt = b.point 0, 5
      pt.deleteForward()
      it "does not change the text", ->
        b.text().should.eql "Hello"
  
  describe "#deleteWordBack", ->
    describe "in the middle of a word", ->
      b  = new Buffer "bla Hello"
      pt = b.point 0, 8
      pt.deleteWordBack()
      it "part of the word", ->
        b.text().should.eql "bla o"
      
      it "moves the point", ->
        pt.col.should.eql 4
    
    describe "at the beginning of a line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 1, 0
      pt.deleteWordBack()
      it "joins the line", ->
        b.text().should.eql "world"
      
      it "moves the point", ->
        pt.row.should.eql 0
        pt.col.should.eql 0
    
    describe "at the beginning of the document", ->
      b  = new Buffer "Hello"
      pt = b.point 0, 0
      pt.deleteWordBack()
      it "does not change the text", ->
        b.text().should.eql "Hello"
      
      it "does not move the point", ->
        pt.col.should.eql 0
  
  
  describe "#deleteWordForward", ->
    describe "in the middle of a word", ->
      b  = new Buffer "bla Hello"
      pt = b.point 0, 6
      pt.deleteWordForward()
      it "part of the word", ->
        b.text().should.eql "bla He"
      
      it "does not move the point", ->
        pt.col.should.eql 6
    
    describe "at the end of a line", ->
      b  = new Buffer "Hello\nworld"
      pt = b.point 0, 5
      pt.deleteWordForward()
      it "joins the line", ->
        b.text().should.eql "Hello"
    
    describe "at the end of the document", ->
      b  = new Buffer "Hello"
      pt = b.point 0, 5
      pt.deleteWordForward()
      it "does not change the text", ->
        b.text().should.eql "Hello"
      
      it "does not move the point", ->
        pt.col.should.eql 5
  
  
  describe "#newLine", ->
    b  = new Buffer "Hello,\nworld"
    pt = b.point 0, 3
    pt.newLine()
    it "creates a new line", ->
      b.text().should.eql "Hel\nlo,\nworld"
    
    it "repositions the point", ->
      pt.row.should.eql 1
      pt.col.should.eql 0



describe "Region", ->
  describe "new", ->
    b      = new Buffer "Hello"
    p1     = b.point 0, 0
    p2     = b.point 0, 2
    region = new Region p1, p2
    
    it "assigns @begin", ->
      region.begin.should.eql p1
    
    it "assigns @end", ->
      region.end.should.eql p2
    
    it "assigns @buffer", ->
      region.buffer.should.eql b
  
  
  describe "#ordered", ->
    b  = new Buffer "Hello\nworld"
    p1 = b.point 0, 0
    p2 = b.point 0, 2
    p3 = b.point 1, 2
    
    describe "when it is already ordered", ->
      region = (new Region p1, p2).ordered()
      
      it "has the same begin point", ->
        region.begin.should.eql p1
      
      it "has the same end point", ->
        region.end.should.eql p2
    
    describe "when they aren't ordered", ->
      describe "within single line", ->
        region = (new Region p2, p1).ordered()
        
        it "@begin is the old end", ->
          region.begin.should.eql p1
        
        it "@end is the old begin", ->
          region.end.should.eql p2
      
      describe "within single line", ->
        region = (new Region p3, p1).ordered()
        
        it "@begin is the old end", ->
          region.begin.should.eql p1
        
        it "@end is the old begin", ->
          region.end.should.eql p3
  
  
  describe "#isEmpty", ->
    b = new Buffer "Hello\nworld"
    describe "an empty region", ->
      region = new Region b.point(0, 2), b.point(0, 2)
      it "is true", ->
        region.isEmpty().should.be.true
    
    describe "a non-empty region", ->
      region = new Region b.point(0, 2), b.point(0, 3)
      it "is false", ->
        region.isEmpty().should.be.false
  
  
  describe "#text", ->
    b = new Buffer "Hello\nworld\n!!!"
    describe "an empty region", ->
      region = new Region b.point(0, 2), b.point(0, 2)
      it "is ''", ->
        region.text().should.eql ""
    
    describe "a single-line region", ->
      region = new Region b.point(0, 2), b.point(0, 4)
      it "is the correct string", ->
        region.text().should.eql "ll"
    
    describe "a multiline region", ->
      region = new Region b.point(0, 2), b.point(2, 2)
      it "is the correct string", ->
        region.text().should.eql "llo\nworld\n!!"
  
  
  describe "#replaceWith", ->
    describe "on a single line", ->
      b      = new Buffer "Hello world"
      region = new Region b.point(0, 6), b.point(0, 11)
      region.replaceWith "planet"
      
      it "replaces the text", ->
        b.text().should.eql "Hello planet"
      
      it "updates the end point", ->
        region.end.col.should.eql 12
    
    describe "replace multiple lines", ->
      b      = new Buffer "Hello\nworld"
      region = new Region b.point(0, 2), b.point(1, 3)
      region.replaceWith ""
      
      it "replaces the text", ->
        b.text().should.eql "Held"
      
      it "updates the end point", ->
        region.end.row.should.eql 0
        region.end.col.should.eql 2
    
    describe "replace with multiple lines", ->
      b      = new Buffer "Hello\nworld"
      region = new Region b.point(0, 2), b.point(1, 3)
      region.replaceWith "!\n?\n!"
      
      it "replaces the text", ->
        b.text().should.eql "He!\n?\n!ld"
      
      it "updates the end point", ->
        region.end.row.should.eql 2
        region.end.col.should.eql 1
  
  
  describe "#delete", ->
    b      = new Buffer "Hello\nworld"
    region = new Region b.point(0, 2), b.point(1, 3)
    region.delete()
    it "deletes the region", ->
      b.text().should.eql "Held"
    
    it "repositions the points", ->
      region.begin.row.should.eql 0
      region.begin.col.should.eql 2
      region.end.row.should.eql 0
      region.end.col.should.eql 2
  
  
  describe "#selectRow", ->
    b      = new Buffer "Hello\nworld"
    region = new Region b.point(0, 0), b.point(0, 0)
    region.selectRow 1
    it "selects the line", ->
      region.begin.row.should.eql 1
      region.begin.col.should.eql 0
      region.end.row.should.eql 1
      region.end.col.should.eql 5
  
  
  describe "#selectRows", ->
    b      = new Buffer "Hello\nworld\n12345\n6789"
    region = new Region b.point(0, 0), b.point(0, 0)
    region.selectRows 1, 3
    it "selects the line", ->
      region.begin.row.should.eql 1
      region.begin.col.should.eql 0
      region.end.row.should.eql 3
      region.end.col.should.eql 4
  
  
  describe "#shiftLinesUp", ->
    describe "a single line", ->
      b      = new Buffer "123\n456\n789"
      region = new Region b.point(1, 1), b.point(1, 1)
      region.shiftLinesUp()
      it "shifts the lines up", ->
        b.text().should.eql "456\n123\n789"
      
      it "moves the cursor", ->
        region.begin.row.should.eql 0
        region.begin.col.should.eql 1
        region.end.row.should.eql 0
        region.end.col.should.eql 1
    
    describe "multiple lines", ->
      b      = new Buffer "123\n456\n789\nabc"
      region = new Region b.point(1, 1), b.point(2, 2)
      region.shiftLinesUp()
      it "shifts the lines up", ->
        b.text().should.eql "456\n789\n123\nabc"
      
      it "moves the cursor", ->
        region.begin.row.should.eql 0
        region.begin.col.should.eql 1
        region.end.row.should.eql 1
        region.end.col.should.eql 2
    
    describe "at the beginning of the document", ->
      b      = new Buffer "123\n456\n789\nabc"
      region = new Region b.point(0, 1), b.point(0, 1)
      region.shiftLinesUp()
      it "does not shift the lines", ->
        b.text().should.eql "123\n456\n789\nabc"
      
      it "does not move the cursor", ->
        region.begin.row.should.eql 0
        region.begin.col.should.eql 1
        region.end.row.should.eql 0
        region.end.col.should.eql 1
  
  
  describe "#shiftLinesDown", ->
    describe "a single line", ->
      b      = new Buffer "123\n456\n789"
      region = new Region b.point(0, 1), b.point(0, 1)
      region.shiftLinesDown()
      it "shifts the lines down", ->
        b.text().should.eql "456\n123\n789"
      
      it "moves the cursor", ->
        region.begin.row.should.eql 1
        region.begin.col.should.eql 1
        region.end.row.should.eql 1
        region.end.col.should.eql 1
    
    describe "multiple lines", ->
      b      = new Buffer "123\n456\n789\nabc"
      region = new Region b.point(1, 1), b.point(2, 2)
      region.shiftLinesDown()
      it "shifts the lines down", ->
        b.text().should.eql "123\nabc\n456\n789"
      
      it "moves the cursor", ->
        region.begin.row.should.eql 2
        region.begin.col.should.eql 1
        region.end.row.should.eql 3
        region.end.col.should.eql 2
    
    describe "at the end of the document", ->
      b      = new Buffer "123\n456\n789\nabc"
      region = new Region b.point(3, 1), b.point(3, 1)
      region.shiftLinesDown()
      it "does not shift the lines", ->
        b.text().should.eql "123\n456\n789\nabc"
      
      it "does not move the cursor", ->
        region.begin.row.should.eql 3
        region.begin.col.should.eql 1
        region.end.row.should.eql 3
        region.end.col.should.eql 1
  
  
  describe "#indent", ->
    b      = new Buffer "123\n456\n789\nabc"
    region = new Region b.point(2, 1), b.point(1, 3)
    region.indent "    "
    it "indents the selected rows", ->
      b.text().should.eql "123\n    456\n    789\nabc"
    
    it "moves the `begin` point right", ->
      region.begin.row.should.eql 2
      region.begin.col.should.eql 5
    
    it "moves the `end` point right", ->
      region.end.row.should.eql 1
      region.end.col.should.eql 7
  
  
  describe "#outdent", ->
    describe "by the full amount", ->
      b = new Buffer "123\n      456\n      789\nabc"
      region = new Region b.point(2, 7), b.point(1, 5)
      region.outdent "    "
      it "outdents the selected rows", ->
        b.text().should.eql "123\n  456\n  789\nabc"
      
      it "moves the `begin` point left", ->
        region.begin.row.should.eql 2
        region.begin.col.should.eql 3
      
      it "moves the `end` point left", ->
        region.end.row.should.eql 1
        region.end.col.should.eql 1
    
    describe "by a partial amount", ->
      b = new Buffer "123\n456\n  789\nabc"
      region = new Region b.point(2, 2), b.point(1, 3)
      region.outdent "    "
      it "outdents the selected rows", ->
        b.text().should.eql "123\n456\n789\nabc"
      
      it "moves the `begin` point left", ->
        region.begin.row.should.eql 2
        region.begin.col.should.eql 0
      
      it "moves the `end` point left", ->
        region.end.row.should.eql 1
        region.end.col.should.eql 0
    
    describe "with both endpoints on the same line", ->
      b = new Buffer "123\n    456\n      789\nabc"
      region = new Region b.point(2, 2), b.point(2, 7)
      region.outdent "    "
      it "outdents the selected rows", ->
        b.text().should.eql "123\n    456\n  789\nabc"
      
      it "moves the `begin` point left", ->
        region.begin.row.should.eql 2
        region.begin.col.should.eql 0
      
      it "moves the `end` point left", ->
        region.end.row.should.eql 2
        region.end.col.should.eql 3
    

