module Hyperspectral
  
  module Smoothing
  
    class SavitzkyGolay
       
      def name
        "Savitzky-Golay"
      end
      
      def apply(array, window_size = 5, order = 3)
        array.savgol(window_size, order)
      end
      
    end
    
  end
  
end