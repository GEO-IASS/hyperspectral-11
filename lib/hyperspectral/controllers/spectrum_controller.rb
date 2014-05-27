module Hyperspectral

  class SpectrumController

    include Callbacks

    # Array of spectrum points where each poin is subarray with just two items
    attr_accessor :points

    # Array used for preview one preprocessing step with current spectrum
    attr_accessor :preview_points

    # Array with selectd points, after change, display it on spectrum canvas
    attr_accessor :selected_points

    # Interval which may be used to draw the image
    attr_accessor :selected_interval

    # Spectrum mode, can be one of the symbols [:default, :single_selection, :multi_selection]
    attr_accessor :mode

    def mode=(mode)
      @mode = mode

      needs_display
    end

    def points=(points)
      @points = points

      self.visible_spectrum = points.dup

      # Default values
      @pressed = NO_MOUSE
      self.zoom_from = self.zoom_to = nil
      self.mode = :single_selection

      needs_display
    end

    def preview_points=(points)
      @preview_points = points
      @spectrum_canvas.preview_points = points
      needs_display
    end

    def selected_points=(points)
      @selected_points = points
      @spectrum_canvas.selected_points = points
      needs_display
    end

    def selected_interval=(interval)
      @selected_interval = interval
      @spectrum_canvas.selected_interval = interval
    end

    # Load all views controller by this controller
    def load_view(superview)

      horizontal_frame = Fox::FXHorizontalFrame.new(superview,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_FILL_Y | Fox::LAYOUT_BOTTOM |
          Fox::LAYOUT_RIGHT
      )

      @spectrum_canvas = Hyperspectral::SpectrumCanvas.new(horizontal_frame)
      @spectrum_canvas.show_cross = true

      # bind events methods
      @spectrum_canvas.connect(Fox::SEL_LEFTBUTTONPRESS, method(:mouse_pressed))
      @spectrum_canvas.connect(Fox::SEL_LEFTBUTTONRELEASE, method(:mouse_released))
      @spectrum_canvas.connect(Fox::SEL_RIGHTBUTTONPRESS, method(:mouse_pressed))
      @spectrum_canvas.connect(Fox::SEL_RIGHTBUTTONRELEASE, method(:mouse_released))
      @spectrum_canvas.connect(Fox::SEL_MOTION, method(:mouse_moved))

      @spectrum_canvas.when_select_point do |selected_points|
        callback(:when_select_point, selected_points)
      end

      buttons_frame = Fox::FXVerticalFrame.new(horizontal_frame,
        :opts => Fox::LAYOUT_FIX_WIDTH | Fox::LAYOUT_FILL_Y,
        :width => 50)

      zoom_in_button = Fox::FXButton.new(buttons_frame, "+",
        :opts => Fox::FRAME_RAISED | Fox::LAYOUT_FILL
      )
      zoom_in_button.connect(Fox::SEL_COMMAND, method(:zoom_in_pressed))
      zoom_reset_buttom = Fox::FXButton.new(buttons_frame, "100%",
        :opts => Fox::FRAME_RAISED | Fox::LAYOUT_FILL
      )
      zoom_reset_buttom.connect(Fox::SEL_COMMAND, method(:zoom_reset_pressed))
      zoom_out_button = Fox::FXButton.new(buttons_frame, "-",
        :opts => Fox::FRAME_RAISED | Fox::LAYOUT_FILL
      )
      zoom_out_button.connect(Fox::SEL_COMMAND, method(:zoom_out_pressed))

      needs_display
    end

    # Redraws the views
    def needs_display
      @spectrum_canvas.reset_cache
      @spectrum_canvas.update
    end

    # Sets the current visible spectrum and calulates the Y and X minimum and
    # maximum values.
    #
    # spectrum - the visible part of the spectrum
    def visible_spectrum=(spectrum)
      # FIXME debug
      @visible_spectrum = spectrum

      # Find min and max
      x_values = spectrum.keys
      y_values = spectrum.values

      # assign min/max values
      @spectrum_canvas.spectrum_min_x = x_values.min
      @spectrum_canvas.spectrum_max_x = x_values.max
      @spectrum_canvas.spectrum_min_y = y_values.min
      @spectrum_canvas.spectrum_max_y = y_values.max

      @spectrum_canvas.spectrum = @visible_spectrum

      needs_display
    end

    def zoom_in_pressed(sender, selector, event)
      visible_spectrum = @visible_spectrum.to_a

      # if there are no too many values, do not zoom any further
      return unless visible_spectrum.size > 4

      # recalculate zoom in values
      quarter = (visible_spectrum.last.first - visible_spectrum.first.first) / 4
      zoom_begin = visible_spectrum.first.first + quarter
      zoom_end = visible_spectrum.last.first - quarter

      zoom([zoom_begin, 0], [zoom_end, 0])
      needs_display
    end

    def zoom_reset_pressed(sender, selector, event)
      spectrum = @points.to_a
      from = [spectrum.first[0], 0]
      to = [spectrum.last[0], 0]

      zoom(from, to)
      needs_display
    end

    def zoom_out_pressed(sender, selector, event)
      visible_spectrum = @visible_spectrum.to_a
      spectrum = @points.to_a

      # do not zoom out if there are no more values to zoom to
      # return unless visible_spectrum.size > 4

      # recalculate zoom out values
      quarter = (visible_spectrum.last.first - visible_spectrum.first.first) / 4
      quarter = 1 if quarter == 0
      zoom_begin = visible_spectrum.first.first - quarter
      zoom_end = visible_spectrum.last.first + quarter

      # limit to the spectrum values
      zoom_begin = spectrum.first.first if zoom_begin < spectrum.first.first
      zoom_end = spectrum.last.first if zoom_end > spectrum.last.first

      zoom([zoom_begin, 0], [zoom_end, 0])
      needs_display
    end

    private

    NO_MOUSE = 0
    LEFT_MOUSE = 1
    RIGHT_MOUSE = 3

    # Views
    attr_accessor :spectrum_canvas

    # Mouse events
    attr_accessor :pressed

    attr_accessor :zoom_from, :zoom_to

    def zoom_from=(zoom_from)
      @zoom_from = zoom_from
      @spectrum_canvas.zoom_from = zoom_from
    end

    def zoom_to=(zoom_to)
      @zoom_to = zoom_to
      @spectrum_canvas.zoom_to = zoom_to
    end

    def mouse_pressed(sender, selector, event)
      case event.click_button
      when LEFT_MOUSE
        self.zoom_from = self.zoom_to = @spectrum_canvas.check_canvas_x(event.click_x)
      when RIGHT_MOUSE
        x = @spectrum_canvas.check_canvas_x(event.last_x)
        spectrum_x_value = @spectrum_canvas.canvas_point_to_spectrum([x, 0]).x
        case @mode
        when :single_selection
          self.selected_points = [spectrum_x_value]
        when :multi_selection
        end
      end

      @spectrum_canvas.show_cross = false
      @pressed = event.click_button
      needs_display
    end

    def mouse_moved(sender, selector, event)
      return unless event.moved?
      case @pressed
      when LEFT_MOUSE
        self.zoom_to = @spectrum_canvas.check_canvas_x(event.last_x)
      when RIGHT_MOUSE
        x = @spectrum_canvas.check_canvas_x(event.last_x)
        spectrum_x_value = @spectrum_canvas.canvas_point_to_spectrum([x, 0]).x
        case @mode
        when :single_selection
          self.selected_points = [spectrum_x_value]
        when :multi_selection
        end
      end

      needs_display
    end

    def mouse_released(sender, selector, event)
      case event.click_button
      when LEFT_MOUSE
        tmp = [@zoom_from, @zoom_to]
        from = @spectrum_canvas.canvas_point_to_spectrum([tmp.min, 0])
        to = @spectrum_canvas.canvas_point_to_spectrum([tmp.max, 0])
        zoom(from, to)
        self.zoom_from = self.zoom_to = nil
      when RIGHT_MOUSE
        case @mode
        when :single_selection
          callback(:when_select_point, @selected_points)
        when :multi_selection
        end
      end

      @show_cross = true
      @pressed = NO_MOUSE
      needs_display
    end

    # Zooming function which takes spectrum point where to zoom
    #
    # from - spectrum point from which to zoom in
    # to - spectrum point from which to zoom to
    def zoom(from, to)
      spectrum_copy = @points.dup
      self.visible_spectrum = spectrum_copy.keep_if do |k, v|
        k >= from.x && k <= to.x
      end
    end

  end

end