module Hyperspectral

  class SmoothingFeatureController

    include Callbacks

    TITLE = "Smoothing"

    MOVING_AVERAGE_DEFAULT = "5"
    SAVITZKY_GOLAY_DEFAULT = "5"
    SAVITZKY_GOLAY_ORDER = 3

    # Origin points of the current spectrum
    attr_accessor :points

    # Points for "before" smoothing preview
    attr_accessor :preview_points

    def load_view(superview)
      item = Fox::FXTabItem.new(superview, TITLE)
      matrix = Fox::FXMatrix.new(superview,
        :opts => Fox::FRAME_THICK | Fox::FRAME_RAISED | Fox::LAYOUT_FILL_X |
          Fox::MATRIX_BY_COLUMNS
      )
      matrix.numColumns = 5
      matrix.numRows = 2

      # =====================
      # = Prepare processes =
      # =====================
      @process_savitzky_golay = Proc.new do |intensity, mz|
        smoothed_values = savgol(intensity, @saviztky_golay_size_textfield.text.to_i, SAVITZKY_GOLAY_ORDER)
        [smoothed_values, mz]
      end

      @process_moving_average = Proc.new do |intensity, mz|
         smoothed_values = moving_average(intensity, @moving_average_size_textfield.text.to_i)
         [smoothed_values, mz]
      end

      # ==================
      # = Moving average =
      # ==================
      Fox::FXLabel.new(matrix, "Moving average window size", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      @moving_average_size_textfield = Fox::FXTextField.new(matrix, 4,
        :opts => Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X |
          Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::TEXTFIELD_REAL |
          Fox::LAYOUT_FILL
      )
      @moving_average_size_textfield.text = MOVING_AVERAGE_DEFAULT
      @moving_average_size_textfield.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        window_size = sender.text.to_i
        if window_size < 1 || window_size >= @points.size
          Fox::FXMessageBox.warning(superview, Fox::MBOX_OK, "Input error",
            "Window size size must be a positive and smaller then spectrum size")
          sender.text = MOVING_AVERAGE_DEFAULT # default value
        end
      end

      Fox::FXSeparator.new(matrix, :opts => Fox::SEPARATOR_NONE)
      moving_average_preview_button = Fox::FXButton.new(matrix, "Preview",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL)
      moving_average_preview_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        intensity, array = @process_moving_average.call(@points.values, nil)
        @preview_points = create_preview_points(intensity)
        callback(:when_smoothing_applied, @preview_points)
      end

      moving_average_button = Fox::FXButton.new(matrix, "Apply to All",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL)
      moving_average_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        callback(:when_apply, @process_moving_average)
      end

      # ==================
      # = Savitzky Golay =
      # ==================
      Fox::FXLabel.new(matrix, "Savitzky-Golay window size", nil,
        Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X | Fox::JUSTIFY_RIGHT |
        Fox::LAYOUT_FILL_ROW
      )
      @saviztky_golay_size_textfield = Fox::FXTextField.new(matrix, 4,
        :opts => Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_CENTER_X |
          Fox::FRAME_SUNKEN | Fox::FRAME_THICK | Fox::TEXTFIELD_REAL |
          Fox::LAYOUT_FILL
      )
      @saviztky_golay_size_textfield.text = SAVITZKY_GOLAY_DEFAULT
      @saviztky_golay_size_textfield.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        window_size = sender.text.to_i
        if !window_size.is_a?(Integer) || window_size.abs != window_size ||
            window_size % 2 != 1 || window_size < 1 ||
            window_size <= SAVITZKY_GOLAY_ORDER
          Fox::FXMessageBox.warning(superview, Fox::MBOX_OK, "Input error",
            "Window size size must be a positive odd integer and must be higher than the order (#{SAVITZKY_GOLAY_ORDER})")
          sender.text = SAVITZKY_GOLAY_DEFAULT # default value
        end
      end

      Fox::FXSeparator.new(matrix, :opts => Fox::SEPARATOR_NONE)
      savitzky_golay_preview_button = Fox::FXButton.new(matrix, "Preview",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL)
      savitzky_golay_preview_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        intensity, array = @process_savitzky_golay.call(@points.values, nil)
        @preview_points = create_preview_points(intensity)
        callback(:when_smoothing_applied, @preview_points)
      end

      savitzky_golay_button = Fox::FXButton.new(matrix, "Apply to All",
        :opts => Fox::LAYOUT_FILL |
          Fox::BUTTON_NORMAL)
      savitzky_golay_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        callback(:when_apply, @process_savitzky_golay)
      end
    end

    private

    # Views
    attr_accessor :saviztky_golay_size_textfield, :moving_average_size_textfield

    # Preprocessing processes
    attr_accessor :process_moving_average, :process_savitzky_golay

    def moving_average(array, n = 5)
      # p "Moving averate with #{n}"

      return array if n <= 1 # FIXME handle situation when the n is 1
      return array if n >= array.size
      # FIXME too big window size make strange artefacts, the begining and the end reproduce the origin signal, think about it somehow

      filtered = Array.new

      n_half = n/2
      start_index = n_half
      end_index = -n_half
      # p "n/2 = #{n_half}"
      # p "start #{start_index}, end_index #{end_index}"

      # prepend unchanged begining
      filtered += array[0..start_index-1]

      array[start_index..end_index-1].map.with_index(start_index) do |x, i|
        # p "x[#{i}] = #{x}"
        # p "from #{i-n_half} to #{i+n_half}"
        from = i-n_half
        to = i+n_half
        subarray = array[from..to]
        sum = subarray.reduce(:+)
        avg = sum/n.to_f
        # p "subarray #{subarray}, sum #{sum}, avg = #{avg}"

        filtered << avg
      end

      # append the unchanged end
      filtered += array[end_index..-1]

      filtered
    end

    # Calculation of Savitzky-Golay smoothing
    #
    # array - an input array which will be smoothed
    # window_size - size of the smoothing window
    # order - order of the weights
    # Returns smoothed array
    def savgol(array, window_size, order, deriv=0, check_args=false)
      # order must be an integer >= 0
      # window_size size must be a positive odd integer
      # window_size is too small for the polynomials order

      half_window = (window_size -1) / 2
      weights = weights(half_window, order, deriv)
      ar = pad_ends(array, half_window)
      convolve(ar, weights)
    end

    # Convolve
    def convolve(data, weights)
      data.each_cons(weights.size).map do |ar|
        ar.zip(weights).map {|pair| pair[0] * pair[1] }.reduce(:+)
      end
    end

    # Pads the ends with the reverse, geometric inverse sequence
    def pad_ends(array, half_window)
      start = array[1..half_window]
      start.reverse!
      start.map! {|v| array[0] - (v - array[0]).abs }

      fin = array[(-half_window-1)...-1]
      fin.reverse!
      fin.map! {|v| array[-1] + (v - array[-1]).abs }
      start.push(*array, *fin)
    end

    # Returns an object that will convolve with the padded array
    def weights(half_window, order, deriv=0)
      mat = Matrix[ *(-half_window..half_window).map {|k| (0..order).map {|i| k**i }} ]
      # Moore-Penrose psuedo-inverse without SVD (not so precize)
      # A' = (A.t * A)^-1 * A.t
      pinv_matrix = Matrix[*(mat.transpose*mat).to_a].inverse * Matrix[*mat.to_a].transpose
      pinv = Matrix[*pinv_matrix.to_a]
      pinv.row(deriv).to_a
    end

    def create_preview_points(values)
      Hash[*@points.keys.zip(values).flatten]
    end

  end

end