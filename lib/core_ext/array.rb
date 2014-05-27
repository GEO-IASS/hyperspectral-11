class Array

  # Simplified access to x value of an array representation of point.
  def x
    self[0]
  end

  # Simplified access to y value of an array representation of point.
  def y
    self[1]
  end

  # Aliases when usign array as size (width, height)
  alias_method :width, :x
  alias_method :height, :y

  # Calculating median of an array.
  #
  # Returns median of self.
  def median
    sorted = self.sort
    mid = (sorted.length - 1) / 2.0
    (sorted[mid.floor] + sorted[mid.ceil]) / 2.0
  end
end