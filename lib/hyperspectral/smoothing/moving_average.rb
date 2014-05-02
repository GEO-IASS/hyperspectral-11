module Hyperspectral
  
  module Smoothing
  
    class MovingAverage
      
      def name
        "Moving average"
      end
      
      def apply(array, n = 5)
        # p "Moving averate with #{n}"
        
        
        return array if n <= 1 # FIXME handle situation when the n is 1
        return array if n >= array.size
        # FIXME too big window size make strange artefacts, the begining and the end reproduce the origin signal, think about it somehow
        
        filtered = Array.new
        
        n_half = n/2
        start_index = n_half
        end_index = -n_half
        # p "n/2 = #{n_half}"
        # p "start #{start_index}, end_index #{end_index}"
        
        # prepend unchanged begining
        filtered += array[0..start_index-1]
      
        array[start_index..end_index-1].map.with_index(start_index) do |x, i|
          # p "x[#{i}] = #{x}"
          # p "from #{i-n_half} to #{i+n_half}"
          from = i-n_half
          to = i+n_half
          subarray = array[from..to]
          sum = subarray.reduce(:+)
          avg = sum/n.to_f
          # p "subarray #{subarray}, sum #{sum}, avg = #{avg}"
          
          filtered << avg
        end
        
        # append the unchanged end
        filtered += array[end_index..-1]
        
        filtered
      end
    end
  
  end
end

# a = [3,5,8,10,6,2,8]
# # 20.times {|i| a << Random.rand}
# p a
# filtered = ImzML::Smoothing::MovingAverage.filter(a)
# p filtered
# p "arrays are equals #{filtered == a}"
# p "arrays have same size #{filtered.size == a.size}"