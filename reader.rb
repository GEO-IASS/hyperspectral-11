require 'rubygems'
require 'fox16'
require 'fox16/colors'

require './imzml'
require './ox'

require 'debugger'
require 'perftools'

include Fox

class Reader < FXMainWindow

  IMAGE_WIDTH = 300
  IMAGE_HEIGHT = 300
  AXIS_PADDING = 30
  DEFAULT_DIR = "../imzML/"
  DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/example_files/Example_Continuous.imzML"
  # DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/example_files/Example_Processed.imzML"
  # DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/s043_processed/S043_Processed.imzML"
  # DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/test_files/testovaci_blbost.imzML"
  ROUND_DIGITS = 4

  def initialize(app)
    super(app, "imzML Reader", :width => 800, :height => 600)
    add_menu_bar

    # progress dialog
    @progress_dialog = FXProgressDialog.new(self, "Please wait", "Loading data")
    @progress_dialog.total = 0
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
        run_on_background do
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

        update_visible_spectrum
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
    # FXLabel.new(matrix, "spectrum", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
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
      if @visible_spectrum
        @mouse_right_down = true
        @spectrum_canvas.grab
        @zoom_from = canvas_point_to_spectrum([event.win_x, event.win_y])
      end
    end
    @spectrum_canvas.connect(SEL_MOTION) do |sender, sel, event|
      if @mouse_right_down
        @zoom_to = canvas_point_to_spectrum([event.win_x, event.win_y])
        @status_line.text = "Zoom from #{@zoom_from.first} to #{@zoom_to.first}"
        @spectrum_canvas.update
      elsif @mouse_left_down
    #     selected_mz_x = event.win_x - AXIS_PADDING
    #     selected_mz_x = @x_axis_width if selected_mz_x > @x_axis_width
    #     selected_mz_x = 0 if selected_mz_x < 0
    #     selected_mz_x = (selected_mz_x / @x_point_size).to_i
    #     @selected_mz = @mz_array[selected_mz_x]
    #     @status_line.text = "Selected MZ value #{@selected_mz}"
        @spectrum_canvas.update
      end
    end
    @spectrum_canvas.connect(SEL_LEFTBUTTONRELEASE) do |sender, sel, event|
      if @mouse_right_down
        @spectrum_canvas.ungrab
        @mouse_right_down = false
        
        update_visible_spectrum
      end
    end
    
    # @spectrum_canvas.connect(SEL_RIGHTBUTTONPRESS) do |sender, sel, event|
    #   if @imzml
    #     @mouse_left_down = true
    #     @spectrum_canvas.grab
    #   end
    # end
    # @spectrum_canvas.connect(SEL_RIGHTBUTTONRELEASE) do |sender, sel, event|
    #   if @mouse_left_down
    #     @spectrum_canvas.ungrab
    #     @mouse_left_down = false
    #     @mz_textfield.text = @selected_mz.round(ROUND_DIGITS).to_s if !@selected_mz.nil?
    # 
    #     run_on_background do
    #       create_image
    #     end
    #   end
    # end

    zoom_button_vertical_frame = FXVerticalFrame.new(bottom_horizontal_frame, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FILL_Y, :width => 50)

    # zoom buttons
    zoom_in_button = FXButton.new(zoom_button_vertical_frame, "+", :opts => FRAME_RAISED|LAYOUT_FILL)
    zoom_in_button.connect(SEL_COMMAND) do
      
      visible_spectrum = @visible_spectrum.to_a
      
      # recalculate zoom in values
      if (visible_spectrum.size > 4)
        quarter = (visible_spectrum.last.first - visible_spectrum.first.first) / 4
        zoom_begin = visible_spectrum.first.first + quarter
        zoom_end = visible_spectrum.last.first - quarter
      
        @zoom_from = [zoom_begin, nil]
        @zoom_to = [zoom_end, nil]
        
        update_visible_spectrum
      end
    end

    zoom_reset_buttom = FXButton.new(zoom_button_vertical_frame, "100%", :opts => FRAME_RAISED|LAYOUT_FILL)
    zoom_reset_buttom.connect(SEL_COMMAND) do
      spectrum = @spectrum.to_a
      @zoom_from = [spectrum.first.first, nil]
      @zoom_to = [spectrum.last.first, nil]

      update_visible_spectrum
    end

    zoom_out_button = FXButton.new(zoom_button_vertical_frame, "-", :opts => FRAME_RAISED|LAYOUT_FILL)
    zoom_out_button.connect(SEL_COMMAND) do
      visible_spectrum = @visible_spectrum.to_a
      spectrum = @spectrum.to_a
      
      # recalculate zoom out values
      if (visible_spectrum.size > 4)
        quarter = (visible_spectrum.last.first - visible_spectrum.first.first) / 4
        zoom_begin = visible_spectrum.first.first - quarter
        zoom_end = visible_spectrum.last.first + quarter
        
        # limit to the spectrum values
        zoom_begin = spectrum.first.first if zoom_begin < spectrum.first.first
        zoom_end = spectrum.last.first if zoom_end > spectrum.last.first
      
        @zoom_from = [zoom_begin, nil]
        @zoom_to = [zoom_end, nil]
        
        update_visible_spectrum
      end

    end
  end

  def add_resources
    @font = FXFont.new(app, "times")
  end

  def canvas_point_to_spectrum(canvas_point)
    # map points
    x_point_origin = canvas_point.first
    y_point_origin = canvas_point.last
    
    # find axis dimensions
    x_axis_width = @spectrum_canvas.width - 2 * AXIS_PADDING
    y_axis_height = @spectrum_canvas.height - 2 * AXIS_PADDING
    
    # calculate x point
    x_point_spectrum = if x_point_origin <= AXIS_PADDING then @spectrum_min_x
    elsif x_point_origin >= (AXIS_PADDING + x_axis_width) then @spectrum_max_x
    else
      x_diff = @spectrum_max_x - @spectrum_min_x
      x_point_size = x_axis_width / x_diff
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

  def create
    super

    create_resources
    reset_to_default_values

    show(PLACEMENT_SCREEN)

    # FIXME debug
    run_on_background do
      read_file(DEBUG_DIR)
    end
  end

  def create_average_spectrum
    log("Calculating average spectrum") do

      dictionary = Hash.new
      sum = @imzml.spectrums.size
      
      @progress_dialog.total += sum
      
      # add all values
      @imzml.spectrums.each do |s|
        
        mz_array = s.mz_array(@datapath)
        intensity_array = s.intensity_array(@datapath)
        
        # create data array
        mz_array.zip(intensity_array).each do |key_value|
          key = key_value.first
          value = key_value.last
          
          dictionary[key] ||= 0
          dictionary[key] += value
        end
        
        # save average spectrum
        @spectrum = dictionary
        @visible_spectrum = dictionary.dup
        @average_spectrum = dictionary.dup
        @progress_dialog.increment(1)
      end
      
      # divide and make average
      dictionary.each do |key, value|
        value /= sum
      end
      
      update_visible_spectrum
    end
    
  end

  def create_resources
    @font.create
  end

  def create_image

    log("Creating hyperspectral image") do

      # PerfTools::CpuProfiler.start("/tmp/getting_image_data") do

      @progress_dialog.total += @imzml.spectrums.size
      data = @imzml.image_data(@datapath, @selected_mz, @selected_interval) do |id|
        @progress_dialog.increment(1)
      end

      # end

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

      # create empty image
      image = FXImage.new(getApp(), nil, IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP, :width => @imzml.pixel_count_x, :height => @imzml.pixel_count_y)
      
      # rescale image and fill image view
      scale_w = IMAGE_WIDTH
      scale_h = IMAGE_HEIGHT
      if image.width > image.height
        scale_h = image.height.to_f/image.width.to_f * IMAGE_HEIGHT
      else
        scale_w = image.width.to_f/image.height.to_f * IMAGE_WIDTH
      end
      image.pixels = data
      @scale_x, @scale_y = scale_h/image.height, scale_w/image.width
      image.scale(scale_w - 10, scale_h - 10)
      image.create
      
      # assign image
      @image = image

    end

    calculate_interval_indexes

    @progress_dialog.increment(1)
    @image_canvas.update
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

          if @visible_spectrum
            
            # recalculate points
            points = Array.new
            
            # draw line
            @visible_spectrum.each do |mz, intensity|
              point = spectrum_point_to_canvas([mz, intensity])
              points << FXPoint.new(point.first.to_i, point.last.to_i)
            end
            
            # draw labels
            labels = Array.new
            visible_spectrum = @visible_spectrum.to_a
            
            debugger if visible_spectrum.last.nil? || visible_spectrum.first.nil? # FIXME
            every_n = (visible_spectrum.last.first - visible_spectrum.first.first) / 10
            i = visible_spectrum.first.first
            @visible_spectrum.each_with_index do |item, index| 
              if (item.first > i)
                point = spectrum_point_to_canvas(item)
                text = item.first.round(3).to_s
                text_width = @font.getTextWidth(text)
                
                dc.drawLine(point.first.to_i, @spectrum_canvas.height - AXIS_PADDING - 3, point.first.to_i, @spectrum_canvas.height - AXIS_PADDING + 3)
                dc.drawText(point.first.to_i - text_width/2, @spectrum_canvas.height - AXIS_PADDING / 2, text)
                i += every_n
              end
            end
            
            # draw spectrum
            dc.foreground = FXColor::Red
            dc.drawLines(points)
            
            # draw zoom rect
            if @zoom_from && @zoom_to
              canvas_from = spectrum_point_to_canvas(@zoom_from)
              canvas_to = spectrum_point_to_canvas(@zoom_to)
              
              dc.lineStyle = LINE_ONOFF_DASH
              dc.foreground = FXColor::Blue
              begining = (canvas_from.first > canvas_to.first) ? canvas_to : canvas_from
              dc.drawRectangle(begining.first, AXIS_PADDING, (canvas_from.first - canvas_to.first).abs, @spectrum_canvas.height - 2 * AXIS_PADDING)
              dc.lineStyle = LINE_SOLID
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
  
  def reset_to_default_values
    @imzml = nil
    @selected_x, @selected_y = 0, 0
    @scale_x, @scale_y = 1, 1
    @selected_spectrum = 0
    @selected_mz = nil
    @selected_interval = 0
    @selected_interval_low = @selected_interval_high = nil

    @interval_textfield.text = @selected_interval.to_s
    
    @progress_dialog.total = 0
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

      imzml = imzml_parser.metadata
      @imzml = imzml
      
    end
    
    create_average_spectrum

  end
  
  def update_visible_spectrum
    if @zoom_from && @zoom_to
      
      # flip values if set on other sides
      @zoom_from, @zoom_to = @zoom_to, @zoom_from if @zoom_from.first > @zoom_to.first
    
      # copy original spectrum
      @visible_spectrum = @spectrum.dup
      
      # delete unwanted values
      @visible_spectrum.delete_if{ |key, value| key < @zoom_from.first || key > @zoom_to.first }
      
      # reset zoom values
      @zoom_from = @zoom_to = nil
      
    end
    
    # find min max values
    @spectrum_min_x, @spectrum_max_x = @visible_spectrum.keys.min, @visible_spectrum.keys.max
    @spectrum_min_y, @spectrum_max_y = @visible_spectrum.values.min, @visible_spectrum.values.max
    
    @spectrum_canvas.update
  end

  private

  def calculate_interval_indexes
    if @selected_interval && @selected_mz

      # find the closest interval values
      @selected_interval_low = @mz_array.index{|x| x >= @selected_mz - @selected_interval}
      @selected_interval_high = @mz_array.index{|x| x >= @selected_mz + @selected_interval}
      @spectrum_canvas.update
    end
  end

  def log(message = "Please wait")
    start = Time.now
    @progress_dialog.total += 1
    message = "#{message} ... "
    @progress_dialog.message = message
    print message
    yield
    print "#{Time.now - start}s\n"
    @progress_dialog.increment(1)
  end
  
  def run_on_background
    @progress_dialog.progress = 0
    Thread.new {
      yield
    }
    @progress_dialog.execute(PLACEMENT_OWNER)
  end

  def spectrum_point_to_canvas(spectrum_point)
    # map points
    x_point_origin = spectrum_point.first
    y_point_origin = spectrum_point.last
    
    # find axis dimensions
    x_axis_width = @spectrum_canvas.width - 2 * AXIS_PADDING
    y_axis_height = @spectrum_canvas.height - 2 * AXIS_PADDING

    # calculate one point size for x and y
    x_diff = @spectrum_max_x - @spectrum_min_x
    x_point_size = x_axis_width / x_diff
    y_diff = @spectrum_max_y - @spectrum_min_y
    y_point_size = y_axis_height / y_diff.to_f
    
    # recalculate points
    x_point_canvas = ((x_point_origin - @spectrum_min_x) * x_point_size) + AXIS_PADDING
    y_point_canvas = @spectrum_canvas.height - AXIS_PADDING - (y_point_origin * y_point_size) - 1
    
    # p "canvas point #{y_point_origin} #{y_point_canvas}"
    
    [x_point_canvas, y_point_canvas]
  end

end

if __FILE__ == $0
  FXApp.new do |app|
    Reader.new(app)
    app.create
    app.run
  end
end