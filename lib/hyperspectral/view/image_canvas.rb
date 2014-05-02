module Hyperspectral

  class ImageCanvas < Fox::FXCanvas

    IMAGE_WIDTH = 300
    IMAGE_HEIGHT = 300

    def initialize(superview)
      super(superview,
        :opts =>
          Fox::LAYOUT_CENTER_X | Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_FILL |
          Fox::LAYOUT_FIX_WIDTH | Fox::LAYOUT_FIX_HEIGHT,
        :width => ImageCanvas::IMAGE_WIDTH,
        :height => ImageCanvas::IMAGE_HEIGHT
      )

    end

    private

  end

end