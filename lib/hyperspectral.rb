#!/usr/bin/env ruby

# TODO debug
lib = File.expand_path("..", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "csv"
require "pp"
# require "byebug"
require "fox16"
require "imzml"

require "hyperspectral"
require "hyperspectral/fox"
require "hyperspectral/peak_detector"
require "hyperspectral/smoothing/moving_average"
require "hyperspectral/smoothing/savitzky_golay"

require "hyperspectral/ui/spectrum_canvas"
require "hyperspectral/ui/main_window"
require "hyperspectral/ui/menu_bar"

# TODO debug
if __FILE__ == $0
  Fox::FXApp.new do |app|
    Hyperspectral::Reader.new(app)
    app.create
    app.run
  end
end