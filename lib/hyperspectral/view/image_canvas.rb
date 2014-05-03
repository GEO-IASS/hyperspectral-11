module Hyperspectral

  class ImageCanvas < Fox::FXCanvas

    IMAGE_WIDTH = 300
    IMAGE_HEIGHT = 300

    # Image itself, instance of FXPNGImage
    attr_accessor :image

    # Selected point, an instance of Array [x, y]
    attr_accessor :point

    def point=(point)
      @point = point
      self.update
    end

    def initialize(superview)
      super(superview,
        :opts =>
          Fox::LAYOUT_CENTER_X | Fox::LAYOUT_CENTER_Y | Fox::LAYOUT_FILL |
          Fox::LAYOUT_FIX_WIDTH | Fox::LAYOUT_FIX_HEIGHT,
        :width => ImageCanvas::IMAGE_WIDTH,
        :height => ImageCanvas::IMAGE_HEIGHT
      )

      connect(Fox::SEL_PAINT, method(:draw))

    end

    def image=(image)
      @image = image
      self.update
    end

    def draw(sender, selector, event)
      return unless sender && selector && event

      Fox::FXDCWindow.new(sender, event) do |dc|
        # clear canvas
        dc.foreground = Fox::FXColor::White
        dc.fillRectangle(0, 0, IMAGE_WIDTH, IMAGE_HEIGHT)

        # draw image
        dc.drawImage(@image, 0, 0) if @image

        return unless @point
        # draw cross
        dc.foreground = Fox::FXColor::Green
        dc.drawLine(point.x, 0, point.x, sender.height)
        dc.drawLine(0, point.y, sender.width, point.y)
      end
    end

    private

  end

end