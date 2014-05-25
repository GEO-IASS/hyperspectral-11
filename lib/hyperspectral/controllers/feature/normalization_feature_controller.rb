module Hyperspectral

  class NormalizationFeatureController

    include Callbacks

    TITLE = "Normalization"


    def load_view(superview)
      item = Fox::FXTabItem.new(superview, TITLE)
      matrix = Fox::FXMatrix.new(superview,
        :opts => Fox::FRAME_THICK | Fox::FRAME_RAISED | Fox::LAYOUT_FILL_X |
          Fox::MATRIX_BY_COLUMNS
      )
      matrix.numColumns = 2
      matrix.numRows = 2

      @process_normalization_tic = Proc.new do |intensity, mz|
        normalized_intensity = normalization(intensity, :tic)
        [normalized_intensity, mz]
      end

      @process_normalization_median = Proc.new do |intensity, mz|
        normalized_intensity = normalization(intensity, :median)
        [normalized_intensity, mz]
      end

      # =======
      # = TIC =
      # =======
      Fox::FXLabel.new(matrix, "TIC", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      tic_apply_button = Fox::FXButton.new(matrix, "Apply to All",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL)
      tic_apply_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        callback(:when_apply, @process_normalization_tic)
      end

      # ==========
      # = Median =
      # ==========
      Fox::FXLabel.new(matrix, "Median", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      tic_apply_button = Fox::FXButton.new(matrix, "Apply to All",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL)
      tic_apply_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        callback(:when_apply, @process_normalization_median)
      end

    end

    private

    # Apply normalization on intensities
    #
    # intensities - an array of intensities
    # type - type of normalization method (currently just :tic and :median)
    # Returns new array of normalized intensities
    def normalization(intensities, type = :tic)

      f = 1
      case type
      when :tic
        p = 1
        sum = intensities.inject { |sum, n| sum + n.abs ** p }
        f = sum ** (1/p)
      when :median
        median = intensities.median
        f = median unless median == 0
      end

      intensities.map do |intensity|
        (1/f.to_f) * intensity
      end
    end

  end

end