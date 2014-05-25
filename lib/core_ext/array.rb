class Array

  def x
    self[0]
  end

  def y
    self[1]
  end

  alias_method :width, :x
  alias_method :height, :y

  def median
    sorted = self.sort
    mid = (sorted.length - 1) / 2.0
    (sorted[mid.floor] + sorted[mid.ceil]) / 2.0
  end
end