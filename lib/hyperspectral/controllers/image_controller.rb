module Hyperspectral

  class ImageController

    def load_view(superview)

      packer = Fox::FXPacker.new(superview,
        :opts => Fox::FRAME_SUNKEN | Fox::LAYOUT_FIX_WIDTH | Fox::LAYOUT_FIX_HEIGHT,
        :width => ImageCanvas::IMAGE_WIDTH,
        :height => ImageCanvas::IMAGE_HEIGHT
      )
      @image_canvas = ImageCanvas.new(packer)

    end

    def need_display
      @image_canvas.update
    end

  end

  private

  # Views
  attr_accessor :image_canvas

end