## Working example
# path = "../imzML/example_files/"
# filename = "Example_Continuous"
# imzml_path = "#{path}#{filename}.imzML"
# ibd_path = "#{path}#{filename}.ibd"
#
# doc = IMZML::Document.new
# parser = Nokogiri::XML::SAX::Parser.new(doc)
# parser.parse_file(imzml_path)
# IO.binread(ibd_path, 16).unpack("H*").first.upcase == doc.metadata.uuid.upcase

require './imzml'
require 'nokogiri'

module IMZML

  class Document < Nokogiri::XML::SAX::Document

    attr_accessor :in_reference_param_group_list
    attr_accessor :in_referenceable_param_group
    attr_accessor :in_mz_array
    attr_accessor :in_file_description
    attr_accessor :in_file_content

    attr_accessor :metadata

    def end_document
      p "End parsing"
    end

    def end_element(name)

      case name
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
    end

    def start_element(name, attrs = [])

      case name
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

  class Parser < Nokogiri::XML::SAX::Parser

  end

end