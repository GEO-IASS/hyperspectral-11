module ImzML

  module Calibration
    
    class Linear
      def initialize(a, b)
        @a, @b = a, b
      end
      
      def recalculate(x)
        error = @a * x + @b
        x + error
      end
    end
  
  end
    
end