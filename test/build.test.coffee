should = require 'should'
bundle     = require 'stratus-bundle'
bundleDir  = require.resolve("stratus-bundle").split("/")[0..-2].join("/")
bundle.dir = "#{bundleDir}/test/cases"
build  = require '../src/build'


buildFractus = ->
  return build(langs: ["Ruby"], theme: "Idlefingers")

describe "build", ->
  describe "()", ->
    it "sets a default theme", ->
      build(langs: ["Ruby"]).theme.should.eql "Idlefingers"
    
    it "includes extended languages", ->
      build(langs: ["Ruby.Rails.Model"]).langs.should.include "Ruby"
    
    #it "includes required languages", ->
    #  build(langs: ["HTML"]).langs.should.include "CSS"
  
  
  describe "#js", ->
    describe "without a file", ->
      js = buildFractus().js()
      it "is a string", ->
        js.should.be.a "string"
        js.should.include "fractus"
      
      it "includes the given bundles", ->
        js.should.include "Ruby"
        js.should.include "sentientwaffle"
      
      it "does not include other bundles", ->
        js.should.not.include "Ruby.Rails"
      
      it "includes jQuery", ->
        js.should.include "jquery.org/license"
      
      it "includes Underscore.js", ->
        js.should.include "(c) 2009-2012 Jeremy Ashkenas"
    
    describe "dont include jQuery", ->
      fractus = build
        langs:  ["Ruby"]
        jquery: false
      
      it "excludes jQuery", ->
        fractus.js().should.not.include "jquery.org/license"
  
  
  describe "#css", ->
    describe "without a file", ->
      css = null
      before (done) ->
        buildFractus().css (err, _css) ->
          throw err if err
          css = _css
          done()
      
      it "is a string", ->
        css.should.be.a "string"
      
      it "includes the Fractus css", ->
        css.should.include ".fractus"
      
      it "includes the theme", ->
        css.should.include ".hi-keyword"
