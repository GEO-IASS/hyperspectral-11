module Hyperspectral

  class SelectionFeatureController

    include Callbacks

    TITLE = "Selection"

    attr_accessor :selected_value

    def selected_value=(value)
      @selected_value = value
      @mz_textfield.text = value.to_s
    end

    def load_view(superview)

      item = Fox::FXTabItem.new(superview, TITLE)
      matrix = Fox::FXMatrix.new(superview,
        :opts => Fox::FRAME_THICK | Fox::FRAME_RAISED | Fox::LAYOUT_FILL_X |
          Fox::MATRIX_BY_COLUMNS
      )
      matrix.numColumns = 2
      matrix.numRows = 4

      # ================
      # = MZ textfield =
      # ================
      Fox::FXLabel.new(matrix, "m/z value", nil, Fox::LAYOUT_CENTER_Y |
        Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT | Fox::LAYOUT_FILL_ROW
      )
      @mz_textfield = Fox::FXTextField.new(matrix, 30,
        :opts => Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X |
          Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::TEXTFIELD_REAL |
          Fox::LAYOUT_FILL
      )
      @mz_textfield.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        if sender.text.size > 0
          callback(:when_changed_mz_value, sender.text.to_f)
        end
      end

      # ======================
      # = Interval textfield =
      # ======================
      Fox::FXLabel.new(matrix, "interval value", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      @interval_textfield = Fox::FXTextField.new(matrix, 10,
        :opts => Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X |
          Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::TEXTFIELD_REAL |
          Fox::LAYOUT_FILL
      )
      @interval_textfield.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        if sender.text.size > 0
          callback(:when_changed_interval_value, sender.text.to_f)
        end
      end

      # =====================
      # = Spectrum selector =
      # =====================
    #
    #   Fox::FXLabel.new(matrix, "selected spectrum", nil,
    #     Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
    #     Fox::LAYOUT_FILL_ROW
    #   )
    #   @tree_list_box = Fox::FXTreeListBox.new(matrix, nil,
    #     :opts => Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::LAYOUT_SIDE_TOP |
    #     Fox::LAYOUT_FILL
    #   )
    #   @tree_list_box.numVisible = 5
    #   @tree_list_box.connect(Fox::SEL_COMMAND) do |sender, sel, event|
    #
    #     # open specfic spectrum
    #     spectrum = @metadata.spectrums[event.to_s.to_sym]
    #     open_spectrum(spectrum)
    #   end
    #
    #   Fox::FXSeparator.new(matrix, :opts => SEPARATOR_NONE)
    #   Fox::FXButton.new(matrix, "Show average spectrum",
    #     :opts => Fox::LAYOUT_FILL | Fox::BUTTON_NORMAL).connect(Fox::SEL_COMMAND) do |sender, sel, event|
    #     # load average
    #     if @average_spectrum.nil?
    #       run_on_background do
    #         create_average_spectrum
    #       end
    #     end
    #     @spectrum = @average_spectrum.dup
    #     @spectrum_canvas.visible_spectrum = @average_spectrum.dup
    #     @selected_y = @selected_x = 0
    #     @image_canvas.update
    #     update_visible_spectrum
    #   end
    #
    #   Fox::FXSeparator.new(matrix, :opts => SEPARATOR_NONE)
    #   Fox::FXButton.new(matrix, "Draw image", :opts => Fox::LAYOUT_FILL|Fox::BUTTON_NORMAL).connect(Fox::SEL_COMMAND) do |sender, sel, event|
    #     run_on_background do
    #       create_image
    #     end
    #   end
    #
    #   Fox::FXSeparator.new(matrix, :opts => SEPARATOR_NONE)
    #   Fox::FXButton.new(matrix, "Find peaks", :opts => Fox::LAYOUT_FILL|Fox::BUTTON_NORMAL).connect(Fox::SEL_COMMAND) do |sender, sel, event|
    #     run_on_background do
    #
    #       # TODO load data from current spectrum
    #       peaks = PeakDetector.peak_indexes(@spectrum.values)
    #       keys = @spectrum.keys
    #       @spectrum_canvas.peaks = peaks.map{|index| keys[index]}
    #       @spectrum_canvas.update
    #     end
    #   end
    end

    private

    # References to the meaningful subviews
    attr_accessor :mz_value_textfield, :interval_textfield

  end

end