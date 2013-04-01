require 'ox'

class ImzMLParser < ::Ox::Sax

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
  attr_accessor :in_cv_param
  attr_accessor :accession_attribute
  attr_accessor :in_value_attribute
  attr_accessor :in_binary_data_array_list

  attr_accessor :spectrum
  attr_accessor :continuous_mz_array_external_offset
  attr_accessor :continuous_mz_array_external_encoded_length

  attr_accessor :metadata

  def initialize()
    @metadata = IMZML::Metadata.new
  end

  def attr(name, str)

    # p "attr #{name}=#{str}"

    case name

    when :ref
      if @in_referenceable_param_group_ref
        case str
        when "mzArray" then @in_mz_array = true
        when "intensityArray" then @in_intensity_array = true
        end
      end
    when :id

      if @in_spectrum
        @spectrum.id = str
      end

      if @in_referenceable_param_group
        case str
        when "mzArray" then @in_mz_array = true
        when "intensityArray" then @in_intensity_array = true
        end
      end

    when :accession then @accession_attribute = str
    when :value

      accession = @accession_attribute
      value = str

      if @in_scan_settings
        case accession
        when IMZML::OBO::IMS::MAX_COUNT_OF_PIXELS_X then @metadata.pixel_count_x = value.to_i
        when IMZML::OBO::IMS::MAX_COUNT_OF_PIXELS_Y then @metadata.pixel_count_y = value.to_i
        when IMZML::OBO::IMS::PIXEL_SIZE then @metadata.pixel_size_x = 1 # FIXME not used properly value.to_i
        when IMZML::OBO::IMS::IMAGE_SHAPE then @metadata.pixel_size_y = 1 # value.to_i # FIXME probably error in obo definition file, should be pixel size y
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
          uuid = value.delete("{}-")
          @metadata.uuid = uuid
        when IMZML::OBO::IMS::CONTINUOUS then @metadata.saving_type = accession
        when IMZML::OBO::IMS::PROCESSED then @metadata.saving_type = accession
        end

      end

      if @in_spectrum_list && @in_spectrum && @in_binary_data_array_list

        type = "mz" if @in_mz_array
        type = "intensity" if @in_intensity_array

        # p "TYPE: #{type}"

        # FIXME
        case accession
        when IMZML::OBO::IMS::EXTERNAL_OFFSET then @spectrum.send("#{type}_array_external_offset=", value)
        when IMZML::OBO::IMS::EXTERNAL_ENCODED_LENGTH then @spectrum.send("#{type}_array_external_encoded_length=", value)
        end

      end

    end


  end

  def start_element(name)

    # p "in #{name}"

    case name
    when :spectrum

      @in_spectrum = true
      @spectrum = IMZML::Spectrum.new

    when :spectrumList then @in_spectrum_list = true
    when :scanSettings then @in_scan_settings = true
    when :fileDescription then @in_file_description = true
    when :fileContent then @in_file_content = true
    when :referenceableParamGroupList then @in_reference_param_group_list = true
    when :referenceableParamGroup then @in_referenceable_param_group = true
    when :referenceableParamGroupRef then @in_referenceable_param_group_ref = true
    when :cvParam then @in_cv_param = true
    when :binaryDataArrayList then @in_binary_data_array_list = true
    end

  end

  def end_element(name)

    # p "out #{name}"

    case name
    when :cvParam then @in_cv_param = false
    when :binaryDataArray then @in_mz_array = @in_intensity_array = false
    when :spectrum
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

    when :spectrumList then @in_spectrum_list = false
    when :scanSettings then @in_scan_settings = false
    when :fileDescription then @in_file_description = false
    when :fileContent then @in_file_content = false
    when :referenceableParamGroupList then @in_reference_param_group_list = false
    when :referenceableParamGroup then @in_referenceable_param_group = @in_mz_array = @in_intensity_array = false
    when :referenceableParamGroupRef then @in_referenceable_param_group_ref = false
    when :binaryDataArrayList then @in_binary_data_array_list = false
    end

  end

end