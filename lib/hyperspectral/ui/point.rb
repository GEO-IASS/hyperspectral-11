module Hyperspectral

  # Class representing simple point.
  class Point

    # point coordinates values
    attr_accessor :x, :y

    # Equal method.
    #
    # another_point - point which should be compared with
    # Returns yes if the object are equal
    def ==(another_point)
      @x == another_point.x && @y == another_point.y
    end

    # Custom init method.
    #
    # args - an Array of arguments where first and second are used for point
    #        itself
    # Returns Point object
    def self.[](*args)
      Point.new(args[0], args[1])
    end

  end

end