{Buffer, Point, Region} = require '../src/buffer'

should = require 'should'
color  = require 'stratus-color'
bundle = require 'stratus-bundle'
bundle.testDir()

{Layout, MaxTree} = require '../src/layout'

color.addScopes bundle("Ruby").syntax

charSize = (c) -> {width: 7, height: 15}

buildLayout = (text, height=10*15, width=10*7, syntax=null) ->
  buffer = new Buffer text
  layout = new Layout buffer, charSize, height, width, syntax
  layout.onReset()
  return layout


describe "Layout", ->
  describe "#scrollTo", ->
    describe "basic", ->
      layout = buildLayout [1..100].join("\n"), 10*15
      it "sets @topRow", ->
        layout.scrollTo 0
        layout.topRow.should.eql 0
    
    describe "many lines", ->
      text = [1..100].join("\n")
      describe "at the first line", ->
        it "emits `render`", (done) ->
          layout = buildLayout text, 20*15
          layout.on "render", (html) ->
            html.should.include "<li>#{ [1..20].join("</li><li>") }</li>"
            done()
          layout.scrollTo 0, true
        
        it "emits `scrollY`", (done) ->
          layout = buildLayout text, 20*15
          layout.on "scrollY", (scrollTop) ->
            scrollTop.should.eql 0
            done()
          layout.scrollTo 0, true
        
        it "emits `gutter:renumber`", (done) ->
          layout = buildLayout text, 20*15
          layout.on "gutter:renumber", (range) ->
            range.begin.should.eql 0
            range.end.should.eql 20
            done()
          layout.scrollTo 0, true
      
      describe "somewhere in the middle", ->
        it "emits `render`", (done) ->
          layout = buildLayout text, 20*15
          layout.on "render", (html) ->
            html.should.include "<li>#{ [10..30].join("</li><li>") }</li>"
            done()
          layout.scrollTo 9
        
        it "emits `scrollY`", (done) ->
          layout = buildLayout text, 20*15
          layout.on "scrollY", (scrollTop) ->
            scrollTop.should.eql 15 * 9
            done()
          layout.scrollTo 9
        
        it "emits `gutter:renumber`", (done) ->
          layout = buildLayout text, 20*15
          layout.on "gutter:renumber", (range) ->
            range.begin.should.eql 9
            range.end.should.eql 29
            done()
          layout.scrollTo 9
      
      describe "with a syntax", ->
        layout = buildLayout text, 10*15, 10*7, "Ruby"
        layout.scrollTo 0
        it "scrolling to the middle does not throw an error", ->
          should.doesNotThrow ->
            layout.scrollTo 50
  
  
  describe "#scrollBottom", ->
    it "aligns with the bottom row", ->
      layout = buildLayout [1..500].join("\n"), 10*15
      layout.scrollBottom 400
      layout.topRow.should.eql 391
  
  
  describe "#lockScroll", ->
    layout = buildLayout [0..100].join("\n")
    layout.scrollTo 0
    layout.lockScroll()
    it "sets @scrollLock to true", ->
      layout.scrollLock.should.eql true
    
    it "prevent scrolling", ->
      layout.scrollTo 10
      layout.topRow.should.eql 0
  
  
  describe "#unlockScroll", ->
    layout = buildLayout [0..100].join("\n")
    layout.scrollTo 0
    layout.lockScroll()
    layout.unlockScroll()
    it "sets @scrollLock to false", ->
      layout.scrollLock.should.eql false
    
    it "allows scrolling", ->
      layout.scrollTo 10
      layout.topRow.should.eql 10
  
  
  describe "#totalHeight", ->
    it "is the total height of the lines, plus a line", ->
      layout = buildLayout [1..100].join("\n"), 20*15
      layout.totalHeight().should.eql 15 * 100 + 15
  
  
  describe "#setHeight", ->
    layout = buildLayout [1..100].join("\n"), 100
    layout.setHeight 400
    it "sets @height to the given value", ->
      layout.height.should.eql 400
  
  
  describe "#renderRow", ->
    describe "plaintext", ->
      it "returns line html", ->
        layout = buildLayout "Hello\nworld", 50*15
        layout.renderRow(0).should.eql "<li>Hello</li>"
        layout.renderRow(1).should.eql "<li>world</li>"
      
      it "escapes html characters", ->
        layout = buildLayout "<div>Hello\n</div>", 50*15
        layout.renderRow(0).should.eql "<li>&lt;div&gt;Hello</li>"
        layout.renderRow(1).should.eql "<li>&lt;/div&gt;</li>"
    
    describe "Ruby", ->
      layout = buildLayout "if 5 > 2\n  x = 'foo'\nend", 50*15, 7*10, "Ruby"
      line0  = layout.renderRow 0
      it "returns a list item", ->
        line0.should.match /^<li>/
        line0.should.match /<\/li>$/
      
      it "escapes html characters", ->
        line0.should.match /&gt;/
      
      it "highlights the code", ->
        line0.should.include "<span class='hi-keyword'>if</span>"
  
  
  describe "#tokenize", ->
    describe "simple", ->
      layout = buildLayout "if x\n  'hello'\nend", 50*15, 7*10, "Ruby"
      tokens = layout.tokenize 0
      it "returns an array", ->
        tokens.should.be.an.instanceof Array
      
      it "is a list of tokens", ->
        tokens[0].type.should.eql "keyword"
        tokens[0].text.should.eql "if"
        tokens[1].type.should.eql ""
        tokens[1].text.should.eql " x"
    
    describe "deep state stack", ->
      layout = buildLayout "'hel\nlo'", 50*15, 7*10, "Ruby"
      it "maintains the state across lines", ->
        layout.tokenize(0)[0].type.should.eql "string.literal"
        layout.tokenize(0)[0].text.should.eql "'hel"
        layout.tokenize(1)[0].type.should.eql "string.literal"
        layout.tokenize(1)[0].text.should.eql "lo'"
  
  
  describe "#buffer line:change", ->
    describe "when the changed line is visible", ->
      layout = buildLayout "Hello\nworld", 10*15
      layout.scrollTo 0
      it "emits `render:line:change`", (done) ->
        layout.on "render:line:change", (data) ->
          data.row.should.eql 1
          data.html.should.eql "<li>&lt;mom&gt;</li>"
          done()
        layout.buffer.setLine 1, "<mom>"
    
    describe "when the changed line is NOT visible", ->
      layout = buildLayout [1..100].join("\n"), 10*15
      layout.scrollTo 20
      it "does not emit `render:line:change`", (done) ->
        layout.on "render:line:change", (data) ->
          done()
        layout.buffer.setLine 1, "<mom>"
        done()
    
    describe "when a syntax is given", ->
      describe "when the context is not changed", ->
        layout = buildLayout "if false\n  'what'\nend", 10*15, 7*10, "Ruby"
        layout.scrollTo 0
        it "rehighlights the line", (done) ->
          layout.on "render:line:change", (data) ->
            return unless data.row == 1
            data.html.should.not.include "what"
            data.html.should.include ">321<"
            data.html.should.include "class='hi-constant"
            done()
          layout.buffer.setLine 1, "321"
      
      describe "when the context is changed", ->
        layout = buildLayout "true\nfalse\n123", 10*15, 7*10, "Ruby"
        layout.scrollTo 0
        it "rehighlights both lines", (done) ->
          layout.on "render:line:change", (data) ->
            {row, html} = data
            html.should.include "class='hi-string hi-string-literal'"
            if row == 0
              html.should.include "hi-string-literal'>'hi</span>"
            else if row == 1
              html.should.include "hi-string-literal'>false</span>"
            else if row == 2
              html.should.include "hi-string-literal'>123</span>"
              done()
          layout.buffer.setLine 0, "'hi"
      
      describe "when the context of offscreen lines change", ->
        layout = buildLayout "true\nfalse\n123\n456\n789", 2*15, 7*10, "Ruby"
        layout.scrollTo 0
        layout.buffer.setLine 0, "'true"
        it "rehighlights them when they become visible", ->
          layout.renderRow(0).should.include "string"
          layout.renderRow(4).should.not.include "string"
          layout.scrollTo 3
          layout.renderRow(4).should.include "string"
  
  
  describe "#buffer line:insert", ->
    describe "when the inserted line is visible", ->
      layout = buildLayout "Hello\nworld", 10*15
      layout.scrollTo 0
      it "emits `render:line:insert`", (done) ->
        layout.on "render:line:insert", (data) ->
          data.row.should.eql 1
          data.html.should.eql "<li>&lt;hi&gt;</li>"
          done()
        layout.buffer.insertLine 1, "<hi>"
    
    describe "when the inserted line is not visible", ->
      layout = buildLayout [1..100].join("\n"), 10*15
      layout.scrollTo 20
      it "does not emit `render:line:insert`", (done) ->
        layout.on "render:line:insert", ->
          done()
        layout.buffer.insertLine 1, "<mom>"
        done()
    
    describe "when a syntax is given", ->
      describe "when the context does not change", ->
        layout = buildLayout "if false\n  'whatsup'\nend", 10*15, 7*10, "Ruby"
        layout.scrollTo 0
        it "highlights the line", (done) ->
          layout.on "render:line:insert", (data) ->
            data.html.should.not.include "whatsup"
            data.html.should.include "321"
            data.html.should.include "hi-constant-numeric"
            done()
          layout.buffer.insertLine 1, "  321"
      
      describe "when the context changes", ->
        layout = buildLayout "false", 10*15, 7*10, "Ruby"
        layout.scrollTo 0
        it "rehighlights the following line", (done) ->
          layout.on "render:line:insert", (data) ->
            data.row.should.eql 0
            data.html.should.include "'hi-string hi-string-literal'>'<"
          layout.on "render:line:change", (data) ->
            data.row.should.eql 1
            data.html.should.include "'hi-string hi-string-literal'"
            data.html.should.include ">false<"
            done()
          layout.buffer.insertLine 0, "'"
      
      #     : []         
      # abc : []         0
      # '   : [string]   1   XXX
      # '   : []         2
      # def : []         3
      # -------- delete[1] -> update[1]
      #     : []         
      # abc : []         0
      # '   : [string]   1
      # def : []         2
      # -------- update[2]
      #     : []         
      # abc : []         0
      # '   : [string]   1
      # def : [string]   2
      # -------- insert[1, "'"]
      #     : []
      # abc : []         0
      # '   : [string]   1
      # '   : []         2
      # def : []         3
      describe "when lines move", ->
        layout = buildLayout "abc\n'\n'\ndef", 10*15, 7*10, "Ruby"
        layout.scrollTo 0
        layout.buffer.shiftLinesUp 2, 2
        
        it "doesnt change the text", ->
          layout.buffer.text().should.eql "abc\n'\n'\ndef"
        
        it "rehighlights the text", ->
          layout.lineCache[0].should.not.include "hi-string"
          layout.lineCache[1].should.include     "hi-string"
          layout.lineCache[2].should.include     "hi-string"
          layout.lineCache[3].should.not.include "hi-string"
  
  
  describe "#buffer line:delete", ->
    describe "when the deleted line is visible", ->
      describe "and the document end is visible", ->
        layout = buildLayout "Hello\nworld", 10*15
        layout.scrollTo 0
        it "emits `render:line:delete`", (done) ->
          layout.on "render:line:delete", (data) ->
            data.row.should.eql 0
            data.html.should.eql ""
            done()
          layout.buffer.deleteLine 0
      
      describe "and the document end is *not* visible", ->
        layout = buildLayout [1..100].join("\n"), 10*15
        layout.scrollTo 0
        it "emits `render:line:delete`", (done) ->
          layout.on "render:line:delete", (data) ->
            data.row.should.eql 0
            data.html.should.eql "<li>11</li>"
            done()
          layout.buffer.deleteLine 0
    
    describe "when the deleted line is not visible", ->
      layout = buildLayout [1..100].join("\n"), 10*15
      layout.scrollTo 20
      it "does not emit `render:line:deleted`", (done) ->
        layout.on "render:line:deleted", ->
          done()
        layout.buffer.deleteLine 1
        done()
    
    describe "when a syntax is given", ->
      describe "when the context changes", ->
        layout = buildLayout "'stuff\nfalse\n12321", 10*15, 7*10, "Ruby"
        layout.scrollTo 0
        it "rehighlights the following line", (done) ->
          layout.on "render:line:delete", (data) ->
            data.row.should.eql 0
          layout.on "render:line:change", (data) ->
            if data.row == 0
              data.html.should.include "hi-constant"
              data.html.should.include "false"
            else if data.row == 1
              data.html.should.include "hi-constant-numeric"
              data.html.should.include "12321"
              done()
          layout.buffer.deleteLine 0
  
  
  describe "#buffer reset", ->
    describe "ignore events", ->
      layout = buildLayout "if false\n  123\nend", 10*15, 7*10, "Ruby"
      layout.scrollTo 0
      layout.buffer.setText "while true\n  puts 'number:\n  123'\nend"
      it "invalidates the lineCache", ->
        layout.lineCache[0].should.include "while"
        should.not.exist layout.lineCache[4]
      
      it "invalidates the tokenCache", ->
        should.not.exist layout.tokenCache[4]
      
      it "resets the contexts", ->
        layout.contexts.should.have.lengthOf 5
        layout.contexts[1].should.have.lengthOf 1
        layout.contexts[2].should.have.lengthOf 2
    
    describe "catching events", ->
      layout = buildLayout "What"
      layout.scrollTo 0
      it "emits 'render'", (done) ->
        layout.on "render", (html) ->
          html.should.match /^<li>/
          html.should.include "Hello"
          done()
        layout.buffer.setText "Hello\nworld"
  
  
  describe "#pointToCoords", ->
    describe "without hard tabs", ->
      layout = buildLayout [1..400].join("\n"), 50*15
      layout.scrollTo 60
      describe "when the point is visible", ->
        point  = layout.buffer.point 100, 2
        coords = layout.pointToCoords point
        it "returns an array", ->
          coords.should.be.an.instanceof Array
        
        it "contains the coordinates", ->
          [top, left] = coords
          top.should.eql 100*15
          left.should.eql 2*7 + 4*7
      
      describe "when the point is not visible", ->
        point  = layout.buffer.point 0, 1
        coords = layout.pointToCoords point
        it "contains the coordinates", ->
          [top, left] = coords
          top.should.eql 0
          left.should.eql 1*7 + 4*7
    
    describe "with hard tabs", ->
      describe "a non-padded hard tab", ->
        layout      = buildLayout "\tCD"
        point       = layout.buffer.point 0, 1
        [top, left] = layout.pointToCoords point
        it "is 8 columns wide", ->
          top.should.eql 0
          left.should.eql 8*7 + 2*7
      
      describe "a 2-padded hard tab", ->
        layout = buildLayout "AB\tCD"
        point       = layout.buffer.point 0, 3
        [top, left] = layout.pointToCoords point
        it "is 6 columns wide", ->
          left.should.eql 8*7 + 2*7
      
      describe "multiple tabs", ->
        layout = buildLayout "AB\t\tCD"
        point       = layout.buffer.point 0, 4
        [top, left] = layout.pointToCoords point
        it "is 6 columns wide", ->
          left.should.eql 16*7 + 2*7
  
  
  describe "#regionToCoords", ->
    describe "a single-line region", ->
      layout = buildLayout [1..100].join("\n"), 50*15
      layout.scrollTo 60
      p1     = layout.buffer.point 100, 2
      p2     = layout.buffer.point 100, 6
      region = new Region p1, p2
      coords = layout.regionToCoords region
      it "returns an object", ->
        coords.should.be.a "object"
      
      it "has the correct 'top'", ->
        coords.top.should.eql 100*15
      
      it "has the correct 'left'", ->
        coords.left.should.eql 2*7 + 4*7
      
      it "has the correct 'width'", ->
        coords.width.should.eql 4*7
      
      it "has the correct 'height'", ->
        coords.height.should.eql 15
  
  
  describe "#coordsToPoint", ->
    layout = buildLayout [1..400].join("\n"), 50*15
    layout.scrollTo 60
    describe "when the point is visible", ->
      point = layout.coordsToPoint 40*15, 2*7
      it "returns a Point", ->
        point.should.be.an.instanceof Point
      
      it "contains the coordinates", ->
        point.row.should.eql 100
        point.col.should.eql 2
    
    describe "when the point is not visible", ->
      point = layout.coordsToPoint -60*15, 1*7
      it "contains the coordinates", ->
        point.row.should.eql 0
        point.col.should.eql 1
    
    describe "when the coordinates are not exact", ->
      it "rounds to the nearest point", ->
        point = layout.coordsToPoint 40*15 + 2, 2*7 - 3
        point.row.should.eql 100
        point.col.should.eql 2
  
  
  describe "#tabWidth", ->
    layout = buildLayout ""
    describe "at the beginning of a line", ->
      it "is 8", ->
        layout.tabWidth(0).should.eql 8
    
    describe "one character in", ->
      it "is 7", ->
        layout.tabWidth(1).should.eql 7
    
    describe "7 characters in", ->
      it "is 1", ->
        layout.tabWidth(7).should.eql 1
    
    describe "8 characters in", ->
      it "is 8", ->
        layout.tabWidth(8).should.eql 8
  
  
  describe "#isTooFarUp", ->
    layout = buildLayout [1..500].join("\n"), 15*10
    layout.scrollTo 20
    describe "a point that is too high", ->
      point = layout.buffer.point 19, 0
      it "is true", ->
        layout.isTooFarUp(point).should.be.true
    
    describe "a visible point", ->
      point = layout.buffer.point 25, 0
      it "is false", ->
        layout.isTooFarUp(point).should.be.false
  
  
  describe "#isTooFarDown", ->
    layout = buildLayout [1..500].join("\n"), 15*10
    layout.scrollTo 20
    describe "a point that is too high", ->
      point = layout.buffer.point 31, 0
      it "is true", ->
        layout.isTooFarDown(point).should.be.true
    
    describe "a visible point", ->
      point = layout.buffer.point 25, 0
      it "is false", ->
        layout.isTooFarDown(point).should.be.false
  
  
  describe "#gutterChars", ->
    it "is the number of characters in the highest line number", ->
      layout = buildLayout [1..123].join("\n")
      layout.gutterChars().should.eql 3
  
  
  describe "#renumber", ->
    layout = buildLayout "Hello\nworld"
    layout.scrollTo 0
    it "emits `gutter:renumber`", (done) ->
      layout.on "gutter:renumber", (range) ->
        range.begin.should.eql 0
        range.end.should.eql 1
        done()
      layout.renumber()



###
describe "MaxTree", ->
  describe "new MaxTree", ->
    describe "when an array is passed", ->
      it "resets the tree", ->
        tree = new MaxTree [2, 4, 6, 3]
        tree.max().should.eql 6
  
  
  describe "#max", ->
    it "is the maximum size", ->
      tree = new MaxTree [9, 4, 5, 6, 7, 8]
      tree.max().should.eql 9
  
  
  describe "#reset", ->
    it "sets the max size", ->
      tree = new MaxTree()
      tree.reset [20, 40, 50, 30]
      tree.max().should.eql 50
  
  
  describe "#insert", ->
    describe "when the size is a new maximum", ->
      tree = new MaxTree [20, 40, 50, 30]
      tree.insert 3, 1000
      it "updates max", ->
        tree.max().should.eql 1000
    
    describe "when the size is not a new maximum", ->
      tree = new MaxTree [20, 40, 50, 30]
      tree.insert 3, 10
      it "does not update max", ->
        tree.max().should.eql 50
    
    describe "insert a new maximum at the beginning", ->
      tree = new MaxTree [5, 4, 2, 7, 6, 2]
      tree.insert 0, 200
      it "updates the max", ->
        tree.max().should.eql 200
  
  
  describe "#delete", ->
    describe "when the size was a maximum", ->
      tree = new MaxTree [20, 40, 50, 30]
      tree.delete 2
      it "update max", ->
        tree.max().should.eql 40
    
    describe "when the size was not a maximum", ->
      tree = new MaxTree [20, 40, 50, 30]
      tree.delete 3
      it "does not update max", ->
        tree.max().should.eql 50
  
  
  describe "#change", ->
    describe "when the size is a new maximum", ->
      tree = new MaxTree [20, 40, 50, 30]
      tree.change 1, 1000
      it "updates the max", ->
        tree.max().should.eql 1000
    
    describe "when the size is not a new maximum", ->
      tree = new MaxTree [20, 40, 50, 30]
      tree.change 1, 4
      it "does not update the max", ->
        tree.max().should.eql 50
    
    describe "when the size of the current max is lowered", ->
      tree = new MaxTree [20, 40, 50, 30]
      tree.change 2, 6
      it "updates the max", ->
        tree.max().should.eql 40

###
