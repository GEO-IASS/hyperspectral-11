require_relative "fox"

module Hyperspectral
	
	class SpectrumCanvas < Fox::FXCanvas
		
		attr_accessor :main_spectrum
		attr_accessor :preview_spectrum
		
		def initialize(parent)
			super(parent, :opts => LAYOUT_FILL)
			
			@font = FXFont.new(app, "times")
			@font.create
			
			connect(SEL_PAINT, method(:draw))
		end
	
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
					
					# recalculate points
					
					# calculate spectrum points and save to cache
					if @spectrum_drawn_points.nil?
						points = Array.new
						
						previous_point = nil
						useless_points = 0
						@visible_spectrum.each do |mz, intensity|
							
							mz = @calibration.recalculate(mz) if @calibration
							point = spectrum_point_to_canvas([mz, intensity])
							# do not draw the same point twice
							points << FXPoint.new(point.first.to_i, point.last.to_i)
							
							previous_point = point
						end
						
						@spectrum_drawn_points = points
					end
					
					# load from cache
					points = @spectrum_drawn_points
					
					# draw labels
					labels = Array.new
					visible_spectrum = @visible_spectrum.to_a
					
					# draw visible spectrum
					every_x = (visible_spectrum.last.first - visible_spectrum.first.first) / LABEL_X_EVERY
					every_y = (@visible_spectrum.values.max - @visible_spectrum.values.min) / LABEL_Y_EVERY
					i, j = visible_spectrum.first.first, visible_spectrum.first.last
					@visible_spectrum.each_with_index do |item, index|
						
						# x labels
						if (item.first > i)
							point = spectrum_point_to_canvas(item)
							text = item.first.round(3).to_s
							text_width = @font.getTextWidth(text)
							
							dc.drawLine(point.first.to_i, @spectrum_canvas.height - AXIS_PADDING + 3, point.first.to_i, @spectrum_canvas.height - AXIS_PADDING)
							dc.drawText(point.first.to_i - text_width/2, @spectrum_canvas.height - AXIS_PADDING / 2, text)
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
					
					# draw spectrum
					dc.foreground = FXColor::Red
					dc.drawLines(points)
					
					# draw zoom rect
					if @zoom_from && @zoom_to
						canvas_from = spectrum_point_to_canvas(@zoom_from)
						canvas_to = spectrum_point_to_canvas(@zoom_to)
						
						dc.lineStyle = LINE_ONOFF_DASH
						dc.foreground = FXColor::Blue
						begining = (canvas_from.first > canvas_to.first) ? canvas_to : canvas_from
						dc.drawRectangle(begining.first, AXIS_PADDING, (canvas_from.first - canvas_to.first).abs, @spectrum_canvas.height - 2 * AXIS_PADDING)
						dc.lineStyle = LINE_SOLID
					end
					
					# draw selected fixed line
					draw_selected_line(dc, @selected_fixed_point, @selected_fixed_interval, FXColor::LightGrey)
					
					# draw selected line
					if @tabbook.current == TAB_BASICS
						draw_selected_line(dc, @selected_point, @selected_interval, FXColor::SteelBlue)
					end
					
					# draw smoothing preview
					if @tabbook.current == TAB_SMOOTHING
						dc.foreground = FXColor::Blue
						dc.drawLine(0,0, 100, 100)
					end
					
					# draw calibration lines
					if @calibration_points.size > 0 && @tabbook.current == TAB_CALIBRATIONS
						@calibration_points.compact.each do |point|
							draw_selected_line(dc, [point, 0], 0, FXColor::Green)
						end
					end
					
				end
			end
			
		end
	end
end