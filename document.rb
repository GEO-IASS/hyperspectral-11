require 'nokogiri'

module IMZML

  class Document < Nokogiri::XML::SAX::Document

    attr_accessor :in_reference_param_group_list
    attr_accessor :in_referenceable_param_group
    attr_accessor :in_referenceable_param_group_ref
    attr_accessor :attr_names
    attr_accessor :in_mz_array
    attr_accessor :in_file_description
    attr_accessor :in_file_content
    attr_accessor :in_scan_settings
    attr_accessor :in_spectrum_list
    attr_accessor :in_spectrum

    attr_accessor :spectrum
    attr_accessor :continuous_mz_array_external_offset
    attr_accessor :continuous_mz_array_external_encoded_length

    attr_accessor :metadata

    def end_element(name)

      case name
      when "binaryDataArray" then @in_mz_array = @in_intensity_array = false
      when "spectrum"
        @in_spectrum = false

        if @metadata.saving_type == IMZML::OBO::IMS::CONTINUOUS

          # save or fill mz array positions
          if @spectrum.mz_array_external_offset && @spectrum.mz_array_external_encoded_length
            @continuous_mz_array_external_offset, @continuous_mz_array_external_encoded_length = @spectrum.mz_array_external_offset, @spectrum.mz_array_external_encoded_length
          else
            @spectrum.mz_array_external_offset, @spectrum.mz_array_external_encoded_length = @continuous_mz_array_external_offset, @continuous_mz_array_external_encoded_length
          end

        end

        @metadata.spectrums << @spectrum

      when "spectrumList" then @in_spectrum_list = false
      when "scanSettings" then @in_scan_settings = false
      when "fileDescription" then @in_file_description = false
      when "fileContent" then @in_file_content = false
      when "referenceableParamGroupList" then @in_reference_param_group_list = false
      when "referenceableParamGroup" then @in_referenceable_param_group = @in_mz_array = @in_intensity_array = false
      end

    end

    def start_document
      @metadata = IMZML::Metadata.new
    end

    def start_element(name, attrs = [])

      case name
      when "spectrum"

        @in_spectrum = true
        @spectrum = IMZML::Spectrum.new
        @spectrum.id = attrs.assoc("id").last

      when "spectrumList" then @in_spectrum_list = true
      when "scanSettings" then @in_scan_settings = true
      when "fileDescription" then @in_file_description = true
      when "fileContent" then @in_file_content = true
      when "referenceableParamGroupList" then @in_reference_param_group_list = true
      when "referenceableParamGroup"
        @in_referenceable_param_group = true

        case attrs.assoc("id").last
        when "mzArray" then @in_mz_array = true
        when "intensityArray" then @in_intensity_array = true
        end

      when "referenceableParamGroupRef"
        @in_referenceable_param_group_ref = true

        case attrs.assoc("ref").last
          when "mzArray" then @in_mz_array = true
          when "intensityArray" then @in_intensity_array = true
        end

      when "cvParam"

        value = attrs.assoc("value").last
        accession = attrs.assoc("accession").last

        if @in_scan_settings

          case accession
          when IMZML::OBO::IMS::MAX_COUNT_OF_PIXELS_X then @metadata.pixel_count_x = value.to_i
          when IMZML::OBO::IMS::MAX_COUNT_OF_PIXELS_Y then @metadata.pixel_count_y = value.to_i
          when IMZML::OBO::IMS::PIXEL_SIZE then @metadata.pixel_size_x = value.to_i
          when IMZML::OBO::IMS::IMAGE_SHAPE then @metadata.pixel_size_y = value.to_i # FIXME probably error in obo definition file, should be pixel size y
          end

        end

        if @in_referenceable_param_group && @in_reference_param_group_list

          if accession == IMZML::OBO::MS::FLOAT_32_BIT

            # p case
            # when @in_mz_array then ">> MZ array"
            # when @in_intensity_array then ">> Intensity array"
            # end

          end

        end

        if @in_file_description && @in_file_content

          case accession
          when IMZML::OBO::IMS::UNIVERSALLY_UNIQUE_IDENTIFIER
            uuid = attrs.assoc("value").last.to_s.delete("{}-")
            @metadata.uuid = uuid
          when IMZML::OBO::IMS::CONTINUOUS then @metadata.saving_type = accession
          when IMZML::OBO::IMS::PROCESSED then @metadata.saving_type = accession
          end

        end

        if @in_spectrum_list && @in_spectrum

          type = "mz" if @in_mz_array
          type = "intensity" if @in_intensity_array

          case accession
          when IMZML::OBO::IMS::EXTERNAL_OFFSET then @spectrum.send("#{type}_array_external_offset=", value)
          when IMZML::OBO::IMS::EXTERNAL_ENCODED_LENGTH then @spectrum.send("#{type}_array_external_encoded_length=", value)
          end

        end

      end

    end

  end

end