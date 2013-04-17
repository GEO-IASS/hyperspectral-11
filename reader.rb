require 'rubygems'
require 'fox16'
require 'fox16/colors'
require './imzml'

include Fox

class Reader < FXMainWindow

  IMAGE_WIDTH = 300
  IMAGE_HEIGHT = 300

  def initialize(app)
    super(app, "imzML Reader", :width => 1024, :height => 600)
    add_menu_bar

    @selected_x,@selected_y = 0, 0
    @scale_x, @scale_y = 1, 1
    @selected_spectrum = 0

    @imzml = nil
    @font = FXFont.new(app, "times")

    # hyperspectral image
    vertical_frame = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)
    top_horizontal_frame = FXHorizontalFrame.new(vertical_frame, :opts => LAYOUT_FILL_X)

    image_container = FXPacker.new(top_horizontal_frame, :opts => FRAME_SUNKEN|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT, :width => IMAGE_WIDTH, :height => IMAGE_HEIGHT)
    # @hyperspectral_image = FXImageView.new(nil, nil, :opts => LAYOUT_CENTER_X|LAYOUT_CENTER_Y|LAYOUT_FILL)
    @image_canvas = FXCanvas.new(image_container, :opts => LAYOUT_CENTER_X|LAYOUT_CENTER_Y|LAYOUT_FILL)
    @image_canvas.connect(SEL_PAINT, method(:canvas_repaint))
    @image_canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, sel, event|
      @selected_x, @selected_y = event.win_x, event.win_y
      @image_canvas.update
      @mouse_down = true
    end
    @image_canvas.connect(SEL_MOTION) do |sender, sel, event|
      if @mouse_down
        @selected_x, @selected_y = event.win_x, event.win_y
        @selected_y = 0 if @selected_y < 0
        @selected_y = @image_canvas.height if @selected_y > @image_canvas.height
        @selected_x = 0 if @selected_x < 0
        @selected_x = @image_canvas.width if @selected_x > @image_canvas.width

        @image_canvas.update
      end
    end
    @image_canvas.connect(SEL_LEFTBUTTONRELEASE) do |sender, sel, event|
      if @mouse_down
        @mouse_down = false
        @status_line.text = "Reading spectrum at #{image_point_x}x#{image_point_y}"
        read_data_and_create_spectrum
      end
    end

    # tab settings
    @tabbook = FXTabBook.new(top_horizontal_frame, :opts => LAYOUT_FILL_X|LAYOUT_RIGHT|LAYOUT_FILL_Y)
    @basics_tab = FXTabItem.new(@tabbook, "Basic")
    FXHorizontalFrame.new(@tabbook, FRAME_THICK|FRAME_RAISED)
    @calibration_tab = FXTabItem.new(@tabbook, "Calibration")
    FXHorizontalFrame.new(@tabbook, FRAME_THICK|FRAME_RAISED)
    @baseline_correction_tab = FXTabItem.new(@tabbook, "Baseline correction")
    FXHorizontalFrame.new(@tabbook, FRAME_THICK|FRAME_RAISED)
    @normalization_tab = FXTabItem.new(@tabbook, "Normalization")
    FXHorizontalFrame.new(@tabbook, FRAME_THICK|FRAME_RAISED)

    # spectrum part
    bottom_horizontal_frame = FXHorizontalFrame.new(vertical_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_BOTTOM|LAYOUT_RIGHT)

    @spectrum_canvas = FXCanvas.new(bottom_horizontal_frame, :opts => LAYOUT_FILL)
    @spectrum_canvas.connect(SEL_PAINT, method(:canvas_repaint))

    zoom_button_vertical_frame = FXVerticalFrame.new(bottom_horizontal_frame, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FILL_Y, :width => 50)

    # TODO implement
    FXButton.new(zoom_button_vertical_frame, "+", :opts => FRAME_RAISED|LAYOUT_FILL)
    FXButton.new(zoom_button_vertical_frame, "100%", :opts => FRAME_RAISED|LAYOUT_FILL)
    FXButton.new(zoom_button_vertical_frame, "-", :opts => FRAME_RAISED|LAYOUT_FILL)

    # status bar
    status_bar = FXStatusBar.new(vertical_frame, :opts => LAYOUT_FILL_X|LAYOUT_FIX_HEIGHT, :height => 30)
    # status_bar.cornerStyle = true
    @status_line = status_bar.statusLine

    # FIXME debug
    read_file("/Users/beny/Dropbox/School/dp/imzML/test_files/testovaci_blbost.imzML")

  end

  def image_point_x
    (@selected_x/@scale_x).to_i + 1
  end

  def image_point_y
    (@selected_y/@scale_y).to_i + 1
  end

  def create
    super

    @font.create

    show(PLACEMENT_SCREEN)
  end

  def add_menu_bar
    menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)

    # file menu
    file_menu = FXMenuPane.new(self)
    FXMenuTitle.new(menu_bar, "File", :popupMenu => file_menu)

    # open file menu
    FXMenuCommand.new(file_menu, "Open...").connect(SEL_COMMAND) do
      dialog = FXFileDialog.new(self, "Open imzML file")
      dialog.directory = "../imzML/test_files"
      dialog.patternList = ["imzML files (*.imzML)"]

      # after success on opening
      if (dialog.execute != 0)
        @progress = 0
        @progress_message = "Opening file"

        read_file(dialog.filename)
      end
    end

    exit_cmd = FXMenuCommand.new(file_menu, "Exit")
    exit_cmd.connect(SEL_COMMAND) {exit}
  end

  def read_file(filepath)

    puts "Parsing file #{filepath}"
    @datapath = filepath.gsub(/imzML$/, "ibd")
    imzml_parser = ImzMLParser.new()
    @progress_message = "Parsing imzML file"
    File.open(filepath, 'r') do |f|
      Ox.sax_parse(imzml_parser, f)
    end

    @imzml = imzml_parser.metadata
    puts "Parsing done"

    read_data_and_create_spectrum
    read_data_and_create_hyperspectral_image
  end

  def read_data_and_create_spectrum
    # get spectrum min and max data

    @selected_spectrum = image_point_x * image_point_y
    @mz_array = @imzml.spectrums.first.mz_array(@datapath)
    @mz_min = @mz_array.first
    @mz_max = @mz_array.last
    @intensity_array = @imzml.spectrums[@selected_spectrum].intensity_array(@datapath)
    @intensity_max = @intensity_array.max
    @intensity_min = @intensity_array.min

    @spectrum_canvas.update
  end

  def read_data_and_create_hyperspectral_image
    image = FXImage.new(getApp(), nil, IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP, :width => @imzml.pixel_count_x, :height => @imzml.pixel_count_y)

    scale_w = IMAGE_WIDTH
    scale_h = IMAGE_HEIGHT
    if image.width > image.height
      scale_h = image.height.to_f/image.width.to_f * IMAGE_HEIGHT
    else
      scale_w = image.width.to_f/image.height.to_f * IMAGE_WIDTH
    end
    image.pixels = image_data
    @scale_x, @scale_y = scale_h/image.height, scale_w/image.width
    image.scale(scale_w - 10, scale_h - 10)
    image.create
    @image = image
    @image_canvas.update
  end

  def image_data

    data = @imzml.image_data(@datapath, 2568.0, 0.1)

    # row, column, i = 0, 0, 0
    # direction_right = true

    max_normalized = data.max - data.min
    min = data.min
    step = 255.0 / max_normalized

    data.map do |i|
      value = (step * (i - min)).to_i
      # puts "Color value for #{i} is (#{value}, #{value}, #{value})}"
      FXRGB(value, value, value)
    end

    # data.each do |value|
    #   # p value
    #   # p "#{column}, #{row}"
    #   color_value = step * (value - min)
    #   f[column, row] = FXRGB(color_value.to_i, color_value.to_i, color_value.to_i)
    #   direction_right ? column += 1 : column -= 1
    #
    #   if (column >= @pixel_count_x || column < 0)
    #     row += 1
    #
    #     direction_right = (row % 2 == 0)
    #     # direction_right = true
    #     direction_right ? column = 0 : column -= 1
    #   end
    # end

  end

  def canvas_repaint(sender, sel, event)
    FXDCWindow.new(sender, event) do |dc|
      case sender
      when @spectrum_canvas
        # draw background
        dc.foreground = FXColor::White
        dc.fillRectangle(event.rect.x, event.rect.y, event.rect.w, event.rect.h)

        # draw axis
        dc.foreground = FXColor::Black
        axis_padding = 30
        line_indicator_height = 5

        # x axis
        dc.drawLine(axis_padding, event.rect.h - axis_padding, event.rect.w - axis_padding, event.rect.h - axis_padding)

        # y axis
        dc.drawLine(axis_padding, event.rect.h - axis_padding, axis_padding, axis_padding)

        dc.font = @font
        dc.drawText(axis_padding/2, event.rect.h - axis_padding/2, "0")

        # draw line only when sent event is correct
        if (@imzml && event.rect.w > axis_padding && event.rect.h > axis_padding)

          # axis dimensions
          x_axis_width = event.rect.w - 2 * axis_padding
          x_point_size = x_axis_width / @mz_max
          y_axis_height = event.rect.h - 2 * axis_padding
          y_point_size = y_axis_height / @intensity_max
          y_baseline = event.rect.h - axis_padding - 1

          # draw number lines
          dc.lineStyle = LINE_ONOFF_DASH
          dc.drawLine(event.rect.w / 2, event.rect.h - axis_padding + line_indicator_height, event.rect.w/2, axis_padding + line_indicator_height)
          # dc.drawLine(axis_padding - line_indicator_height, event.rect.h/2, event.rect.w - axis_padding, event.rect.h/2)
          dc.lineStyle = LINE_SOLID

          # draw mz numbers
          dc.drawText(event.rect.w / 2, event.rect.h - axis_padding/2, (@mz_max/2).round(2).to_s)
          dc.drawText(event.rect.w - 2 * axis_padding, event.rect.h - axis_padding/2, @mz_max.round(2).to_s)

          # draw intensitu numbers
          dc.drawText(0, event.rect.h/2, (@intensity_max/2).round(2).to_s)
          dc.drawText(0, axis_padding + axis_padding/2, @intensity_max.round(2).to_s)

          # map spectrum points to canvas
          points = @mz_array.zip(@intensity_array).map{|coords| FXPoint.new(axis_padding + (coords[0]*x_point_size).to_i, y_baseline - (coords[1] * y_point_size).to_i)}

          # draw spectrum line
          dc.foreground = FXColor::Red
          dc.drawLines(points)
        end
      when @image_canvas

        # clear canvas
        dc.foreground = FXColor::White
        dc.fillRectangle(0, 0, @image_canvas.width, @image_canvas.height)

        # draw image
        if @image
          dc.drawImage(@image, 0, 0)
        end

        # draw cross
        dc.foreground = FXColor::Green
        dc.drawLine(@selected_x, 0, @selected_x, event.rect.h)
        dc.drawLine(0, @selected_y, event.rect.w, @selected_y)
        @status_line.normalText = "Selected point #{image_point_x}x#{image_point_y}"
        @status_line.text = @status_line.normalText
      end
    end
  end

end

if __FILE__ == $0
  FXApp.new do |app|
    Reader.new(app)
    app.create
    app.run
  end
end