require './document'
require './parser'
require './obo'
require 'gnuplot'
require 'rmagick'

module IMZML

  class Metadata

    attr_accessor :saving_type
    attr_accessor :uuid
    attr_accessor :sha1

    attr_accessor :pixel_count_x
    attr_accessor :pixel_count_y

    attr_accessor :pixel_size_x
    attr_accessor :pixel_size_y

    attr_accessor :spectrums

    def initialize

      @spectrums = Array.new

    end


    def save_image(image_name, data_path, mz_value, interval)

      p "Finding intensities"
      data = Array.new
      @spectrums.each do |spectrum|
        data << spectrum.intensity(data_path, mz_value, interval)
      end

      max_normalized = data.max - data.min
      step = 255.0 / max_normalized

      f = Magick::Image.new(@pixel_count_x, @pixel_count_y)

      p "Creating image"
      i = 0
      row = column = 0
      data.each do |value|
        f.pixel_color(column, row, Magick::Pixel.from_hsla(0,0, step * (value - data.min)))
        column += 1
        if (column >= @pixel_count_y)
          row += 1
          column = 0
        end
      end

      f.write(image_name)
    end

  end

  class Spectrum

    attr_accessor :id
    attr_accessor :mz_array_external_offset
    attr_accessor :mz_array_external_encoded_length
    attr_accessor :intensity_array_external_offset
    attr_accessor :intensity_array_external_encoded_length

    def intensity(data_path, at, interval)
      mz_array = mz_array(data_path)
      intensity_array = intensity_array(data_path)

      low_value = search_binary(mz_array, at - interval)
      low_index = mz_array.index(low_value)
      high_value = search_binary(mz_array, at + interval)
      high_index = mz_array.index(high_value)

      # p "#{mz_array[low_index..high_index]} - #{intensity_array[low_index..high_index]}"

      intensity_array[low_index..high_index].inject{|sum, x| sum + x}
    end

    def search_binary(array, value, first = true)

      if (array.size > 2)
        middle_index = array.size/2
        middle = array[middle_index]

        if (middle > value)
          search_binary(array[0..middle_index], value, first)
        else
          search_binary(array[middle_index..array.size], value, first)
        end
      else
        if first
          array.first
        else
          array.last
        end
      end

    end

    def search_last(array, value)

    end

    def mz_array(data_path)
      IO.binread(data_path, @mz_array_external_encoded_length.to_i, @mz_array_external_offset.to_i).unpack("e*")
    end

    def intensity_array(data_path)
      IO.binread(data_path, @intensity_array_external_encoded_length.to_i, @intensity_array_external_offset.to_i).unpack("e*")
    end

    def save_spectrum_graph(data_path)

      Gnuplot.open do |gp|
        Gnuplot::Plot.new( gp ) do |plot|

          graph_name = "#{@id.delete('=')}"
          plot.title  "Spectrum #{graph_name}"
          plot.ylabel "intensity"
          plot.xlabel "m/z"

          plot.terminal "png size 1024, 480"

          p "Graph name \"#{graph_name}\""
          plot.output File.expand_path("./graph_#{graph_name}.png")

          x = mz_array(data_path)
          y = intensity_array(data_path)

          plot.data << Gnuplot::DataSet.new( [x, y] ) do |ds|
            ds.with = "lines"
            ds.notitle
          end
        end
      end

    end

  end

end


if __FILE__ == $0

  # Working example
  path = "../imzML/example_files/"
  filename = "Example_Continuous"
  # path = "../imzML/test_files/"
  # filename = "testovaci_blbost"
  imzml_path = "#{path}#{filename}.imzML"
  ibd_path = "#{path}#{filename}.ibd"

  doc = IMZML::Document.new
  parser = IMZML::Parser.new(doc)
  parser.parse_file(imzml_path)
  imzml = doc.metadata
  p "Checksum equals" if IO.binread(ibd_path, 16).unpack("H*").first.upcase == imzml.uuid.upcase

  # save spectrum to images
  # imzml.spectrums.each do |spectrum|
  #   p spectrum.intensity(ibd_path, 151.9, 0.25)
  #   spectrum.save_spectrum_graph(ibd_path)
  # end

  # save image
  imzml.save_image("image.png", ibd_path, 151.9, 0.25)

end