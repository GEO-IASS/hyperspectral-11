require 'rubygems'
require 'fox16'
require 'fox16/colors'
require './imzml'
require './image_view'

include Fox

class Reader < FXMainWindow

  def initialize(app)
    super(app, "imzML Reader", :width => 1024, :height => 500)
    add_menu_bar

    @imzml = nil
    @font = FXFont.new(app, "times")

    # hyperspectral image
    vertical_frame = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)
    top_horizontal_frame = FXHorizontalFrame.new(vertical_frame, :opts => LAYOUT_FILL_X)

    @hyperspectral_image = ImageView.new(top_horizontal_frame)
    @hyperspectral_image.load_image("image.png")

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
    @spectrum_canvas.connect(SEL_PAINT, method(:spectrum_canvas_repaint))

    zoom_button_vertical_frame = FXVerticalFrame.new(bottom_horizontal_frame, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FILL_Y, :width => 50)

    # TODO implement
    FXButton.new(zoom_button_vertical_frame, "+", :opts => FRAME_RAISED|LAYOUT_FILL)
    FXButton.new(zoom_button_vertical_frame, "100%", :opts => FRAME_RAISED|LAYOUT_FILL)
    FXButton.new(zoom_button_vertical_frame, "-", :opts => FRAME_RAISED|LAYOUT_FILL)

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

    # get spectrum min and max data
    @mz_array = @imzml.spectrums.first.mz_array(@datapath)
    @mz_min = @mz_array.first
    @mz_max = @mz_array.last
    @intensity_array = @imzml.spectrums.first.intensity_array(@datapath)
    @intensity_max = @intensity_array.max
    @intensity_min = @intensity_array.min

    puts "Parsing done"

    @spectrum_canvas.update
  end

  def spectrum_canvas_repaint(sender, sel, event)
    FXDCWindow.new(@spectrum_canvas, event) do |dc|

      # draw background
      dc.foreground = FXColor::White
      dc.fillRectangle(event.rect.x, event.rect.y, event.rect.w, event.rect.h)

      # draw axis
      dc.foreground = FXColor::Black
      axis_padding = 30

      # x axis
      dc.drawLine(axis_padding, event.rect.h - axis_padding, event.rect.w - axis_padding, event.rect.h - axis_padding)

      # y axis
      dc.drawLine(axis_padding, event.rect.h - axis_padding, axis_padding, axis_padding)

      dc.font = @font
      dc.drawText(axis_padding/2, event.rect.h - axis_padding/2, "0")

      if (@imzml && event.rect.w > axis_padding && event.rect.h > axis_padding)

        # axis dimensions
        x_axis_width = event.rect.w - 2 * axis_padding
        x_point_size = x_axis_width / @mz_max
        y_axis_height = event.rect.h - 2 * axis_padding
        y_point_size = y_axis_height / @intensity_max
        y_baseline = event.rect.h - axis_padding - 1

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