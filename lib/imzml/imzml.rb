require 'ox'

require_relative '../core_ext/string'

require_relative 'cv'
require_relative 'cv_param'
require_relative 'file_description'
require_relative 'file_description/file_content'

module ImzML
  
  class ImzML < ::Ox::Sax
    
    ###############################################
    # ATTRIBUTES
    ###############################################
    
    attr_accessor :accession
    
    attr_accessor :id
    
    attr_accessor :version
    
    ###############################################
    # SUBELEMENTS
    ###############################################
    
    # (required) an array of ImzML::ImzML::CV objects
    attr_accessor :cvs

    # (required) an ImzML::ImzML::FileDescription
    attr_accessor :file_description

    # (optional) an array of CV::ReferenceableParamGroup objects
    attr_accessor :referenceable_param_groups

    # (optional) an array of ImzML::ImzML::Sample objects
    attr_accessor :samples

    # (required) an array of ImzML::ImzML::Software objects 
    attr_accessor :software_list

    # (optional) an array of ImzML::ImzML::ScanSettings objects
    attr_accessor :scan_settings_list

    # (required) an array of ImzML::ImzML::InstrumentConfiguration objects
    attr_accessor :instrument_configurations

    # (required) an array of ImzML::ImzML::DataProcessing objects
    attr_accessor :data_processing_list

    # (required) an ImzML::ImzML::Run object
    attr_accessor :run
    
    ###############################################
    # ADDITIONAL
    ###############################################
    
    # the io object of the mzml file
    attr_accessor :io

    # xml file encoding
    attr_accessor :encoding
    
    def initialize(filepath, &block)
      # open file
      File.open(filepath, 'r') do |f|
        Ox.sax_parse(self, f)
      end
      block.call(self)
    end
    
    ###############################################
    # SAX
    ###############################################
    
    def start_element(name)
      instance_variable_set("@in_#{name.to_s.underscore}".to_sym, true)
      
      if @in_cv_list
        if @in_cv
          @cvs ||= []
          @_cv ||= Cv.new
        end
      end
      
      if @in_file_description
        if @in_file_content
          if @in_cv_param
            @file_description ||= FileDescription.new
            @_file_content ||= FileContent.new
            @_cv_param ||= CvParam.new
          end
        end
      end
      
    end
    
    def end_element(name)
      if @in_cv_list
        if @in_cv
          @cvs << @_cv
          @_cv = nil
        end
      end
      
      if @in_file_description
        if @in_file_content      
          if @in_cv_param
            @_file_content.cv_params ||= []
            @_file_content.cv_params << @_cv_param
            @_cv_param = nil
          else
            @file_description.file_content = @_file_content
            @_file_content = nil
          end
        end
      end
      
      instance_variable_set("@in_#{name.to_s.underscore}".to_sym, false)
      
      # remove temporary and hel variables
      if !@in_mz_ml
        # p instance_variables
        instance_variables.each{|x| remove_instance_variable(x) if x.to_s[0..3] == "@in_" || x.to_s[0..1] == "@_"}
        # p instance_variables
      end
    end
    
    def attr(name, str)

      name = "@#{name.to_s.underscore}".to_sym

      if @in_cv_list
        if @in_cv
          @_cv.instance_variable_set(name, str)
        end
      end
      
      if @in_file_description
        if @in_file_content      
          if @in_cv_param
            @_cv_param.instance_variable_set(name, str)
          end
        end
      end
      
    end
    
  end
  
end

if __FILE__ == $0
  
  ImzML::ImzML.new("Example_Continuous.imzML") do |imzml|
    # p imzml.cvs
    # p imzml.file_description.file_conten
  end
  
end