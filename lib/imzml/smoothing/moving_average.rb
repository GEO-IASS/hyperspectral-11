module ImzML
	module Smoothing
	
		class MovingAverage
			ID = 1
			
			def self.filter(array, n)
				p "Moving averate with #{n}"
				b = Array.new
				n_half = n/2
		
				# print begging
				array[0..n_half].each do |x|
					p x
				end
		
				# calculate and print middle part
				array[n_half..-n_half].each do |x|
					current_index = array.index(x)
					sum_of_ns = array[(current_index - n_half)..(current_index + n_half)].inject{|sum,xx| sum += xx}
					current_average = sum_of_ns/n
			
					p current_average
			
					b << current_average
					b
				end
		
				# print end
				array[-n_half..-1].each do |x|
					p x
				end
			end
		end
	
	end
end