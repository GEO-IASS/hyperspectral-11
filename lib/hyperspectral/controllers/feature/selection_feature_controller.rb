module Hyperspectral

  class SelectionFeatureController

    include Callbacks

    TITLE = "Selection"

    # Currently selected mz value
    attr_accessor :selected_value

    # Reference for spectrum names to show in tree list box
    attr_accessor :spectrum_names

    def selected_value=(value)
      @selected_value = value
      @mz_textfield.text = value.to_s
    end

    def spectrum_names=(names)
      @spectrum_names = names

      return unless @spectrums_treelistbox

      # remove previous items
      @spectrums_treelistbox.clearItems

      p "tree list #{@spectrums_treelistbox.respond_to?(:appendItem)}"

      # add new items
      names.each do |name|
        @spectrums_treelistbox.appendItem(nil, name.to_s)
      end
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
      Fox::FXLabel.new(matrix, "selected spectrum", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      @spectrums_treelistbox = Fox::FXTreeListBox.new(matrix, nil,
        :opts => Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::LAYOUT_SIDE_TOP |
        Fox::LAYOUT_FILL
      )
      @spectrums_treelistbox.numVisible = 5
      @spectrums_treelistbox.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        callback(:when_spectrum_listbox_chaned, event.to_s)
      end
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