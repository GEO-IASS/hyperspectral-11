module Hyperspectral

  class PeakFeatureController

    TITLE = "Peak"

    def load_view(superview)
      item = Fox::FXTabItem.new(superview, TITLE)
      matrix = Fox::FXMatrix.new(superview,
        :opts => Fox::FRAME_THICK | Fox::FRAME_RAISED | Fox::LAYOUT_FILL_X |
          Fox::MATRIX_BY_COLUMNS
      )
      matrix.numColumns = 2
      matrix.numRows = 4
    end

  end

end