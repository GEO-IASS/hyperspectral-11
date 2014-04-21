R = 2 # to disable basic R init (even documentation recommend this way)
require "rinruby"

module Hyperspectral
  
  class PeakDetector
    
    DEBUG_R = false

    DEFAULT_DATA_FILENAME = "exampl_countinuous.csv"
    DEFAULT_DATA_SIZE = nil
    DEFAULT_SCALES_TOP = 64
    DEFAULT_SNRATIO = 10
    
    def self.peak_indexes(spectrum, echo_debug = PeakDetector::DEBUG_R)
      
      @interpret = RinRuby.new(echo_debug)

      # @interpret.filename = "#{File.expand_path( File.dirname(__FILE__) + '/../../data/')}/#{filename}"
      
      # p @interpret.filename
      p @interpret.exampleMS = spectrum
      
      @interpret.eval %Q{
        # csv = read.csv(filename, colClasses = c('character', 'numeric'))
        exampleMS = matrix(csv$V1)
      }
    
      @interpret.topScale = PeakDetector::DEFAULT_SCALES_TOP
      @interpret.SNRatio = PeakDetector::DEFAULT_SNRATIO

      @interpret.eval %Q{

        library(MassSpecWavelet)
      
        peakInfo <- peakDetectionCWT(exampleMS)
      
        # ridgeList = peakInfo$ridgeList
        # localMax = peakInfo$localMax
        # wCoefs = peakInfo$wCoefs
        majorPeakInfo = peakInfo$majorPeakInfo
      
        # peakIndex = majorPeakInfo$peakIndex
        # peakValue = majorPeakInfo$peakValue
        # peakCenterIndex = majorPeakInfo$peakCenterIndex
        peakSNR = majorPeakInfo$peakSNR
        # peakScale = majorPeakInfo$peakScale
        # potentialPeakIndex = majorPeakInfo$potentialPeakIndex
        allPeakIndex = majorPeakInfo$allPeakIndex

      }
      
      all_snrs = @interpret.peakSNR
      peaks = []
      @interpret.allPeakIndex.each_with_index do |x, index|
        peaks << x if all_snrs[index] >= @interpret.SNRatio
      end
    
      peaks
    end
  end
  
end