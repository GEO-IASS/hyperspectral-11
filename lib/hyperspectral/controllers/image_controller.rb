module Hyperspectral

  class ImageController

    include Callbacks

    # Array of origin intensity values
    attr_accessor :intensity_values

    # Origin image dimension as Array
    attr_accessor :image_size

    # Image intensity range to trim
    attr_accessor :intensity_range

    # Scan settings which affects drawing the image
    attr_accessor :options

    # When assinged data, create image immediately
    def intensity_values=(data)
      @intensity_values = data
      create_image(data)
    end

    # Getter for image pixels
    #
    # Returns array of image pixel data
    def pixels
      @image_canvas.image.pixels
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

    def clear_image
      @image_canvas.image = nil
      @image_canvas.point = nil
      @intensity_range = nil
      need_display
    end

    def reload_image
      create_image(@intensity_values)
    end

    # def spectrum_to_image_point(spectrum)
    #   index = @imzml.spectrums.index(spectrum)
    #
    #   x = ((index % image_width).to_i * @scale_x) + @scale_x / 2
    #   y = ((index / image_width).to_i * @scale_y) + @scale_y / 2
    #
    #   [x, y]
    # end

    private

    NO_MOUSE = 0
    LEFT_MOUSE = 1
    RIGHT_MOUSE = 3

    # Views
    attr_accessor :image_canvas

    def create_image(data)
      raise "Image size must be set" unless @image_size

      # if the value is out of range or nil do not include it into data
      temp_data = data.map do |x|
        if @intensity_range
          @intensity_range.include?(x) ? x : @intensity_range.begin
        else
          x ||= 0
        end
      end

      max = temp_data.max
      min = temp_data.min

      # normalize value
      max_normalized = max - min
      max_normalized = 1 if max_normalized == 0
      step = 255.0 / max_normalized

      # map to color
      temp_data.map! do |i|
        value = (i - min) * step

        value = 0 if value < 0
        value = 255 if value > 255
        Fox::FXRGB(value, value, value)
      end

      # create empty image
      image = Fox::FXPNGImage.new(Fox::FXApp.instance, nil,
        :opts => Fox::IMAGE_KEEP | Fox::IMAGE_SHMI | Fox::IMAGE_SHMP,
        :width => @image_size.width,
        :height => @image_size.height
      )

      # rescale image and fill image view
      scale_w = ImageCanvas::IMAGE_WIDTH
      scale_h = ImageCanvas::IMAGE_HEIGHT
      if image.width > image.height
        scale_h = image.height.to_f/image.width.to_f * ImageCanvas::IMAGE_HEIGHT
      else
        scale_w = image.width.to_f/image.height.to_f * ImageCanvas::IMAGE_WIDTH
      end
      image.pixels = temp_data
      image.scale(scale_w, scale_h)
      @scale_y, @scale_x = (image.width)/@image_size.width.to_f, (image.height)/@image_size.height.to_f
      image.create

      # assign image
      @image_canvas.image = image

    end

  end
end