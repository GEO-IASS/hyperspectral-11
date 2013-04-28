require 'ox'
require './imzml'
require './spectrum'
require './obo'

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
        # when IMZML::OBO::IMS::LINESCAN_SEQUENCE_BOTTOM_UP then @metadata.linescan_sequence = accession.to_s
        # when IMZML::OBO::IMS::LINESCAN_SEQUENCE_BOTTOM_UP then @metadata.linescan_sequence = accession.to_s
        # when IMZML::OBO::IMS::LINESCAN_SEQUENCE_TOP_DOWN then @metadata.linescan_sequence = accession.to_s
        # when IMZML::OBO::IMS::LINESCAN_SEQUENCE_LEFT_RIGHT then @metadata.linescan_sequence = accession.to_s
        # when IMZML::OBO::IMS::LINESCAN_SEQUENCE_RIGHT_LEFT then @metadata.linescan_sequence = accession.to_s
        # when IMZML::OBO::IMS::LINESCAN_SEQUENCE_NO_DIRECTION then @metadata.linescan_sequence = accession.to_s
        # when IMZML::OBO::IMS::SCAN_PATTERN_MEANDERING then @metadata.scan_pattern = accession.to_s
        # when IMZML::OBO::IMS::SCAN_PATTERN_RANDOM_ACCESS then @metadata.scan_pattern = accession.to_s
        # when IMZML::OBO::IMS::SCAN_PATTERN_FLYBACK then @metadata.scan_pattern = accession.to_s
        # when IMZML::OBO::IMS::SCAN_TYPE_HORIZONTAL_LINE_SCAN then @metadata.scan_type = accession.to_s
        # when IMZML::OBO::IMS::SCAN_TYPE_VERTICAL_LINE_SCAN then @metadata.scan_type = accession.to_s
        # when IMZML::OBO::IMS::LINE_SCAN_DIRECTION_LINESCAN_RIGHT_LEFT then @metadata.line_scan_direction = accession.to_s
        # when IMZML::OBO::IMS::LINE_SCAN_DIRECTION_LINESCAN_LEFT_RIGHT then @metadata.line_scan_direction = accession.to_s
        end
      end
      
      if @in_spectrum && @in_scan_list && @in_scan
        case accession
        when IMZML::OBO::IMS::SPECTRUM_POSITION_X then @current_position_x = value.to_i - 1
        when IMZML::OBO::IMS::SPECTRUM_POSITION_Y then @current_position_y = value.to_i - 1
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
    when :scanList then @in_scan_list = true
    when :scanSettings then @in_scan_settings = true
    when :scan then @in_scan = true
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

      # create new empty array
      @metadata.spectrums = Array.new(@metadata.pixel_count_x * @metadata.pixel_count_y) if !@metadata.spectrums

      # save spectrum data to the right position
      position = @metadata.pixel_count_x * @current_position_y + @current_position_x
      @metadata.spectrums[position] = @spectrum
      
      # reset positions
      @current_position_x, @current_position_y = nil, nil

    when :spectrumList then @in_spectrum_list = false
    when :scanSettings then @in_scan_settings = false
    when :scanList then @in_scan_list = false
    when :scan then @in_scan = false
    when :fileDescription then @in_file_description = false
    when :fileContent then @in_file_content = false
    when :referenceableParamGroupList then @in_reference_param_group_list = false
    when :referenceableParamGroup then @in_referenceable_param_group = @in_mz_array = @in_intensity_array = false
    when :referenceableParamGroupRef then @in_referenceable_param_group_ref = false
    when :binaryDataArrayList then @in_binary_data_array_list = false
    end

  end

end