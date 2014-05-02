module Hyperspectral

  class SpectrumController

    include Callbacks

    # Array of spectrum points where each poin is subarray with just two items
    attr_accessor :points

    # Array with selectd points, after change, display it on spectrum canvas
    attr_accessor :selected_points

    # Interval which may be used to draw the image
    attr_accessor :selected_interval

    def points=(points)
      @points = points
      @spectrum_canvas.spectrum = points
      @spectrum_canvas.update
    end

    def selected_points=(points)
      @selected_points = points
      @spectrum_canvas.selected_points = points
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

    def zoom_in_pressed(sender, selector, event)
      @spectrum_canvas.zoom_in
    end

    def zoom_reset_pressed(sender, selector, event)
      @spectrum_canvas.zoom_reset
    end

    def zoom_out_pressed(sender, selector, event)
      @spectrum_canvas.zoom_out
    end

    private

    # Views
    attr_accessor :spectrum_canvas

  end

end