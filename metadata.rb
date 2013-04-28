require './spectrum'

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

    def image_data(data_path, mz_value, interval)
      
      # PerfTools::CpuProfiler.start("/tmp/finding_intensities") do

      data = Array.new
      @spectrums.each do |spectrum|
        data << spectrum.intensity(data_path, mz_value, interval)
        yield spectrum.id
      end
      
      # end
      data
    end

  end
end