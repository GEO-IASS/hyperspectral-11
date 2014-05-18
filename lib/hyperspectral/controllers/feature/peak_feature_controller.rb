R = 2 # to disable basic R init (even documentation recommend this way)
require "rinruby"

module Hyperspectral

  class PeakFeatureController

    include Callbacks

    DEBUG_R = false

    DEFAULT_SCALES_TOP = 64
    DEFAULT_SNRATIO = 10

    TITLE = "Peak"

    # Spectrum points
    attr_accessor :points

    def load_view(superview)
      item = Fox::FXTabItem.new(superview, TITLE)
      matrix = Fox::FXMatrix.new(superview,
        :opts => Fox::FRAME_THICK | Fox::FRAME_RAISED | Fox::LAYOUT_FILL_X |
          Fox::MATRIX_BY_COLUMNS
      )
      matrix.numColumns = 2
      matrix.numRows = 4


      # ==========
      # = Scales =
      # ==========
      Fox::FXLabel.new(matrix, "Scales count", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      @scale_textfield = Fox::FXTextField.new(matrix, 10,
        :opts => Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X |
          Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::TEXTFIELD_REAL |
          Fox::LAYOUT_FILL
      )
      @scale_textfield.text = DEFAULT_SCALES_TOP.to_s

      # =======
      # = SNR =
      # =======
      Fox::FXLabel.new(matrix, "SNR", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      @snr_textfield = Fox::FXTextField.new(matrix, 10,
        :opts => Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X |
          Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::TEXTFIELD_REAL |
          Fox::LAYOUT_FILL
      )
      @snr_textfield.text = DEFAULT_SNRATIO.to_s

      # =====================
      # = Find peaks button =
      # =====================
      Fox::FXSeparator.new(matrix, :opts => Fox::SEPARATOR_NONE)
      Fox::FXButton.new(matrix, "Find peaks",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL).connect(Fox::SEL_COMMAND) do |sender, sel, event|
            indexes = peak_indexes(@points.values)
            peaks = indexes.map { |i| @points.keys[i] }
            callback(:when_peaks_found, peaks)
      end
    end

    def peak_indexes(spectrum, echo_debug = DEBUG_R)

      @interpret = RinRuby.new(echo_debug)

      # @interpret.filename = "#{File.expand_path( File.dirname(__FILE__) + '/../../data/')}/#{filename}"

      # p @interpret.filename
      @interpret.exampleMS = spectrum
      @interpret.topScale = @scale_textfield.text.to_f
      @interpret.SNRatio = @snr_textfield.text.to_f

      @interpret.eval %Q{

        library(MassSpecWavelet)
        library(waveslim)

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
