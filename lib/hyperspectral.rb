#!/usr/bin/env ruby

# TODO debug
lib = File.expand_path("..", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "csv"
require "pp"
# require "byebug"
require "fox16"
require "fox16/colors"
require "imzml"
require "matrix"

# load all ruby files from all subdirectories
Dir.glob("{hyperspectral, core_ext}/**/*.rb", &method(:require))

require "core_ext/array"

# TODO debug
if __FILE__ == $0
  Fox::FXApp.new do |app|
    Hyperspectral::MainController.new(app)
    app.create
    app.run
  end
end