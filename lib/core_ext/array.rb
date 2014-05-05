class Array

  def x
    self[0]
  end

  def y
    self[1]
  end

  alias_method :width, :x
  alias_method :height, :y

end