module Hyperspectral

  class ImageController

    include Callbacks

    def clear_image
      @image_canvas.image = nil
      @image_canvas.point = nil
      need_display
    end

    def create_image(data, image_width, image_height)
      @image_size = [image_width, image_height]
      raise "Image size must be set" if image_height.nil? || image_height.nil?

      # remove nil values
      data.map!{|x| x.nil? ? 0 : x}

      # normalize value into greyscale
      max_normalized = data.max - data.min
      max_normalized = 1 if max_normalized == 0
      min = data.min
      step = 255.0 / max_normalized
      data.map! do |i|
        value = (step * (i - min)).to_i
        Fox::FXRGB(value, value, value)
      end

      # create empty image
      image = Fox::FXPNGImage.new(Fox::FXApp.instance, nil,
        :opts => Fox::IMAGE_KEEP | Fox::IMAGE_SHMI | Fox::IMAGE_SHMP,
        :width => image_width,
        :height => image_height
      )

      # rescale image and fill image view
      scale_w = ImageCanvas::IMAGE_WIDTH
      scale_h = ImageCanvas::IMAGE_HEIGHT
      if image.width > image.height
        scale_h = image.height.to_f/image.width.to_f * ImageCanvas::IMAGE_HEIGHT
      else
        scale_w = image.width.to_f/image.height.to_f * ImageCanvas::IMAGE_WIDTH
      end
      image.pixels = data
      image.scale(scale_w, scale_h)
      @scale_y, @scale_x = (image.width)/image_width.to_f, (image.height)/image_height.to_f
      image.create

      # # # FIXME debug
      # Fox::FXFileStream.open("/Users/beny/Desktop/image.png", Fox::FXStreamSave) do |outfile|
      #   i = Fox::FXPNGImage.new(Fox::FXApp.instance,
      #     :width => image.width,
      #     :height => image.height
      #   )
      #   i.setPixels(image.pixels)
      #   i.scale(image_width, image_height)
      #   i.savePixels(outfile)
      # end

      # assign image
      @image_canvas.image = image

    end

    def load_view(superview)

      packer = Fox::FXPacker.new(superview,
        :opts => Fox::FRAME_SUNKEN | Fox::LAYOUT_FIX_WIDTH | Fox::LAYOUT_FIX_HEIGHT,
        :width => ImageCanvas::IMAGE_WIDTH,
        :height => ImageCanvas::IMAGE_HEIGHT
      )
      @image_canvas = ImageCanvas.new(packer)

      @image_canvas.connect(Fox::SEL_LEFTBUTTONPRESS, method(:mouse_pressed))

    end

    def mouse_pressed(sender, selector, event)
      case event.click_button
      when LEFT_MOUSE
        spectrum_index = image_point_to_spectrum_index([event.click_x, event.click_y])
        callback(:when_spectrum_selected, spectrum_index)
      when RIGHT_MOUSE
      end
    end

    def need_display
      @image_canvas.update
    end

    def show_point(point)
      return unless @scale_x && @scale_y
      @image_canvas.point = [point.x * @scale_x - @scale_x/2, point.y * @scale_y - @scale_y/2]
    end

    def image_point_to_spectrum_index(point)
      (point.y/@scale_y).to_i * @image_size.width + (point.x/@scale_x).to_i
    end

    # def spectrum_to_image_point(spectrum)
    #   index = @imzml.spectrums.index(spectrum)
    #
    #   x = ((index % image_width).to_i * @scale_x) + @scale_x / 2
    #   y = ((index / image_width).to_i * @scale_y) + @scale_y / 2
    #
    #   [x, y]
    # end

    ## FIXME
    # def image_data(data_path, mz_value, interval)
    #
    #   data = Array.new
    #   @spectrums.each do |spectrum|
    #     data << spectrum.intensity(data_path, mz_value, interval)
    #     yield spectrum.id
    #   end
    #
    #   data
    # end

  end

  private

  NO_MOUSE = 0
  LEFT_MOUSE = 1
  RIGHT_MOUSE = 3

  # Views
  attr_accessor :image_canvas

  attr_accessor :image_size

end