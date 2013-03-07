##### Working example
# path = "../imzML/example_files/"
# filename = "Example_Continuous"
# imzml_path = "#{path}#{filename}.imzML"
# ibd_path = "#{path}#{filename}.ibd"
#
# doc = IMZML::Document.new
# parser = Nokogiri::XML::SAX::Parser.new(doc)
# parser.parse_file(imzml_path)
# doc.metadata
# IO.binread(ibd_path, 16).unpack("H*").first.upcase == doc.metadata.uuid.upcase
# mz_array = IO.binread(ibd_path, 33596, 16).unpack("l*")
# intensity_array = IO.binread(ibd_path, 33596, 33612).unpack("l*")
# Gnuplot.open do |gp|
#   Gnuplot::Plot.new( gp ) do |plot|
#
#     plot.title  "Spectrum"
#     plot.ylabel "intensity"
#     plot.xlabel "m/z"
#
#     plot.terminal "png size 8192, 480"
#     plot.output File.expand_path("/tmp/graph.png", __FILE__)
#
#     x = mz_array
#     y = intensity_array
#
#     plot.data << Gnuplot::DataSet.new( [x, y] ) do |ds|
#       ds.with = "lines"
#       ds.notitle
#     end
#   end
# end

require 'nokogiri'

module IMZML

  class Document < Nokogiri::XML::SAX::Document

    attr_accessor :in_reference_param_group_list
    attr_accessor :in_referenceable_param_group
    attr_accessor :in_mz_array
    attr_accessor :in_file_description
    attr_accessor :in_file_content
    attr_accessor :in_scan_settings

    attr_accessor :metadata

    def end_document
      p "End parsing"
    end

    def end_element(name)

      case name
      when "scanSettings"
        @in_scan_settings = false
      when "fileDescription"
        @in_file_description = false
      when "fileContent"
        @in_file_content = false
      when "referenceableParamGroupList"
        @in_reference_param_group_list = false
      when "referenceableParamGroup"
        @in_referenceable_param_group = false
        @in_mz_array = false
        @in_intensity_array = false
      end

    end

    def start_document
      p "Start parsing"
      @metadata = IMZML::Metadata.new
    end

    def start_element(name, attrs = [])

      case name
      when "scanSettings"
        @in_scan_settings = true
      when "fileDescription"
        @in_file_description = true
      when "fileContent"
        @in_file_content = true
      when "referenceableParamGroupList"
        @in_reference_param_group_list = true
      when "referenceableParamGroup"
        @in_referenceable_param_group = true

        id = attrs.assoc("id")
        case id.last
        when "mzArray"
          @in_mz_array = true
        when "intensityArray"
          @in_intensity_array = true
        end
      when "cvParam"

        if @in_scan_settings

          attr_value = attrs.assoc("value").last
          accession_value = attrs.assoc("accession").last

          case accession_value
          when "IMS:1000042"
            @metadata.pixel_count_x = attr_value.to_i
          when "IMS:1000043"
            @metadata.pixel_count_y = attr_value.to_i
          when "IMS:1000046"
            @metadata.pixel_size_x = attr_value.to_i
          when "IMS:1000047"
            @metadata.pixel_size_y = attr_value.to_i
          end

        end

        if @in_referenceable_param_group && @in_reference_param_group_list
          if attrs.assoc("accession").last == "MS:1000521"
            case
            when @in_mz_array
              p "MZ array"
            when @in_intensity_array
              p "Intensity array"
            end
            p attrs.assoc("name").last
          end
        end

        if @in_file_description && @in_file_content
          if attrs.assoc("accession").last == "IMS:1000080"
            uuid = attrs.assoc("value").last.to_s.delete("{}-")
            @metadata.uuid = uuid
          end
        end

      end

    end

  end

end