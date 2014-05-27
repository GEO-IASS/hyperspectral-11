module Hyperspectral

  # Class for handling selection tab and the selection itself.
  class SelectionFeatureController

    include Callbacks

    # tab title
    TITLE = "Selection"

    # Currently selected mz value
    attr_accessor :selected_value

    # Selected mz interval number (readonly)
    attr_reader :selected_interval

    # Reference for spectrum names to show in tree list box
    attr_accessor :spectrum_names

    # Image drawn intensity range, used for sliders to limit shown intensity
    attr_accessor :image_intensity_range

    def initialize
      # Defaults
      @selected_value = nil
      @selected_interaval = 0
    end

    # Gets the selected interval from textfield.
    #
    # Returns String of selected interval from textfield.
    def selected_interval
      @interval_textfield.text.to_f
    end

    # Sets the selected value also in the textfield.
    #
    # value - new selected value
    def selected_value=(value)
      @selected_value = value
      @mz_textfield.text = value.to_s
    end

    # Assign spectrum names into the tree list box.
    #
    # names - an array of spectrum names
    def spectrum_names=(names)
      @spectrum_names = names

      return unless @spectrums_treelistbox

      # remove previous items
      @spectrums_treelistbox.clearItems

      # add new items
      names.each do |name|
        @spectrums_treelistbox.appendItem(nil, name.to_s)
      end
    end

    # Assing the intensity range and sets the correct slider values and
    # behavior.
    #
    # range - new range of intensity
    def image_intensity_range=(range)
      @image_intensity_range = range
      @minimum_slider.enabled = true
      @maximum_slider.enabled = true
      @minimum_value_label.text = range.begin.round(SLIDER_RANGE_ROUND).to_s
      @maximum_value_label.text = range.end.round(SLIDER_RANGE_ROUND).to_s
    end

    # Calculates selected intensity range to draw
    #
    # Returns Range object
    def selected_intensity_range
      range = @image_intensity_range
      step = (range.end - range.begin) / 100

      from = @minimum_slider.value * step + range.begin
      to = @maximum_slider.value * step + range.begin

      from..to
    end

    # Loads view.
    #
    # superview - parent view
    def load_view(superview)

      item = Fox::FXTabItem.new(superview, TITLE)
      matrix = Fox::FXMatrix.new(superview,
        :opts => Fox::FRAME_THICK | Fox::FRAME_RAISED | Fox::LAYOUT_FILL_X |
          Fox::MATRIX_BY_COLUMNS
      )
      matrix.numColumns = 2
      matrix.numRows = 4

      # ====================
      # = Use memory cache =
      # ====================
      Fox::FXSeparator.new(matrix, :opts => Fox::SEPARATOR_NONE)
      @checkbox = Fox::FXCheckButton.new(matrix, "Cache into memory")
      @checkbox.connect(Fox::SEL_COMMAND) do |sender, selector, event|
        callback(:when_cache_changed, sender.checkState == Fox::TRUE)
      end

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
      @interval_textfield.text = @selected_inteval.to_s
      @interval_textfield.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        if sender.text.size >= 0
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

      # =========================
      # = Show average spectrum =
      # =========================
      Fox::FXSeparator.new(matrix, :opts => Fox::SEPARATOR_NONE)
      Fox::FXButton.new(matrix, "Show average spectrum",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL).connect(Fox::SEL_COMMAND) do |sender, sel, event|
          callback(:when_average_spectrum_pressed)
      end

      # =====================
      # = Draw image button =
      # =====================
      Fox::FXSeparator.new(matrix, :opts => Fox::SEPARATOR_NONE)
      draw_image_button = Fox::FXButton.new(matrix, "Draw image",
        :opts => Fox::LAYOUT_FILL | Fox::BUTTON_NORMAL
      )
      draw_image_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        callback(:when_draw_image_pressed)
      end

      # =======================
      # = Reset preprocessing =
      # =======================
      Fox::FXSeparator.new(matrix, :opts => Fox::SEPARATOR_NONE)
      draw_image_button = Fox::FXButton.new(matrix, "Reset all preprocessing",
        :opts => Fox::LAYOUT_FILL | Fox::BUTTON_NORMAL
      )
      draw_image_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        callback(:when_reset)
      end

      # ==================
      # = Minimum slider =
      # ==================
      Fox::FXLabel.new(matrix, "Minimum intensity", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      packer = Fox::FXHorizontalFrame.new(matrix,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_FILL_Y | Fox::LAYOUT_BOTTOM |
        Fox::LAYOUT_RIGHT
      )
      @minimum_slider = Fox::FXSlider.new(packer, :opts => Fox::LAYOUT_FILL)
      @minimum_slider.enabled = false
      @minimum_slider.value = 0
      @minimum_value_label = Fox::FXLabel.new(packer, @minimum_slider.value.to_s, nil,
        Fox::LAYOUT_FIX_WIDTH | Fox::LAYOUT_RIGHT | Fox::JUSTIFY_RIGHT,
        :width => 50
      )
      @minimum_slider.connect(Fox::SEL_COMMAND) do |sender, selector, event|
        if event > @maximum_slider.value
          sender.value = @maximum_slider.value
          minimum_value_text(sender.value)
        end

        callback(:when_intensity_range_change, selected_intensity_range)
      end
      @minimum_slider.connect(Fox::SEL_CHANGED) do |sender, selector, event|
        minimum_value_text(@minimum_slider.value)
        callback(:when_intensity_range_change, selected_intensity_range)
      end

      # ==================
      # = Maximum slider =
      # ==================
      Fox::FXLabel.new(matrix, "Maximum intensity", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      packer = Fox::FXHorizontalFrame.new(matrix,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_FILL_Y | Fox::LAYOUT_BOTTOM |
        Fox::LAYOUT_RIGHT
      )
      @maximum_slider = Fox::FXSlider.new(packer, :opts => Fox::LAYOUT_FILL)
      @maximum_slider.enabled = false
      @maximum_slider.value = 100
      @maximum_value_label = Fox::FXLabel.new(packer, @maximum_slider.value.to_s, nil,
        Fox::LAYOUT_FIX_WIDTH | Fox::LAYOUT_RIGHT | Fox::JUSTIFY_RIGHT,
        :width => 50
      )
      @maximum_slider.connect(Fox::SEL_COMMAND) do |sender, selector, event|
        if event < @minimum_slider.value
          sender.value = @minimum_slider.value
          maximum_value_text(sender.value)
        end

        callback(:when_intensity_range_change, selected_intensity_range)
      end
      @maximum_slider.connect(Fox::SEL_CHANGED) do |sender, selector, event|
        maximum_value_text(@maximum_slider.value)
        callback(:when_intensity_range_change, selected_intensity_range)
      end

    end

    private

    # number of digits to round the displayed slider value
    SLIDER_RANGE_ROUND = 2

    # Method which transforms the maximum intensity value in 0..100 range.
    #
    # value - selected intensity value
    def maximum_value_text(value)
      range = @image_intensity_range
      step = (range.end - range.begin) / 100
      actual_value = value * step + range.begin
      @maximum_value_label.text = actual_value.round(SLIDER_RANGE_ROUND).to_s;
    end

    # Method which transforms the minimum intensity value in 0..100 range.
    #
    # value - selected intensity value
    def minimum_value_text(value)
      range = @image_intensity_range
      step = (range.end - range.begin) / 100
      actual_value = value * step + range.begin
      @minimum_value_label.text = actual_value.round(SLIDER_RANGE_ROUND).to_s;
    end

    # References to the meaningful subviews
    attr_accessor :mz_value_textfield, :interval_textfield

  end

end