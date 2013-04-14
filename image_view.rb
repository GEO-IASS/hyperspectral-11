require 'fox16'
include Fox

class ImageView < FXImageFrame

  MAX_WIDTH = 200
  MAX_HEIGHT = 200

  def initialize(p)
    super(p, nil)
  end

  def load_image(image_path)
    File.open(image_path, "rb") do |io|
      image = FXPNGImage.new(app, io.read)
      image.scale(MAX_WIDTH, MAX_HEIGHT)
      self.image = image
    end
  end

end