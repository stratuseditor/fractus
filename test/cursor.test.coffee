should                  = require 'should'
{Cursor}                = require '../src/cursor'
{Buffer, Point, Region} = require '../src/buffer'

describe "Cursor", ->
  describe "new", ->
    b = new Buffer "Hello"
    c = new Cursor b, 0, 0
    for prop in ["buffer", "point"]
      it "assigns @#{prop}", ->
        c.should.have.property prop
  
  
  describe "#moveVertical", ->
    b = new Buffer "Hello\nworld"
    c = new Cursor b, 0, 2
    c.moveVertical 1
    it "moves the cursor down", ->
      c.point.row.should.eql 1
      c.point.col.should.eql 2
  
  
  describe "#selectVertical", ->
    b = new Buffer "Hello\nworld"
    c = new Cursor b, 0, 2
    c.selectVertical 1
    it "does not move the selection begin", ->
      c.region.begin.row.should.eql 0
      c.region.begin.col.should.eql 2
    
    it "moves the selection end down", ->
      c.region.end.row.should.eql 1
      c.region.end.col.should.eql 2
  
  
  describe "#moveLeft", ->
    b = new Buffer "Hello\nworld"
    c = new Cursor b, 0, 2
    c.moveLeft()
    it "moves the cursor left", ->
      c.point.row.should.eql 0
      c.point.col.should.eql 1
  
  
  describe "#selectLeft", ->
    b = new Buffer "Hello\nworld"
    c = new Cursor b, 0, 2
    c.selectLeft()
    it "moves the selection left", ->
      c.region.begin.row.should.eql 0
      c.region.begin.col.should.eql 2
      c.region.end.row.should.eql 0
      c.region.end.col.should.eql 1
  
  
  describe "#newLine", ->
    b = new Buffer "Hello\nworld"
    c = new Cursor b, 0, 3
    c.newLine()
    it "splits the line", ->
      b.text().should.eql "Hel\nlo\nworld"
  
  
  describe "#deleteSelection", ->
    b = new Buffer "Hello\nworld"
    c = new Cursor b, 0, 2
    c.selectTo 1, 2
    c.deleteSelection()
    it "deletes the selection", ->
      b.text().should.eql "Herld"
    
    it "collapses to the cursor", ->
      c.region.begin.row.should.eql 0
      c.region.begin.col.should.eql 2
      c.region.end.row.should.eql 0
      c.region.end.col.should.eql 2
  
  
  describe "#deleteRows", ->
    describe "single row", ->
      b = new Buffer "123\n456\n789"
      c = new Cursor b, 1, 2
      c.deleteRows()
      it "deletes the line", ->
        b.text().should.eql "123\n789"
      
      it "does not move the cursor", ->
        c.point.row.should.eql 1
        c.point.col.should.eql 2
    
    describe "multiple rows", ->
      b = new Buffer "123\n456\n789\nabc"
      c = new Cursor b, 1, 2
      c.selectTo 2, 3
      c.deleteRows()
      it "deletes the line", ->
        b.text().should.eql "123\nabc"
      
      it "collapses to the cursor", ->
        c.point.row.should.eql 1
        c.point.col.should.eql 2
    
    describe "the last line", ->
      b = new Buffer "123"
      c = new Cursor b, 0, 2
      c.deleteRows()
      it "emptys the line", ->
        b.text().should.eql ""
  
  
  describe "#text", ->
    b = new Buffer "Hello\nworld"
    describe "as a point", ->
      c = new Cursor b, 0, 2
      it "is ''", ->
        c.text().should.eql ""
    
    describe "a region", ->
      c = new Cursor b, 0, 2
      c.selectTo 1, 3
      it "has the correct test", ->
        c.text().should.eql "llo\nwor"
