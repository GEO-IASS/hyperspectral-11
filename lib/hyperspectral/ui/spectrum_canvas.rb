module Hyperspectral
	
	class SpectrumCanvas < Fox::FXCanvas
		
		# The currently displayed full spectrum
		attr_accessor :visible_spectrum
		
		# Cache for currently visible points
		attr_accessor :cached_visible_spectrum
		
		# Smoothing variables
		attr_accessor :smoothing
		attr_accessor :smoothing_window_size

		# Spectrum preview before alternating it's points
		attr_accessor :spectrum_preview

		# Boundaries for currently visible spectrum
		attr_accessor :spectrum_min_x
		attr_accessor :spectrum_max_x
		attr_accessor :spectrum_min_y
		attr_accessor :spectrum_max_y
		
		# Properties used to draw the zoom rectangle
		attr_accessor :zoom_from
		attr_accessor :zoom_to
		
		# Helper properties for displaying the selection with interval
		attr_accessor :selected_point
		attr_accessor :selected_fixed_point
		attr_accessor :selected_fixed_interval
		attr_accessor :selected_interval
    
    # Found peaks to draw
    attr_accessor :peaks
		
		# Init method
		#
		# parent
		def initialize(parent)
			super(parent, :opts => LAYOUT_FILL)
			
			@font = FXFont.new(app, "times")
			@font.create
			
			
			self.smoothing_window_size = 5
			
			connect(SEL_PAINT, method(:draw))
		end
	
		# Spectrum part drawing method
		#
		# Returns nothing
		def draw(sender, sel, event)
			FXDCWindow.new(sender, event) do |dc|
        
        # draw background
				dc.foreground = FXColor::White
				dc.fillRectangle(0, 0, sender.width, sender.height)
				
				# draw axis
				dc.foreground = FXColor::Black
				
				# x and y axis
				dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, sender.width - AXIS_PADDING, sender.height - AXIS_PADDING)
				dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, AXIS_PADDING, AXIS_PADDING)
				dc.font = @font
				
				if @visible_spectrum && @spectrum_min_x && @spectrum_max_x
					
					# FIXME debug
					preview_points = Array.new
					
					# calculate spectrum points and save to cache
					if @cached_visible_spectrum.nil?
						
						points = Array.new
						
						previous_point = nil
						
						# convert spectrum points and create canvas points
						@visible_spectrum.each do |mz, intensity|
							
							# FIXME calibration
							# mz = @calibration.recalculate(mz) if @calibration
							point = spectrum_point_to_canvas([mz, intensity])
							# do not draw the same point twice
							points << FXPoint.new(point.first.to_i, point.last.to_i)
							# previous_point = point
						end
						
						# preview for smoothing
						if !self.smoothing.nil?
							preview_values = @visible_spectrum.values
							keys = @visible_spectrum.keys
							self.smoothing.apply(preview_values, self.smoothing_window_size).each_with_index do |intensity, index|
								point = spectrum_point_to_canvas([keys[index], intensity])
								preview_points << FXPoint.new(point.first.to_i, point.last.to_i)
							end
						end
						
						@cached_visible_spectrum = points
					end
					
					# load from cache
					points = @cached_visible_spectrum
					
					# draw labels
					labels = Array.new
					visible_spectrum = @visible_spectrum.to_a
					
					# draw visible spectrum labels
					every_x = (visible_spectrum.last.first - visible_spectrum.first.first) / LABEL_X_EVERY
					every_y = (@visible_spectrum.values.max - @visible_spectrum.values.min) / LABEL_Y_EVERY
					i, j = visible_spectrum.first.first, visible_spectrum.first.last
					@visible_spectrum.each_with_index do |item, index|
						
						# x labels
						if (item.first > i)
							point = spectrum_point_to_canvas(item)
							text = item.first.round(3).to_s
							text_width = @font.getTextWidth(text)
							
							dc.drawLine(point.first.to_i, self.height - AXIS_PADDING + 3, point.first.to_i, sender.height - AXIS_PADDING)
							dc.drawText(point.first.to_i - text_width/2, sender.height - AXIS_PADDING / 2, text)
							i += every_x
						end
						
						# y labels
						if (item.last > j)
							
							point = spectrum_point_to_canvas(item)
							text = item.last.round(1).to_s
							text_width = @font.getTextWidth(text)
							text_height = @font.getTextHeight(text)
							
							dc.drawLine(AXIS_PADDING - 3, point.last.to_i, AXIS_PADDING, point.last.to_i)
							dc.drawText(AXIS_PADDING - text_width - 3, point.last.to_i + text_height/2, text)
							
							j += every_y
						end
					end
					
					# draw spectrum line
					dc.foreground = FXColor::Red
					dc.drawLines(points)
					
					# FIXME
					dc.foreground = FXColor::Blue
					dc.drawLines(preview_points)
          
          # draw found peaks
          if @peaks 
            @peaks.each do |p|
              draw_selected_line(dc, [p, 0], 0, FXColor::Blue)
            end
          end
					
					# draw zoom rect
					if @zoom_from && @zoom_to
						canvas_from = spectrum_point_to_canvas(@zoom_from)
						canvas_to = spectrum_point_to_canvas(@zoom_to)
						
						dc.lineStyle = LINE_ONOFF_DASH
						dc.foreground = FXColor::Blue
						begining = (canvas_from.first > canvas_to.first) ? canvas_to : canvas_from
						dc.drawRectangle(begining.first, AXIS_PADDING, (canvas_from.first - canvas_to.first).abs, self.height - 2 * AXIS_PADDING)
						dc.lineStyle = LINE_SOLID
					end
					
					# draw selected fixed line
					draw_selected_line(dc, @selected_fixed_point, @selected_fixed_interval, FXColor::LightGrey)
					
					# draw selected line
					# if @tabbook.current == TAB_BASICS
						draw_selected_line(dc, @selected_point, @selected_interval, FXColor::SteelBlue)
					# end
					
					# FIXME smoothing
					# # draw smoothing preview
					# if @tabbook.current == TAB_SMOOTHING
					# 	dc.foreground = FXColor::Blue
					# 	dc.drawLine(0,0, 100, 100)
					# end
					
					# FIXME calibration
					# # draw calibration lines
					# if @calibration_points.size > 0 && @tabbook.current == TAB_CALIBRATIONS
					# 	@calibration_points.compact.each do |point|
					# 		draw_selected_line(dc, [point, 0], 0, FXColor::Green)
					# 	end
					# end
					
				end
			end
			
		end
	
		# Converting canvas point to spectrum point
		# 
		# canvas_point - point in the canvas
		# 
		# Returns point in spectrum domain
		def canvas_point_to_spectrum(canvas_point)
			# map points
			x_point_origin = canvas_point.first
			y_point_origin = canvas_point.last
	
			# find axis dimensions
			x_axis_width = self.width - 2 * AXIS_PADDING
			y_axis_height = self.height - 2 * AXIS_PADDING
	
			# calculate x point
			x_point_spectrum = if x_point_origin <= AXIS_PADDING then self.spectrum_min_x
			elsif x_point_origin >= (AXIS_PADDING + x_axis_width) then self.spectrum_max_x
			else
				x_diff = self.spectrum_max_x - self.spectrum_min_x
				x_point_size = x_axis_width / x_diff
				((x_point_origin - AXIS_PADDING) / x_point_size) + self.spectrum_min_x
			end
	
			# calculate y point
			y_point_spectrum = if y_point_origin <= AXIS_PADDING then self.spectrum_max_y
			elsif y_point_origin >= (AXIS_PADDING + y_axis_height) then @spectrum_min_y
			else
				y_diff = self.spectrum_max_y - @spectrum_min_y
				y_point_size = y_axis_height / y_diff.to_f
				self.spectrum_max_y - (y_point_origin - AXIS_PADDING) / y_point_size
			end
	
			[x_point_spectrum, y_point_spectrum]
		end
	
		# Converting spectrum point to canvas point
		# 
		# spectrum_point - point in the spectrum
		#
		# Returns point in canvas domain
		def spectrum_point_to_canvas(spectrum_point)
		
			# if spectrum was not yet loaded
			return [0, 0] if self.spectrum_min_x.nil? || self.spectrum_max_x.nil?
		
			# map points
			x_point_origin = spectrum_point.first
			y_point_origin = spectrum_point.last
		
			# find axis dimensions
			x_axis_width = self.width - 2 * AXIS_PADDING
			y_axis_height = self.height - 2 * AXIS_PADDING
		
			# calculate one point size for x and y
			x_diff = self.spectrum_max_x - self.spectrum_min_x
			x_point_size = x_axis_width / x_diff
			y_diff = self.spectrum_max_y - @spectrum_min_y
			y_point_size = y_axis_height / y_diff.to_f
		
			# recalculate points
			x_point_canvas = ((x_point_origin - self.spectrum_min_x) * x_point_size) + AXIS_PADDING
			y_point_canvas = self.height - AXIS_PADDING - (y_point_origin * y_point_size - @spectrum_min_y * y_point_size) - 1
		
			[x_point_canvas, y_point_canvas]
		end
		
		# Drawing vertical line, used for selection of specific part of spectrum
		#
		# context - instance of FXDCWindow
		# selected_point - selected point in spectrum domain
		# selected_interval - selected interval in spectrum domain
		# color - which color to use for the line
		#
		# Returns nothing
		def draw_selected_line(context, selected_point, selected_interval, color)
			# draw selected line
			if selected_point
				point = self.spectrum_point_to_canvas(selected_point)
				context.foreground = color
				context.stipple = STIPPLE_NONE
				context.fillStyle = FILL_SOLID
				context.drawLine(point.first, AXIS_PADDING, point.first, self.height - AXIS_PADDING)
			
				text = selected_point.first.round(ROUND_DIGITS).to_s
				text_width = @font.getTextWidth(text)
				text_height = @font.getTextHeight(text)
				context.drawText(point.first - text_width/2, AXIS_PADDING - 3, text)
			
				# draw interval
				if selected_interval > 0
					interval_from = self.spectrum_point_to_canvas([selected_point.first - selected_interval, selected_point.last])
					interval_to = self.spectrum_point_to_canvas([selected_point.first + selected_interval, selected_point.last])
				
					context.fillStyle = FILL_STIPPLED
					context.stipple = STIPPLE_2
					context.fillRectangle(interval_from.first, AXIS_PADDING - 1, interval_to.first - interval_from.first, self.height - 2 * AXIS_PADDING)
				end
			end
		end
		
		# Resets spectrum point cache
		#
		# Returns nothing
		def reset_cache
			@cached_visible_spectrum = nil
		end
	end
end
