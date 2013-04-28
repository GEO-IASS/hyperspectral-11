require 'rubygems'
require 'fox16'
require 'fox16/colors'
require 'debugger'
require './imzml'
require './ox'


include Fox

class Reader < FXMainWindow

  IMAGE_WIDTH = 300
  IMAGE_HEIGHT = 300
  AXIS_PADDING = 30
  DEFAULT_DIR = "../imzML/"
  ROUND_DIGITS = 4

  def initialize(app)
    super(app, "imzML Reader", :width => 800, :height => 600)
    add_menu_bar

    # progress dialog
    @progress_dialog = FXProgressDialog.new(self, "Please wait", "Loading data")
    @progress_dialog.connect(SEL_UPDATE) do |sender, sel, event|
      if sender.progress >= sender.total
        sender.handle(sender, MKUINT(FXDialogBox::ID_ACCEPT, SEL_COMMAND), nil)
      end
    end

    @main_frame = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)

    # create main UI parts
    add_image_part
    add_spectrum_part

    # status bar
    status_bar = FXStatusBar.new(@main_frame, :opts => LAYOUT_FILL_X|LAYOUT_FIX_HEIGHT, :height => 30)
    @status_line = status_bar.statusLine

    # prepare resources
    add_resources
  end

  def add_menu_bar
    menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)

    # file menu
    file_menu = FXMenuPane.new(self)
    FXMenuTitle.new(menu_bar, "File", :popupMenu => file_menu)

    # open file menu
    FXMenuCommand.new(file_menu, "Open...").connect(SEL_COMMAND) do
      dialog = FXFileDialog.new(self, "Open imzML file")
      dialog.directory = "#{DEFAULT_DIR}"
      dialog.patternList = ["imzML files (*.imzML)"]

      # after success on opening
      if (dialog.execute != 0)

        # show progress dialog and starts thread
        run_on_background(3) do
          read_file(dialog.filename)
        end

      end
    end

    exit_cmd = FXMenuCommand.new(file_menu, "Exit")
    exit_cmd.connect(SEL_COMMAND) {exit}
  end

  def add_image_part
    # hyperspectral image
    top_horizontal_frame = FXHorizontalFrame.new(@main_frame, :opts => LAYOUT_FILL_X)

    image_container = FXPacker.new(top_horizontal_frame, :opts => FRAME_SUNKEN|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT, :width => IMAGE_WIDTH, :height => IMAGE_HEIGHT)
    @image_canvas = FXCanvas.new(image_container, :opts => LAYOUT_CENTER_X|LAYOUT_CENTER_Y|LAYOUT_FILL)
    @image_canvas.connect(SEL_PAINT, method(:draw_canvas))
    @image_canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, sel, event|
      if @imzml
        @selected_x, @selected_y = event.win_x, event.win_y
        @image_canvas.update
        @mouse_right_down = true
      end
    end
    @image_canvas.connect(SEL_MOTION) do |sender, sel, event|
      if @mouse_right_down
        @selected_x, @selected_y = event.win_x, event.win_y
        @selected_y = 0 if @selected_y < 0
        @selected_y = @image_canvas.height if @selected_y > @image_canvas.height
        @selected_x = 0 if @selected_x < 0
        @selected_x = @image_canvas.width if @selected_x > @image_canvas.width
        @image_canvas.update
      end
    end
    @image_canvas.connect(SEL_LEFTBUTTONRELEASE) do |sender, sel, event|
      if @mouse_right_down
        @mouse_right_down = false

        @mz_from = @mz_to = nil

        create_spectrum
      end
    end

    # tab settings
    @tabbook = FXTabBook.new(top_horizontal_frame, :opts => LAYOUT_FILL_X|LAYOUT_RIGHT|LAYOUT_FILL_Y)
    @basics_tab = FXTabItem.new(@tabbook, "Basic")
    matrix = FXMatrix.new(@tabbook, :opts => FRAME_THICK|FRAME_RAISED|LAYOUT_FILL_X)
    matrix.numColumns = 2
    matrix.numRows = 2
    FXLabel.new(matrix, "m/z value", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
    FXLabel.new(matrix, "interval value", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
    @mz_textfield = FXTextField.new(matrix, 10, :opts => LAYOUT_CENTER_Y|LAYOUT_CENTER_X|FRAME_SUNKEN|FRAME_THICK|TEXTFIELD_REAL)
    @mz_textfield.connect(SEL_COMMAND) do |sender, sel, event|
      if sender.text.size > 0
        # find the closest existing point and set as mz value
        index = @mz_array.index{|x| x >= sender.text.to_f}
        @selected_mz = @mz_array[index]
        sender.text = @selected_mz.round(ROUND_DIGITS).to_s

        run_on_background do
          create_image
        end
      end
    end
    @interval_textfield = FXTextField.new(matrix, 10, :opts => LAYOUT_CENTER_Y|LAYOUT_CENTER_X|FRAME_SUNKEN|FRAME_THICK|TEXTFIELD_REAL)
    @interval_textfield.connect(SEL_COMMAND) do |sender, sel, event|
      if sender.text.size > 0
        @selected_interval = sender.text.to_f
        @spectrum_canvas.update

        run_on_background do
          create_image
        end
      end
    end
  end

  def add_spectrum_part
    # spectrum part
    bottom_horizontal_frame = FXHorizontalFrame.new(@main_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_BOTTOM|LAYOUT_RIGHT)

    @spectrum_canvas = FXCanvas.new(bottom_horizontal_frame, :opts => LAYOUT_FILL)
    @spectrum_canvas.connect(SEL_PAINT, method(:draw_canvas))
    @spectrum_canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, sel, event|
      if @imzml
        @mouse_right_down = true
        @spectrum_canvas.grab
        @zoom_from_x = event.win_x - AXIS_PADDING
        @zoom_from_x = @x_axis_width if @zoom_from_x > @x_axis_width
        @zoom_from_x = 0 if @zoom_from_x < 0
      end
    end
    @spectrum_canvas.connect(SEL_MOTION) do |sender, sel, event|
      if @mouse_right_down
        @zoom_to_x = event.win_x - AXIS_PADDING
        @zoom_to_x = @x_axis_width if @zoom_to_x > @x_axis_width
        @zoom_to_x = 0 if @zoom_to_x < 0
        @status_line.text = "Zoom from #{@mz_array[@zoom_from_x/@x_point_size]} to #{@mz_array[@zoom_to_x/@x_point_size]}"
        @spectrum_canvas.update
      elsif @mouse_left_down
        selected_mz_x = event.win_x - AXIS_PADDING
        selected_mz_x = @x_axis_width if selected_mz_x > @x_axis_width
        selected_mz_x = 0 if selected_mz_x < 0
        selected_mz_x = (selected_mz_x / @x_point_size).to_i
        @selected_mz = @mz_array[selected_mz_x]
        @status_line.text = "Selected MZ value #{@selected_mz}"
        @spectrum_canvas.update
      end
    end
    @spectrum_canvas.connect(SEL_LEFTBUTTONRELEASE) do |sender, sel, event|
      if @mouse_right_down
        @spectrum_canvas.ungrab
        @mouse_right_down = false

        # zoom to selected values
        from = (@zoom_to_x > @zoom_from_x) ? @zoom_from_x : @zoom_to_x
        to = (@zoom_to_x > @zoom_from_x) ? @zoom_to_x : @zoom_from_x
        from = @mz_from + (from/ @x_point_size).to_i
        to = @mz_from + (to / @x_point_size).to_i
        @mz_from = from
        @mz_to = to

        # remove selectiong frame
        @zoom_to_x = @zoom_from_x = nil

        create_spectrum
      end
    end
    @spectrum_canvas.connect(SEL_RIGHTBUTTONPRESS) do |sender, sel, event|
      if @imzml
        @mouse_left_down = true
        @spectrum_canvas.grab
      end
    end
    @spectrum_canvas.connect(SEL_RIGHTBUTTONRELEASE) do |sender, sel, event|
      if @mouse_left_down
        @spectrum_canvas.ungrab
        @mouse_left_down = false
        @mz_textfield.text = @selected_mz.round(ROUND_DIGITS).to_s if !@selected_mz.nil?

        run_on_background do
          create_image
        end
      end
    end

    zoom_button_vertical_frame = FXVerticalFrame.new(bottom_horizontal_frame, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FILL_Y, :width => 50)

    # zoom buttons
    zoom_in_button = FXButton.new(zoom_button_vertical_frame, "+", :opts => FRAME_RAISED|LAYOUT_FILL)
    zoom_in_button.connect(SEL_COMMAND) do
      if @mz_to - @mz_from > 20
        diff = (@mz_to - @mz_from)/2
        middle = @mz_from + diff

        @mz_from = middle - diff/2
        @mz_to = middle + diff/2

        create_spectrum
      end
    end

    zoom_reset_buttom = FXButton.new(zoom_button_vertical_frame, "100%", :opts => FRAME_RAISED|LAYOUT_FILL)
    zoom_reset_buttom.connect(SEL_COMMAND) do
      @mz_from = nil
      @mz_to = nil

      create_spectrum
    end

    zoom_out_button = FXButton.new(zoom_button_vertical_frame, "-", :opts => FRAME_RAISED|LAYOUT_FILL)
    zoom_out_button.connect(SEL_COMMAND) do
      diff = (@mz_to - @mz_from)/2
      middle = @mz_from + diff

      @mz_from = middle - diff*2
      @mz_to = middle + diff*2

      create_spectrum
    end
  end

  def add_resources
    @font = FXFont.new(app, "times")
  end

  def create
    super

    create_resources
    reset_to_default_values

    show(PLACEMENT_SCREEN)

    # FIXME debug
    run_on_background do
      # read_file("/Users/beny/Dropbox/School/dp/imzML/example_files/Example_Continuous.imzML")
      read_file("/Users/beny/Dropbox/School/dp/imzML/s043_processed/S043_Processed.imzML")
      
    end
  end

  def create_resources
    @font.create
  end

  def create_spectrum

    log("Reading spectrum data") do

      # get spectrum min and max data
      @selected_spectrum = (((@selected_y/@scale_y).to_i + 1) - 1) * @imzml.pixel_count_x + (((@selected_x/@scale_x).to_i + 1) - 1)

      @mz_array = @imzml.spectrums[@selected_spectrum].mz_array(@datapath)
      mz_min = @mz_array.first
      mz_max = @mz_array.last
      default_from, default_to = 0, @mz_array.size - 1

      # set default values
      @mz_from ||= default_from
      @mz_to ||= default_to

      # check top boundaries
      @mz_from = default_from if @mz_from < default_from
      @mz_to = default_to if @mz_to > default_to

      @mz_array = @mz_array[@mz_from..@mz_to]

      @intensity_array = @imzml.spectrums[@selected_spectrum].intensity_array(@datapath)
      @intensity_array = @intensity_array[@mz_from..@mz_to]
      @intensity_max = @intensity_array.max
      @intensity_min = @intensity_array.min

    end

    calculate_interval_indexes

    @progress_dialog.increment(1)
    @spectrum_canvas.update
  end

  def create_image

    log("Creating hyperspectral image") do

      image = FXImage.new(getApp(), nil, IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP, :width => @imzml.pixel_count_x, :height => @imzml.pixel_count_y)

      scale_w = IMAGE_WIDTH
      scale_h = IMAGE_HEIGHT
      if image.width > image.height
        scale_h = image.height.to_f/image.width.to_f * IMAGE_HEIGHT
      else
        scale_w = image.width.to_f/image.height.to_f * IMAGE_WIDTH
      end
      image.pixels = create_image_pixels
      @scale_x, @scale_y = scale_h/image.height, scale_w/image.width
      image.scale(scale_w - 10, scale_h - 10)
      image.create
      @image = image

    end

    calculate_interval_indexes

    @progress_dialog.increment(1)
    @image_canvas.update
  end

  def reset_to_default_values
    @imzml = nil
    @selected_x, @selected_y = 0, 0
    @scale_x, @scale_y = 1, 1
    @selected_spectrum = 0
    @selected_mz = nil
    @selected_interval = 0
    @selected_interval_low = @selected_interval_high = nil

    @interval_textfield.text = @selected_interval.to_s
  end

  def calculate_interval_indexes
    if @selected_interval && @selected_mz

      # find the closest interval values
      @selected_interval_low = @mz_array.index{|x| x >= @selected_mz - @selected_interval}
      @selected_interval_high = @mz_array.index{|x| x >= @selected_mz + @selected_interval}
      @spectrum_canvas.update
    end
  end

  def read_file(filepath)

    reset_to_default_values

    log("Parsing imzML file") do
      
      @filename = filepath.split("/").last
      self.title = @filename
      @datapath = filepath.gsub(/imzML$/, "ibd")
      imzml_parser = ImzMLParser.new()
      File.open(filepath, 'r') do |f|
        Ox.sax_parse(imzml_parser, f)
      end

      @imzml = imzml_parser.metadata
    end

    @progress_dialog.increment(1)

    create_spectrum
    create_image
  end

  def create_image_pixels

    @progress_dialog.total += @imzml.spectrums.size
    data = @imzml.image_data(@datapath, @selected_mz, @selected_interval) do |id|
      @progress_dialog.increment(1)
    end
    
    
    # remve nil values
    data.map{|x| x.nil? ? 0 :x}
    
    # normalize value into greyscale
    max_normalized = data.max - data.min
    max_normalized = 1 if max_normalized == 0
    min = data.min
    step = 255.0 / max_normalized
    data.map do |i|
      value = (step * (i - min)).to_i
      FXRGB(value, value, value)
    end

  end

  def draw_canvas(sender, sel, event)
    if sender && sel && event
      FXDCWindow.new(sender, event) do |dc|
        case sender
        when @spectrum_canvas
          # draw background
          dc.foreground = FXColor::White
          dc.fillRectangle(0, 0, sender.width, sender.height)

          # draw axis
          dc.foreground = FXColor::Black

          # x and y axis
          dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, sender.width - AXIS_PADDING, sender.height - AXIS_PADDING)
          dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, AXIS_PADDING, AXIS_PADDING)

          # y axis description
          dc.font = @font
          dc.drawText(AXIS_PADDING/2, sender.height - AXIS_PADDING, "0")

          if @imzml

            # axis dimensions
            @x_axis_width = sender.width - 2 * AXIS_PADDING
            @x_point_size = @x_axis_width.to_f / (@mz_array.size - 1).to_f
            y_axis_height = sender.height - 2 * AXIS_PADDING
            y_point_size = y_axis_height / @intensity_max
            y_baseline = sender.height - AXIS_PADDING - 1

            # draw mz numbers
            dc.drawText(AXIS_PADDING, sender.height - AXIS_PADDING/2, @mz_array.first.round(ROUND_DIGITS).to_s)
            center_text = (@mz_array[@mz_array.size/2]).round(ROUND_DIGITS).to_s
            dc.drawText(sender.width / 2, sender.height - AXIS_PADDING/2, center_text)
            dc.drawText(sender.width - 2 * AXIS_PADDING, sender.height - AXIS_PADDING/2, @mz_array.last.round(ROUND_DIGITS).to_s)

            # draw intensity numbers
            dc.drawText(5, sender.height/2, (@intensity_max/2).round(ROUND_DIGITS).to_s)
            dc.drawText(5, AXIS_PADDING + AXIS_PADDING/2, @intensity_max.round(ROUND_DIGITS).to_s)

            # map spectrum points to canvas
            i = 0.0
            points = @mz_array.zip(@intensity_array).map do |coords|
              x_point = (AXIS_PADDING + 1 + i).to_i
              y_point = y_baseline - (coords[1] * y_point_size).to_i
              i += @x_point_size
              FXPoint.new(x_point, y_point)
            end

            # draw spectrum line
            dc.foreground = FXColor::Red
            dc.drawLines(points)

            # draw selected mz
            if @selected_mz && @selected_mz >= @mz_array.first && @selected_mz <= @mz_array.last
              index = @mz_array.index(@selected_mz)
              
              raise "Selected index is not in this spectrum" if index.nil?
              
              line_x = AXIS_PADDING + index * @x_point_size
              dc.foreground = FXColor::Blue

              dc.drawLine(line_x, sender.height - AXIS_PADDING, line_x, AXIS_PADDING)
              text =
              dc.drawText(line_x - 5, (sender.height - AXIS_PADDING/2) + @font.getTextHeight(center_text), @selected_mz.round(ROUND_DIGITS).to_s)

              dc.lineStyle = LINE_ONOFF_DASH
              # interval lines
              if @selected_interval_low && @selected_interval_high
                line_x = AXIS_PADDING + @selected_interval_low * @x_point_size
                dc.drawLine(line_x, sender.height - AXIS_PADDING, line_x, AXIS_PADDING)
                line_x = AXIS_PADDING + @selected_interval_high * @x_point_size
                dc.drawLine(line_x, sender.height - AXIS_PADDING, line_x, AXIS_PADDING)
              end
              dc.lineStyle = LINE_SOLID
            end

            # draw zoom rect
            if @zoom_from_x && @zoom_to_x
              dc.foreground = FXColor::Blue
              start_from = (@zoom_from_x > @zoom_to_x) ? @zoom_to_x : @zoom_from_x
              dc.drawRectangle(AXIS_PADDING + start_from, AXIS_PADDING, (@zoom_from_x - @zoom_to_x).abs, sender.height - 2 * AXIS_PADDING)
            end
          end
        when @image_canvas

          # clear canvas
          dc.foreground = FXColor::White
          dc.fillRectangle(0, 0, @image_canvas.width, @image_canvas.height)

          # draw image
          if @image
            dc.drawImage(@image, 0, 0)
          end

          if @imzml
            # draw cross
            dc.foreground = FXColor::Green
            dc.drawLine(@selected_x, 0, @selected_x, sender.height)
            dc.drawLine(0, @selected_y, sender.width, @selected_y)
            @status_line.text = @status_line.normalText
          end
        end
      end
    end
  end

  private

  def run_on_background(operations_count = 1)
    @progress_dialog.progress = 0
    @progress_dialog.total = operations_count
    Thread.new {
      yield
    }
    @progress_dialog.execute(PLACEMENT_OWNER)
  end

  def log(message = "Please wait")
    start = Time.now

    message = "#{message} ... "
    @progress_dialog.message = message
    print message
    yield
    print "#{Time.now - start}s\n"
  end

end

if __FILE__ == $0
  FXApp.new do |app|
    Reader.new(app)
    app.create
    app.run
  end
end