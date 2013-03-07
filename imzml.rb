require './document'
require './parser'
require 'gnuplot'

module IMZML

  class Metadata

    attr_accessor :uuid
    attr_accessor :sha1

    attr_accessor :pixel_count_x
    attr_accessor :pixel_count_y

    attr_accessor :pixel_size_x
    attr_accessor :pixel_size_y

  end

end


if __FILE__ == $0

  # Working example
  path = "../imzML/example_files/"
  filename = "Example_Continuous"
  imzml_path = "#{path}#{filename}.imzML"
  ibd_path = "#{path}#{filename}.ibd"

  doc = IMZML::Document.new
  parser = IMZML::Parser.new(doc)
  parser.parse_file(imzml_path)
  doc.metadata
  p "Checksum equals" if IO.binread(ibd_path, 16).unpack("H*").first.upcase == doc.metadata.uuid.upcase
  mz_array = IO.binread(ibd_path, 33596, 16).unpack("l*")
  intensity_array = IO.binread(ibd_path, 33596, 33612).unpack("l*")
  Gnuplot.open do |gp|
    Gnuplot::Plot.new( gp ) do |plot|

      plot.title  "Spectrum"
      plot.ylabel "intensity"
      plot.xlabel "m/z"

      plot.terminal "png size 1024, 480"
      plot.output File.expand_path("./graph.png")

      x = mz_array
      y = intensity_array

      plot.data << Gnuplot::DataSet.new( [x, y] ) do |ds|
        ds.with = "lines"
        ds.notitle
      end
    end
  end

end