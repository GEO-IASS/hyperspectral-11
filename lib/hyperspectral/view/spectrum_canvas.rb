module Hyperspectral

  # Class representing the UI element for drawing the spectrum
  class SpectrumCanvas < Fox::FXCanvas

    include Callbacks

    # The currently displayed full spectrum
    attr_accessor :spectrum

    # Array used for preview one preprocessing step with current spectrum
    attr_accessor :preview_points

    # Array of selected point (in spectrum coords) which should be drawn
    attr_accessor :selected_points

    # When selecting point for image drawing the interval value is sometimes needed
    attr_accessor :selected_interval

    # Bool determinig if the position cross with coordinates is shown
    attr_accessor :show_cross

    # Boundaries for currently visible spectrum
    attr_accessor :spectrum_min_x, :spectrum_max_x, :spectrum_min_y,
      :spectrum_max_y

    attr_accessor :zoom_from, :zoom_to

    # Init method
    #
    # superview - instance of Fox::FXWindo
    def initialize(superview)
      super(superview, :opts => Fox::LAYOUT_FILL)

      @font = Fox::FXFont.new(app, "times")
      @font.create

      @selected_interval = 0

      connect(Fox::SEL_PAINT, method(:draw))

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

    # Redraw canvas after interval selection
    def selected_interval=(interval)
      @selected_interval = interval
      self.update
    end

    # Resets spectrum point cache
    #
    # Returns nothing
    def reset_cache
      @cached_spectrum = nil
    end

    # Converting canvas point to spectrum point
    #
    # canvas_point - point in the canvas
    #
    # Returns point in spectrum domain
    def canvas_point_to_spectrum(canvas_point)
      # map points
      x_point_origin = canvas_point.x
      y_point_origin = canvas_point.y

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
      x_point_origin = spectrum_point.x
      y_point_origin = spectrum_point.y

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

    # ===========
    # = private =
    # ===========
    private

    AXIS_PADDING = 30

    LABEL_X_SPACING = 40
    LABEL_Y_SPACING = 40

    LABEL_X_PADDING = 3
    LABEL_Y_PADDING = 3

    # Cache for currently visible points
    attr_accessor :cached_spectrum

    # Spectrum part drawing method
    #
    # Returns nothing
    def draw(sender, selector, event)
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

        return unless @spectrum && @spectrum_min_x && @spectrum_min_x

        preview_points = Array.new

        # ===============================================
        # = calculate spectrum points and save to cache =
        # ===============================================
        if @cached_spectrum.nil?

          points = Array.new

          previous_point = nil

          # convert spectrum points and create canvas points
          @spectrum.each do |mz, intensity|

            point = spectrum_point_to_canvas([mz, intensity])
            points << Fox::FXPoint.new(point.x.to_i, point.y.to_i)
          end

          # preview points
          @preview_points.each do |mz, intensity|

            point = spectrum_point_to_canvas([mz, intensity])
            preview_points << Fox::FXPoint.new(point.x.to_i, point.y.to_i)
          end if @preview_points

          @cached_spectrum = points
        end

        # load from cache
        points = @cached_spectrum

        # ===============
        # = draw labels =
        # ===============
        labels = Array.new
        spectrum = @spectrum.to_a

        x = AXIS_PADDING
        while x < (sender.width - AXIS_PADDING) do
          point = [x, sender.height - AXIS_PADDING]
          spectrum_point = canvas_point_to_spectrum(point)
          text = spectrum_point.x.round(3).to_s
          text_width = @font.getTextWidth(text)
          dc.drawLine(point.x.to_i, self.height - AXIS_PADDING + 3, point.x.to_i, sender.height - AXIS_PADDING)
          dc.drawText(point.x.to_i - text_width/2, sender.height - AXIS_PADDING / 2, text)
          x += text_width + LABEL_X_SPACING
        end

        y = sender.height - AXIS_PADDING
        while y > AXIS_PADDING do
          point = [LABEL_X_SPACING, y]
          spectrum_point = canvas_point_to_spectrum(point)
          text = spectrum_point.y.round(3).to_s
          text_width = @font.getTextWidth(text)
          text_height = @font.getTextHeight(text)
          dc.drawLine(AXIS_PADDING - 3, point.y.to_i, AXIS_PADDING, point.y.to_i)
          dc.drawText(AXIS_PADDING - text_width - 3, point.y.to_i + text_height/2, text)
          y -= text_height + LABEL_Y_SPACING
        end

        # ======================
        # = draw spectrum line =
        # ======================
        dc.foreground = Fox::FXColor::Red
        dc.drawLines(points)

        # =====================
        # = Draw preview line =
        # =====================
        dc.foreground = Fox::FXColor::Blue
        dc.drawLines(preview_points)

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
          draw_selected_line(dc, spectrum_point, @selected_interval, Fox::FXColor::SteelBlue)
        end if @selected_points

        # ==================
        # = position cross =
        # ==================
        if @show_cross

          mouse_point = [event.last_x, event.last_y]
          spectrum_point = canvas_point_to_spectrum(mouse_point)

          position_text = "#{spectrum_point.x.round(3)} x #{spectrum_point.y.round(3)}"
          text_width = @font.getTextWidth(position_text)
          text_height = @font.getTextHeight(position_text)

          # draw rectangle under the position text
          dc.foreground = dc.background = Fox::FXColor::White
          dc.fillRectangle(mouse_point.x,
            mouse_point.y - text_height,
            text_width + 2 * LABEL_X_PADDING,
            text_height + LABEL_Y_PADDING
          )

          # draw the actual value
          dc.foreground = Fox::FXColor::LightSlateGray
          dc.drawText(mouse_point.x + LABEL_X_PADDING,
            mouse_point.y - LABEL_Y_PADDING,
            position_text
          )

          # draw lines
          dc.lineStyle = Fox::LINE_ONOFF_DASH
          dc.drawLine(mouse_point.x, 0, mouse_point.x, self.height)
          dc.drawLine(0, mouse_point.y, self.width, mouse_point.y)
        end
      end
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

      # save the styles config
      prev_fill = context.fillStyle
      prev_stipple = context.stipple
      prev_color = context.foreground
      prev_line = context.lineStyle

      context.lineStyle = Fox::LINE_SOLID
      context.foreground = color
      context.stipple = Fox::STIPPLE_NONE
      context.fillStyle = Fox::FILL_SOLID
      context.drawLine(point.x,
        AXIS_PADDING,
        point.x,
        self.height - AXIS_PADDING
      )

      text = selected_point.x.round(3).to_s
      text_width = @font.getTextWidth(text)
      text_height = @font.getTextHeight(text)
      context.drawText(point.x - text_width/2, AXIS_PADDING - 3, text)

      # draw interval
      return unless selected_interval > 0
      interval_from = spectrum_point_to_canvas(
        [selected_point.x - selected_interval,
        selected_point.y]
      )
      interval_to = spectrum_point_to_canvas(
        [selected_point.x + selected_interval,
        selected_point.y]
      )


      context.fillStyle = Fox::FILL_STIPPLED

      context.stipple = Fox::STIPPLE_2
      context.fillRectangle(interval_from[0],
        AXIS_PADDING - 1,
        interval_to[0] - interval_from[0],
        self.height - 2 * AXIS_PADDING
      )

      # set the styles back
      context.stipple = prev_stipple
      context.fillStyle = prev_fill
      context.foreground = prev_color
      context.lineStyle = prev_line
    end

  end
end
