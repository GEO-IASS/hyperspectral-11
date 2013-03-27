require 'fox16'
require './imzml'

include Fox

class ImageView < FXImageFrame

  MAX_WIDTH = 200
  MAX_HEIGHT = 200

  def initialize(p)
    super(p, nil)
    load_image
  end

  def load_image
    File.open("image.png", "rb") do |io|
      self.image = FXPNGImage.new(app, io.read)
    end
    p "image loaded"
  end

end

class Reader < FXMainWindow

  def initialize(app)
    super(app, "imzML Reader", width:600, height:400)
    add_menu_bar

    ImageView.new(self)
  end

  def create
    super
    show(PLACEMENT_SCREEN)
  end

  def add_menu_bar
    menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)

    # File
    file_menu = FXMenuPane.new(self)
    FXMenuTitle.new(menu_bar, "File", :popupMenu => file_menu)

    FXMenuCommand.new(file_menu, "Open...").connect(SEL_COMMAND) do
      dialog = FXFileDialog.new(self, "Open imzML file")
      # dialog.selectMode = SELECTFILE_MULTIPLE
      dialog.patternList = ["imzML files (*.imzML)"]
      read_file(dialog.filename) if (dialog.execute != 0)
    end

    exit_cmd = FXMenuCommand.new(file_menu, "Exit")
    exit_cmd.connect(SEL_COMMAND) do
      exit
    end
  end

  def read_file(filepath)

    path = "/#{filepath.split("/")[1..-2].join("/")}/"
    filename = filepath.split("/").last.split(".").first

    imzml_path = "#{path}#{filename}.imzML"
    ibd_path = "#{path}#{filename}.ibd"

    doc = IMZML::Document.new
    parser = IMZML::Parser.new(doc)
    parser.parse_file(imzml_path)
    imzml = doc.metadata
    p "Checksum equals" if IO.binread(ibd_path, 16).unpack("H*").first.upcase == imzml.uuid.upcase

    # save spectrum to images
    # imzml.spectrums.each do |spectrum|
      # p spectrum.intensity(ibd_path, mz, interval)
      # spectrum.save_spectrum_graph(ibd_path)
    # end

    # save image
    mz, interval = 151.9, 0.25
    imzml.generate_image(ibd_path, mz, interval)

    p "image generated you should see output"
    image_view = ImageView.new(self)

  end

end

if __FILE__ == $0
  FXApp.new do |app|
    Reader.new(app)
    app.create
    app.run
  end
end