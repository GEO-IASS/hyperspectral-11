require './obo'
require './ox'
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

      print "Finding intensities ... "

      start = Time.now
      data = Array.new
      # PerfTools::CpuProfiler.start("/tmp/finding_intensities") do
        @spectrums.each do |spectrum|
          data << spectrum.intensity(data_path, mz_value, interval)
        end
      # end
      print "#{Time.now - start}s\n"

      data
    end

  end

  class Spectrum

    attr_accessor :id
    attr_accessor :mz_array_external_offset
    attr_accessor :mz_array_external_encoded_length
    attr_accessor :intensity_array_external_offset
    attr_accessor :intensity_array_external_encoded_length

    def intensity(data_path, at, interval)

      raise "Interval cannot be nil" if !interval

      # read array and intensity data
      mz_array = mz_array(data_path)
      intensity_array = intensity_array(data_path)

      default_from, default_to = mz_array.first, mz_array.first

      # find designated intensity
      if !at
        from = default_from
        to = default_to
      else
        from = at - interval
        from = default_from if from < 0
        to = at + interval
        to = default_to if to > mz_array.last
      end

      # find values in mz array
      low_value = search_binary(mz_array, from)
      low_index = mz_array.index(low_value)
      high_value = search_binary(mz_array, to)
      high_index = mz_array.index(high_value)

      # sum all values in subarray
      intensity_array[low_index..high_index].inject{|sum, x| sum + x}
    end

    def mz_array(data_path)
      IO.binread(data_path, @mz_array_external_encoded_length.to_i, @mz_array_external_offset.to_i).unpack("e*")
    end

    def intensity_array(data_path)
      IO.binread(data_path, @intensity_array_external_encoded_length.to_i, @intensity_array_external_offset.to_i).unpack("e*")
    end

    private

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