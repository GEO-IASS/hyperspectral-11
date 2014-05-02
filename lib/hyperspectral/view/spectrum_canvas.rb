module Hyperspectral

  class SpectrumCanvas < Fox::FXCanvas

    include Callbacks

    # Spectrum mode, can be one of the symbols [:default, :single_selection, :multi_selection]
    attr_accessor :mode

    # The currently displayed full spectrum
    attr_accessor :spectrum

    # Array of selected point (in spectrum coords) which should be drawn
    attr_accessor :selected_points

    # Bool determinig if the position cross with coordinates is shown
    attr_accessor :show_cross

    # Init method
    #
    # superview - instance of Fox::FXWindo
    def initialize(superview)
      super(superview, :opts => Fox::LAYOUT_FILL)

      @font = Fox::FXFont.new(app, "times")
      @font.create

      # default state
      @smoothing_window_size = 5
      @pressed = NO_MOUSE
      @zoom_from = @zoom_from = nil
      @mode = :single_selection

      # bind events methods
      connect(Fox::SEL_PAINT, method(:draw))
      connect(Fox::SEL_LEFTBUTTONPRESS, method(:mouse_pressed))
      connect(Fox::SEL_LEFTBUTTONRELEASE, method(:mouse_released))
      connect(Fox::SEL_RIGHTBUTTONPRESS, method(:mouse_pressed))
      connect(Fox::SEL_RIGHTBUTTONRELEASE, method(:mouse_released))
      connect(Fox::SEL_MOTION, method(:mouse_moved))

    end

    # Overriden setter for spectrum which adds new visible spectrum
    def spectrum=(spectrum)
      @spectrum = spectrum

      self.visible_spectrum = spectrum.dup
    end

    # Resets spectrum point cache
    #
    # Returns nothing
    def reset_cache
      @cached_spectrum = nil
    end

    # Zooms in into the half
    def zoom_in
      visible_spectrum = @visible_spectrum.to_a

      # if there are no too many values, do not zoom any further
      return unless visible_spectrum.size > 4

      # recalculate zoom in values
      quarter = (visible_spectrum.last.first - visible_spectrum.first.first) / 4
      zoom_begin = visible_spectrum.first.first + quarter
      zoom_end = visible_spectrum.last.first - quarter

      zoom([zoom_begin, 0], [zoom_end, 0])
    end

    # Zooms out to see twice as current
    def zoom_out
      visible_spectrum = @visible_spectrum.to_a
      spectrum = @spectrum.to_a

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
    end

    # Resets the zoom to the default
    def zoom_reset
      spectrum = @spectrum.to_a
      zoom_from = [spectrum.first[0], 0]
      zoom_to = [spectrum.last[0], 0]

      zoom(zoom_from, zoom_to)
    end

    # ===========
    # = private =
    # ===========
    private

    AXIS_PADDING = 30

    LABEL_X_SPACING = 40
    LABEL_Y_SPACING = 40

    LABEL_X_PADDING = 3
    LABEL_Y_PADDING = 3

    NO_MOUSE = 0
    LEFT_MOUSE = 1
    RIGHT_MOUSE = 3

    # Cache for currently visible points
    attr_accessor :cached_spectrum

    # Smoothing variables
    attr_accessor :smoothing, :smoothing_window_size

    # Spectrum preview before alternating it's points
    attr_accessor :spectrum_preview

    # Boundaries for currently visible spectrum
    attr_accessor :spectrum_min_x, :spectrum_max_x, :spectrum_min_y,
      :spectrum_max_y

    # Helper properties for displaying the selection with interval
    attr_accessor :selected_point, :selected_fixed_point,
      :selected_fixed_interval, :selected_interval

    # Found peaks to draw
    attr_accessor :peaks

    # Mouse events
    attr_accessor :pressed, :last_mouse_position

    # Sets the current visible spectrum and calulates the Y and X minimum and
    # maximum values
    #
    # spectrum - the visible part of the spectrum
    def visible_spectrum=(spectrum)
      @visible_spectrum = spectrum

      # Find min and max
      x_values = spectrum.keys
      y_values = spectrum.values
      @spectrum_min_x, @spectrum_max_x = x_values.min, x_values.max
      @spectrum_min_y, @spectrum_max_y = y_values.min, y_values.max

      self.reset_cache
      self.update
    end

    # Spectrum part drawing method
    #
    # Returns nothing
    def draw(sender, sel, event)
      Fox::FXDCWindow.new(sender, event) do |dc|

        # ===================
        # = draw background =
        # ===================
        dc.foreground = Fox::FXColor::White
        dc.fillRectangle(0, 0, sender.width, sender.height)

        # =====================
        # = draw x and y axis =
        # =====================
        dc.foreground = Fox::FXColor::Black
        dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, sender.width - AXIS_PADDING, sender.height - AXIS_PADDING)
        dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, AXIS_PADDING, AXIS_PADDING)
        dc.font = @font

        return unless @visible_spectrum && @spectrum_min_x && @spectrum_min_x

        # FIXME
        preview_points = Array.new

        # ===============================================
        # = calculate spectrum points and save to cache =
        # ===============================================
        if @cached_spectrum.nil?

          points = Array.new

          previous_point = nil

          # convert spectrum points and create canvas points
          @visible_spectrum.each do |mz, intensity|

            # FIXME calibration
            # mz = @calibration.recalculate(mz) if @calibration
            point = spectrum_point_to_canvas([mz, intensity])
            # do not draw the same point twice
            points << Fox::FXPoint.new(point[0].to_i, point[1].to_i)
            # previous_point = point
          end

          ## FIXME
          # # preview for smoothing
          # if !@smoothing.nil?
          #   preview_values = @visible_spectrum.values
          #   keys = @spectrum.keys
          #   @smoothing.apply(preview_values, @smoothing_window_size).each_with_index do |intensity, index|
          #     point = spectrum_point_to_canvas([keys[index], intensity])
          #     preview_points << Fox::FXPoint.new(point[0].to_i, point[1].to_i)
          #   end
          # end

          @cached_spectrum = points
        end

        # load from cache
        points = @cached_spectrum

        # ===============
        # = draw labels =
        # ===============
        labels = Array.new
        spectrum = @visible_spectrum.to_a

        x = AXIS_PADDING
        while x < (sender.width - AXIS_PADDING) do
          point = [x, sender.height - AXIS_PADDING]
          spectrum_point = canvas_point_to_spectrum(point)
          text = spectrum_point[0].round(3).to_s
          text_width = @font.getTextWidth(text)
          dc.drawLine(point[0].to_i, self.height - AXIS_PADDING + 3, point[0].to_i, sender.height - AXIS_PADDING)
          dc.drawText(point[0].to_i - text_width/2, sender.height - AXIS_PADDING / 2, text)
          x += text_width + LABEL_X_SPACING
        end

        y = sender.height - AXIS_PADDING
        while y > AXIS_PADDING do
          point = [LABEL_X_SPACING, y]
          spectrum_point = canvas_point_to_spectrum(point)
          text = spectrum_point[1].round(3).to_s
          text_width = @font.getTextWidth(text)
          text_height = @font.getTextHeight(text)
          dc.drawLine(AXIS_PADDING - 3, point[1].to_i, AXIS_PADDING, point[1].to_i)
          dc.drawText(AXIS_PADDING - text_width - 3, point[1].to_i + text_height/2, text)
          y -= text_height + LABEL_Y_SPACING
        end

        # ======================
        # = draw spectrum line =
        # ======================
        dc.foreground = Fox::FXColor::Red
        dc.drawLines(points)

        ## FIXME
        # dc.foreground = Fox::FXColor::Blue
        # dc.drawLines(preview_points)

        # ====================
        # = draw found peaks =
        # ====================
        if @peaks
          @peaks.each do |p|
            draw_selected_line(dc, [p, 0], 0, Fox::FXColor::Blue)
          end
        end

        # ==================
        # = draw zoom rect =
        # ==================
        if @zoom_from && @zoom_to
          dc.lineStyle = Fox::LINE_ONOFF_DASH
          dc.foreground = Fox::FXColor::Magenta
          zoom_from, zoom_to = @zoom_from, @zoom_to
          width = (@zoom_to - @zoom_from).abs

          # switch the coords when goes left from start position
          zoom_from = @zoom_to if @zoom_to < @zoom_from

          dc.drawRectangle(zoom_from, AXIS_PADDING, width, self.height - 2 * AXIS_PADDING)
        end

        # draw selected fixed line
        draw_selected_line(dc, @selected_fixed_point, @selected_fixed_interval, Fox::FXColor::LightGrey)

        # =======================
        # = draw selected lines =
        # =======================
        @selected_points.each do |x|
          spectrum_point = [x, 0]
          draw_selected_line(dc, spectrum_point, 0, Fox::FXColor::SteelBlue)
        end if @selected_points

        ## FIXME
        # # draw selected line
        # # if @tabbook.current == TAB_BASICS
        # draw_selected_line(dc, @selected_point, @selected_interval, Fox::FXColor::SteelBlue)
        # # end

        # FIXME smoothing
        # # draw smoothing preview
        # if @tabbook.current == TAB_SMOOTHING
        #   dc.foreground = Fox::FXColor::Blue
        #   dc.drawLine(0,0, 100, 100)
        # end

        # FIXME calibration
        # # draw calibration lines
        # if @calibration_points.size > 0 && @tabbook.current == TAB_CALIBRATIONS
        #   @calibration_points.compact.each do |point|
        #     draw_selected_line(dc, [point, 0], 0, Fox::FXColor::Green)
        #   end
        # end

        # ==================
        # = position cross =
        # ==================
        if @show_cross
          mouse_point = [event.last_x, event.last_y]
          spectrum_point = canvas_point_to_spectrum(mouse_point)

          position_text = "#{spectrum_point[0].round(3)} x #{spectrum_point[1].round(3)}"
          text_width = @font.getTextWidth(position_text)
          text_height = @font.getTextHeight(position_text)

          # draw rectangle under the position text
          dc.foreground = dc.background = Fox::FXColor::White
          dc.fillRectangle(mouse_point[0],
            mouse_point[1] - text_height,
            text_width + 2 * LABEL_X_PADDING,
            text_height + LABEL_Y_PADDING
          )

          # draw the actual value
          dc.foreground = Fox::FXColor::LightSlateGray
          dc.drawText(mouse_point[0] + LABEL_X_PADDING,
            mouse_point[1] - LABEL_Y_PADDING,
            position_text
          )

          # draw lines
          dc.lineStyle = Fox::LINE_ONOFF_DASH
          dc.drawLine(mouse_point[0], 0, mouse_point[0], self.height)
          dc.drawLine(0, mouse_point[1], self.width, mouse_point[1])
        end
      end
    end

    # Zooming function which takes spectrum point where to zoom
    #
    # from - spectrum point from which to zoom in
    # to - spectrum point from which to zoom to
    def zoom(from, to)
      spectrum_copy = @spectrum.dup
      self.visible_spectrum = spectrum_copy.keep_if do |k, v|
        k >= from[0] && k <= to[0]
      end
    end

    # Converting canvas point to spectrum point
    #
    # canvas_point - point in the canvas
    #
    # Returns point in spectrum domain
    def canvas_point_to_spectrum(canvas_point)
      # map points
      x_point_origin = canvas_point[0]
      y_point_origin = canvas_point[1]

      # find axis dimensions
      x_axis_width = self.width - 2 * AXIS_PADDING
      y_axis_height = self.height - 2 * AXIS_PADDING

      # calculate x point
      x_point_spectrum = if x_point_origin <= AXIS_PADDING then @spectrum_min_x
      elsif x_point_origin >= (AXIS_PADDING + x_axis_width) then @spectrum_max_x
      else
        x_diff = @spectrum_max_x - @spectrum_min_x
        x_point_size = x_axis_width / x_diff.to_f
        ((x_point_origin - AXIS_PADDING) / x_point_size) + @spectrum_min_x
      end

      # calculate y point
      y_point_spectrum = if y_point_origin <= AXIS_PADDING then @spectrum_max_y
      elsif y_point_origin >= (AXIS_PADDING + y_axis_height) then @spectrum_min_y
      else
        y_diff = @spectrum_max_y - @spectrum_min_y
        y_point_size = y_axis_height / y_diff.to_f
        @spectrum_max_y - (y_point_origin - AXIS_PADDING) / y_point_size
      end

      [x_point_spectrum, y_point_spectrum]
    end

    # Converting spectrum point to canvas point
    #
    # spectrum_point - point in the spectrum
    #
    # Returns point in canvas domain
    def spectrum_point_to_canvas(spectrum_point)

      # if spectrum was not yet loaded
      return [0, 0] unless @spectrum_min_x && spectrum_max_x && (@spectrum_max_x - @spectrum_min_x).abs > 0

      # map points
      x_point_origin = spectrum_point[0]
      y_point_origin = spectrum_point[1]

      # find axis dimensions
      x_axis_width = self.width - 2 * AXIS_PADDING
      y_axis_height = self.height - 2 * AXIS_PADDING

      # calculate one point size for x and y
      x_diff = @spectrum_max_x - @spectrum_min_x
      x_point_size = x_axis_width / x_diff
      y_diff = @spectrum_max_y - @spectrum_min_y
      y_point_size = y_axis_height / y_diff.to_f

      # recalculate points
      x_point_canvas = ((x_point_origin - @spectrum_min_x) * x_point_size) + AXIS_PADDING
      y_point_canvas = self.height - AXIS_PADDING - (y_point_origin * y_point_size - @spectrum_min_y * y_point_size) - 1

      [x_point_canvas, y_point_canvas]
    end

    # Drawing vertical line, used for selection of specific part of spectrum
    #
    # context - instance of Fox::FXDCWindow
    # selected_point - selected point in spectrum domain
    # selected_interval - selected interval in spectrum domain
    # color - which color to use for the line
    #
    # Returns nothing
    def draw_selected_line(context, selected_point, selected_interval, color)

      selected_point = [selected_point, 0] if selected_point.kind_of?(Numeric)

      # draw selected line
      return unless selected_point
      point = spectrum_point_to_canvas(selected_point)

      context.lineStyle = Fox::LINE_SOLID
      context.foreground = color
      context.stipple = Fox::STIPPLE_NONE
      context.fillStyle = Fox::FILL_SOLID
      context.drawLine(point[0],
        AXIS_PADDING,
        point[0],
        self.height - AXIS_PADDING
      )

      text = selected_point[0].round(ROUND_DIGITS).to_s
      text_width = @font.getTextWidth(text)
      text_height = @font.getTextHeight(text)
      context.drawText(point[0] - text_width/2, AXIS_PADDING - 3, text)

      # draw interval
      return unless selected_interval > 0
      interval_from = spectrum_point_to_canvas(
        [selected_point[0] - selected_interval,
        selected_point[1]]
      )
      interval_to = spectrum_point_to_canvas(
        [selected_point[0] + selected_interval,
        selected_point[1]]
      )

      context.fillStyle = FILL_STIPPLED
      context.stipple = STIPPLE_2
      context.fillRectangle(interval_from[0],
        AXIS_PADDING - 1,
        interval_to[0] - interval_from[0],
        self.height - 2 * AXIS_PADDING
      )
    end

    # Checks if the canvas x value does not overlaps the graph dimension, if so
    # then it sets the limit value of the x
    #
    # x - canvas value for checking
    # Return values in graph, not some outside value
    def check_canvas_x(x)
      min_x = AXIS_PADDING
      max_x = self.width - AXIS_PADDING
      return min_x if x < min_x
      return max_x if x > max_x
      x
    end

    def mouse_pressed(sender, selector, event)
      case event.click_button
      when LEFT_MOUSE
        @zoom_from = check_canvas_x(event.click_x)
      when RIGHT_MOUSE
        spectrum_x_value = canvas_point_to_spectrum([check_canvas_x(event.last_x), 0])[0]
        case @mode
        when :single_selection
          @selected_points = [spectrum_x_value]
        when :multi_selection
        end
      end

      @pressed = event.click_button
      self.update
    end

    def mouse_released(sender, selector, event)
      case event.click_button
      when LEFT_MOUSE
        tmp = [@zoom_from, @zoom_to]
        spectrum_zoom_from = canvas_point_to_spectrum([tmp.min, 0])
        spectrum_zoom_to = canvas_point_to_spectrum([tmp.max, 0])
        zoom(spectrum_zoom_from, spectrum_zoom_to)
        @zoom_from = @zoom_from = nil
      when RIGHT_MOUSE
        case @mode
        when :single_selection
          callback(:when_select_point, @selected_points)
        when :multi_selection
        end
      end

      @pressed = NO_MOUSE
      self.update
    end

    def mouse_moved(sender, selector, event)
      return unless event.moved?
      case @pressed
      when LEFT_MOUSE
        @zoom_to = check_canvas_x(event.last_x)
      when RIGHT_MOUSE
        spectrum_x_value = canvas_point_to_spectrum([check_canvas_x(event.last_x), 0])[0]
        case @mode
        when :single_selection
          @selected_points = [spectrum_x_value]
        when :multi_selection
        end
      end

      self.update
    end

  end
end
