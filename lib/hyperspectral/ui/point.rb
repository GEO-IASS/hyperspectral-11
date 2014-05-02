module Hyperspectral
  
  class Point
   
    attr_accessor :x, :y
    
    def ==(another_point)
      @x == another_point.x && @y == another_point.y
    end
    
    def self.[](*args)
      Point.new(args[0], args[1])
    end
    
  end
  
end