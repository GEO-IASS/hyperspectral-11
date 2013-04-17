require './obo'
require './ox'
require 'gnuplot'
require 'chunky_png'
require 'perftools'

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

    def image_data(data_path, mz_value, interval)

      print "\nFinding intensities ... "

      start = Time.now
      data = Array.new
      # PerfTools::CpuProfiler.start("/tmp/finding_intensities") do
        @spectrums.each do |spectrum|
          data << spectrum.intensity(data_path, mz_value, interval)
        end
      # end
      print "#{Time.now - start}s"

      # start = Time.now
#       max_normalized = data.max - data.min
#       min = data.min
#       step = 255.0 / max_normalized
#
      data

      #
      # f = ChunkyPNG::Image.new(@pixel_count_x, @pixel_count_y)
      #
      # start = Time.now
      # print "\nCreating image #{@pixel_count_x}x#{@pixel_count_y} ... "
      #
      # # PerfTools::CpuProfiler.start("/tmp/creating_image") do
      #
      # row, column, i = 0, 0, 0
      # direction_right = true
      # data.each do |value|
      #   # p value
      #   # p "#{column}, #{row}"
      #   color_value = step * (value - min)
      #   f[column, row] = ChunkyPNG::Color.grayscale(color_value.to_i)
      #   direction_right ? column += 1 : column -= 1
      #
      #   if (column >= @pixel_count_x || column < 0)
      #     row += 1
      #
      #     direction_right = (row % 2 == 0)
      #     # direction_right = true
      #     direction_right ? column = 0 : column -= 1
      #   end
      # end
      #
    end

    def generate_image(filename, data_path, mz_value, interval)

      print "\nFinding intensities ... "

      start = Time.now
      data = Array.new
      # PerfTools::CpuProfiler.start("/tmp/finding_intensities") do
        @spectrums.each do |spectrum|
          data << spectrum.intensity(data_path, mz_value, interval)
        end
      # end
      print "#{Time.now - start}s"

      start = Time.now
      max_normalized = data.max - data.min
      min = data.min
      step = 255.0 / max_normalized

      f = ChunkyPNG::Image.new(@pixel_count_x, @pixel_count_y)

      start = Time.now
      print "\nCreating image #{@pixel_count_x}x#{@pixel_count_y} ... "

      # PerfTools::CpuProfiler.start("/tmp/creating_image") do

      row, column, i = 0, 0, 0
      direction_right = true
      data.each do |value|
        # p value
        # p "#{column}, #{row}"
        color_value = step * (value - min)
        f[column, row] = ChunkyPNG::Color.grayscale(color_value.to_i)
        direction_right ? column += 1 : column -= 1

        if (column >= @pixel_count_x || column < 0)
          row += 1

          direction_right = (row % 2 == 0)
          # direction_right = true
          direction_right ? column = 0 : column -= 1
        end
      end

      # end

      print "#{Time.now - start}s"

      filename ||= "image.png"
      f.save("#{filename}.png", :interlace => true)
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

      sum = low_value
      i = 0
      high_mz_value = low_value

      # try to find high value by adding, not with binary search
      # p "high #{high_mz_value} compare #{at + interval} from #{i} sum #{sum}"
      # while high_mz_value < (at + interval)
      #   high_mz_value = mz_array[low_index + i]
      #   sum += high_mz_value
      #   i += 1
      # end
      #
      # p sum
      # sum

      high_value = search_binary(mz_array, at + interval)
      high_index = mz_array.index(high_value)

      intensity_array[low_index..high_index].inject{|sum, x| sum + x}
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

  end

end


if __FILE__ == $0

  # Working example
  # path, filename, mz, interval = "../imzML/example_files/", "Example_Continuous", 151.9, 0.25
  # path, filename, mz, interval = "../imzML/example_files/", "Example_Processed", 151.9, 0.25
  path, filename, mz, interval = "../imzML/test_files/", "testovaci_blbost", 2568.0, 0.1
  # path, filename, mz, interval = "../imzML/s042_continuous/", "S042_Continuous", 157.2, 0.25
  # path, filename, mz, interval = "../imzML/s043_processed/", "S043_Processed", 152.9, 0.5
  # path, filename, mz, interval = "../imzML/test_files/", "20121220_LIN_100x100_1mmScan_PAPER_0018_spot5_1855", 2561.5, 5.6
  # path, filename, mz, interval = "../imzML/test_files/", "20130115_lin_range_10row_100vdef_0V_DOBRA_144327", 2533.3, 3.6
  imzml_path = "#{path}#{filename}.imzML"
  ibd_path = "#{path}#{filename}.ibd"

  # parse with Ox
  start = Time.now
  print "Parsing imzML file \"#{filename}.imzML\" with Ox ... "
  any = ImzMLParser.new()
  # PerfTools::CpuProfiler.start("/tmp/ox") do
  File.open(imzml_path, 'r') do |f|
    Ox.sax_parse(any, f)
  end
  #end
  imzml = any.metadata
  print "#{Time.now - start}s"

  # TODO create some tests
  # print "\nPASS checksum equals" if IO.binread(ibd_path, 16).unpack("H*").first.upcase == imzml.uuid.upcase

  # save spectrum to images
  imzml.spectrums.each{|spectrum| spectrum.save_spectrum_graph(ibd_path)}

  # save image
  imzml.generate_image(filename, ibd_path, mz, interval)

  print "\n"

end