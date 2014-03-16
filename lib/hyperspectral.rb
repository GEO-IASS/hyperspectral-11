#!/usr/bin/env ruby

require 'rubygems'
require 'csv'
require "pp"
require "byebug"

require_relative "hyperspectral/fox"

require_relative 'imzml/imzml'
require_relative 'imzml/parser'
require_relative 'imzml/calibration'
require_relative "imzml/smoothing/moving_average"
require_relative "imzml/smoothing/savitzky_golay"
require_relative "hyperspectral/spectrum_canvas"

include Fox

IMAGE_WIDTH = 300
IMAGE_HEIGHT = 300
AXIS_PADDING = 30
LABEL_X_EVERY = 10
LABEL_Y_EVERY = 4
COLUMN_DEFAULT_WIDTH = 80
DEFAULT_DIR = "/Users/beny/Dropbox/School/dp/imzML"
DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/example_files/Example_Continuous.imzML"
# DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/example_files/Example_Processed.imzML"
# DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/s042_continuous/S042_Continuous.imzML"
# DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/s043_processed/S043_Processed.imzML"
# DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/test_files/testovaci_blbost.imzML"
# DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/test_files/20130115_lin_range_10row_100vdef_0V_DOBRA_144327.imzML"
# DEBUG_DIR = "/Users/beny/Dropbox/School/dp/imzML/calibration_files/20130503_2013_ImzML_141238.imzML"
ROUND_DIGITS = 4

# tabs
TAB_BASICS, TAB_SMOOTHING, TAB_CALIBRATIONS = 0, 1, 2

# smoothing constants
SMOOTHING_NONE = 0

# calibration columns
CALIBRATION_COLUMN_SELECTED, CALIBRATION_COLUMN_ORIGIN, CALIBRATION_COLUMN_DIFF, CALIBRATION_COLUMN_PEPTID = 0, 1, 2, 3

module Hyperspectral

class Reader < FXMainWindow
		
	def initialize(app)
		
		super(app, "imzML Hyperspectral", :width => 800, :height => 600)
		add_menu_bar
		
		self.connect(SEL_CONFIGURE) do
			@spectrum_canvas.spectrum_drawn_points = nil
		end
		
		@mutex = Mutex.new
		
		# progress dialog
		@progress_dialog = FXProgressDialog.new(self, "Please wait", "Loading data")
		@progress_dialog.total = 0
		@progress_dialog.connect(SEL_UPDATE) do |sender, sel, event|
			if sender.progress >= sender.total
				sender.handle(sender, MKUINT(FXDialogBox::ID_ACCEPT, SEL_COMMAND), nil)
			else
				# p "progress #{sender.progress} #{sender.total}"
			end
		end
		
		@main_frame = FXVerticalFrame.new(self, :opts => LAYOUT_FILL)
		
		# create main UI parts
		add_image_part
		add_spectrum_part
		
		# status bar
		status_bar = FXStatusBar.new(@main_frame, :opts => LAYOUT_FILL_X|LAYOUT_FIX_HEIGHT, :height => 30)
		@status_line = status_bar.statusLine
	end
	
	def add_menu_bar
		menu_bar = FXMenuBar.new(self, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)
		
		# file menu (fold)
		file_menu = FXMenuPane.new(self)
		FXMenuTitle.new(menu_bar, "File", :popupMenu => file_menu)
		
		# open file menu
		FXMenuCommand.new(file_menu, "Open...").connect(SEL_COMMAND) do
			dialog = FXFileDialog.new(self, "Open imzML file")
			dialog.directory = "#{DEFAULT_DIR}"
			dialog.patternList = ["imzML files (*.imzML)"]
			
			# after success on opening
			if (dialog.execute != 0)
				
				# show progress dialog and starts thread
				run_on_background do
					read_file(dialog.filename)
				end
			end
		end
		
		FXMenuSeparator.new(file_menu)
		
		FXMenuCommand.new(file_menu, "Save image...").connect(SEL_COMMAND) do
			saveDialog = FXFileDialog.new(self, "Save as PNG")
			saveDialog.patternList = ["PNG files (*.png)"]
			if @image
				if saveDialog.execute != 0
					FXFileStream.open(saveDialog.filename, FXStreamSave) do |outfile|
						image = FXPNGImage.new(getApp(), :width => @image.width, :height => @image.height)
						image.setPixels(@image.pixels)
						image.scale(@imzml.pixel_count_x, @imzml.pixel_count_y)
						image.savePixels(outfile)
					end
				end
			end
		end
		
		FXMenuCommand.new(file_menu, "Save spectrum ...").connect(SEL_COMMAND) do
			saveDialog = FXFileDialog.new(self, "Save as CSV")
			saveDialog.patternList = ["CSV files (*.csv)"]
			if @spectrum
				if saveDialog.execute != 0
					CSV.open(saveDialog.filename, "wb") do |csv|
						@spectrum.each{|key, value| csv << [key, value]}
					end
				end
			end
		end
		
		FXMenuSeparator.new(file_menu)
		
		exit_cmd = FXMenuCommand.new(file_menu, "Exit")
		exit_cmd.connect(SEL_COMMAND) {exit}
		# file menu (end)
		
		# calibration menu (fold)
		calibration_menu = FXMenuPane.new(self)
		FXMenuTitle.new(menu_bar, "Calibration", :popupMenu => calibration_menu)
		
		FXMenuCommand.new(calibration_menu, "Load template").connect(SEL_COMMAND) do
			dialog = FXFileDialog.new(self, "Open calibration file...")
			dialog.directory = "#{DEFAULT_DIR}"
			dialog.patternList = ["CSV (*.csv)"]
			
			# after success on opening
			if (dialog.execute != 0)
				
				# read CSV file and fill table with data
				@calibration_points = Array.new
				@table.removeRows(0, @table.numRows)
				CSV.read(dialog.filename, {:skip_blanks => true}).each_with_index do |row, i|
					@table.appendRows
					@table.setItemText(i, CALIBRATION_COLUMN_SELECTED, "0.0")
					@table.setItemText(i, CALIBRATION_COLUMN_DIFF, "0.0")
					@table.setItemText(i, CALIBRATION_COLUMN_ORIGIN, row[1])
					@table.setItemText(i, CALIBRATION_COLUMN_PEPTID, row[0])
					
					# FIXME debug
					@table.setItemText(i, CALIBRATION_COLUMN_SELECTED, row[2])
					@calibration_points << row[2].to_f
				end
				
				@spectrum_canvas.update
			end
		end
		
		# debug menu
		
		debug_menu = FXMenuPane.new(self)
		FXMenuTitle.new(menu_bar, "DEBUG", :popupMenu => debug_menu)
		
		
		# TODO implement	
		# FXMenuCommand.new(calibration_menu, "Load calibration file").connect(SEL_COMMAND) do
		# dialog = FXFileDialog.new(self, "Open calibration file...")
		# dialog.directory = "#{DEFAULT_DIR}"
		# dialog.patternList = ["YAML (*.yaml, *.yml)"]
		# 
		# # after success on opening
		# if (dialog.execute != 0)
		# 	
		# 	p "opening #{dialog.filename}"
		# 	@spectrum_canvas.update
		# end
		# end
		# calibration menu (end)
		
	end
	
	def add_image_part
		# hyperspectral image
		top_horizontal_frame = FXHorizontalFrame.new(@main_frame, :opts => LAYOUT_FILL_X)
		
		image_container = FXPacker.new(top_horizontal_frame, :opts => FRAME_SUNKEN|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT, :width => IMAGE_WIDTH, :height => IMAGE_HEIGHT)
		@image_canvas = FXCanvas.new(image_container, :opts => LAYOUT_CENTER_X|LAYOUT_CENTER_Y|LAYOUT_FILL|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT, :width => IMAGE_WIDTH, :height => IMAGE_HEIGHT)
		@image_canvas.connect(SEL_PAINT, method(:draw_canvas))
		
		@image_canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, sel, event|
			if @image
				@selected_x, @selected_y = event.win_x, event.win_y
				@mouse_right_down = true
				@image_canvas.update
			end
		end
		
		@image_canvas.connect(SEL_MOTION) do |sender, sel, event|
			if @mouse_right_down
				@selected_x, @selected_y = event.win_x, event.win_y
				@selected_y = 0 if @selected_y < 0
				@selected_y = @image_canvas.height if @selected_y > @image_canvas.height
				@selected_x = 0 if @selected_x < 0
				@selected_x = @image_canvas.width if @selected_x > @image_canvas.width
				
				spectrum = image_point_to_spectrum([@selected_x, @selected_y])
				@status_line.text = "Selected spectrum #{spectrum.id}"
				@image_canvas.update
			end
		end
		
		@image_canvas.connect(SEL_LEFTBUTTONRELEASE) do |sender, sel, event|
			if @mouse_right_down
				@mouse_right_down = false
				
				selected_spectrum = image_point_to_spectrum([@selected_x, @selected_y])
				open_spectrum(selected_spectrum.id) if selected_spectrum
			end
		end
		
		# tab settings
		@tabbook = FXTabBook.new(top_horizontal_frame, :opts => LAYOUT_FILL_X|LAYOUT_RIGHT|LAYOUT_FILL_Y)
		@tabbook.connect(SEL_COMMAND) do |sender, sel, event|
			@spectrum_canvas.update
		end
		
		# basic tab (fold)
		@basics_tab = FXTabItem.new(@tabbook, "Basic")
		matrix = FXMatrix.new(@tabbook, :opts => FRAME_THICK|FRAME_RAISED|LAYOUT_FILL_X|MATRIX_BY_COLUMNS)
		matrix.numColumns = 2
		matrix.numRows = 4
		
		FXLabel.new(matrix, "m/z value", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
		@mz_textfield = FXTextField.new(matrix, 10, :opts => LAYOUT_CENTER_Y|LAYOUT_CENTER_X|FRAME_SUNKEN|FRAME_THICK|TEXTFIELD_REAL|LAYOUT_FILL)
		@mz_textfield.connect(SEL_COMMAND) do |sender, sel, event|
			if sender.text.size > 0
				# damn what the hell does mean the first.last??
				@spectrum_canvas.selected_point = [sender.text.to_f, @spectrum_canvas.visible_spectrum.to_a.first.last]
				@spectrum_canvas.update
			end
		end
		
		FXLabel.new(matrix, "interval value", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
		@interval_textfield = FXTextField.new(matrix, 10, :opts => LAYOUT_CENTER_Y|LAYOUT_CENTER_X|FRAME_SUNKEN|FRAME_THICK|TEXTFIELD_REAL|LAYOUT_FILL)
		@interval_textfield.connect(SEL_COMMAND) do |sender, sel, event|
			if sender.text.size > 0
				@spectrum_canvas.selected_interval = sender.text.to_f
				def self.moving_average(array, n)
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
				@spectrum_canvas.update
			end
		end
		
		FXLabel.new(matrix, "selected spectrum", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
		@tree_list_box = FXTreeListBox.new(matrix, nil, :opts => FRAME_SUNKEN|FRAME_THICK|LAYOUT_SIDE_TOP|LAYOUT_FILL)
		@tree_list_box.numVisible = 5
		@tree_list_box.connect(SEL_COMMAND) do |sender, sel, event|
			open_spectrum(event.to_s)
		end
		
		FXSeparator.new(matrix, :opts => SEPARATOR_NONE)
		FXButton.new(matrix, "Show average spectrum", :opts => LAYOUT_FILL|BUTTON_NORMAL).connect(SEL_COMMAND) do |sender, sel, event|
			# load average
			if @average_spectrum.nil?
				run_on_background do 
					create_average_spectrum
				end
			end
			@spectrum = @average_spectrum.dup
			@spectrum_canvas.visible_spectrum = @average_spectrum.dup
			@selected_y = @selected_x = 0
			@image_canvas.update
			update_visible_spectrum
		end
		
		FXSeparator.new(matrix, :opts => SEPARATOR_NONE)
		FXButton.new(matrix, "Draw image", :opts => LAYOUT_FILL|BUTTON_NORMAL).connect(SEL_COMMAND) do |sender, sel, event|
			run_on_background do
				create_image
			end
		end
		
		# basic tab (end)
		
		# smoothing tab (fold)
		
		@smoothing_tab = FXTabItem.new(@tabbook, "Smoothing")
		matrix = FXMatrix.new(@tabbook, :opts => FRAME_THICK|FRAME_RAISED|LAYOUT_FILL_X|MATRIX_BY_ROWS)
		matrix.numColumns = 2
		matrix.numRows = 3
		
		# smoothing radio choices
		@smoothing = FXDataTarget.new(SMOOTHING_NONE)
		@smoothing.connect(SEL_COMMAND) do |sender, sel, event|
			puts "Smoothing is now #{sender.value}"
		end
		
		# smoothing none choice
		smoothing_none = FXRadioButton.new(matrix, "None", :target => @smoothing, :selector => FXDataTarget::ID_OPTION)
		smoothing_none.checkState = true
		
		# smoothing moving average choice
		smoothing_moving_average = FXRadioButton.new(matrix, "Moving average", :target => @smoothing, :selector => FXDataTarget::ID_OPTION + ImzML::Smoothing::MovingAverage::ID)
		
		# smoothing savitzky golay choice
		smoothing_savitzky_golay = FXRadioButton.new(matrix, "Savitzky-Golay", :target => @smoothing, :selector => FXDataTarget::ID_OPTION + ImzML::Smoothing::SavitzkyGolay::ID)
		
		# smoothing specific settings
		matrix = FXMatrix.new(matrix, :opts => LAYOUT_FILL_X|MATRIX_BY_ROWS)
		matrix.numColumns = 2
		matrix.numRows = 1
		
		FXLabel.new(matrix, "n", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
		moving_average_smoothing_n_text_field = FXTextField.new(matrix, 10, :opts => FRAME_SUNKEN|FRAME_THICK|LAYOUT_SIDE_TOP|LAYOUT_FILL)
		moving_average_smoothing_n_text_field.connect(SEL_COMMAND) do |sender, sel, event|
			
		end
		
		# smoothing tab (end)
		
		# calibration tab (fold)
		@calibration_tab = FXTabItem.new(@tabbook, "Calibration")
		horizontal_frame = FXHorizontalFrame.new(@tabbook, :opts => LAYOUT_FILL_X|LAYOUT_SIDE_LEFT|FRAME_RAISED)
		
		table = FXTable.new(horizontal_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|TABLE_NO_COLSELECT)
		table.horizontalGridShown = true
		table.verticalGridShown = true
		table.setTableSize(0, 4)
		table.rowRenumbering = true
		table.rowHeaderMode = LAYOUT_FIX_WIDTH
		table.rowHeaderWidth = 30
		table.setColumnText(0, "selected")
		table.setColumnWidth(CALIBRATION_COLUMN_SELECTED, COLUMN_DEFAULT_WIDTH)
		table.setColumnText(1, "origin")
		table.setColumnWidth(CALIBRATION_COLUMN_ORIGIN, COLUMN_DEFAULT_WIDTH)
		table.setColumnText(2, "diff")
		table.setColumnWidth(CALIBRATION_COLUMN_DIFF, COLUMN_DEFAULT_WIDTH)
		table.setColumnText(3, "peptid")
		table.setColumnWidth(CALIBRATION_COLUMN_PEPTID, 85)
		table.selBackColor = FXColor::DarkGrey
		@table = table
		
		table.connect(SEL_REPLACED) do |sender, sel, event|
			item_position = event.fm
			item = sender.getItem(item_position.row, item_position.col)
			
			# validate input data
			case item_position.col
			when CALIBRATION_COLUMN_SELECTED..CALIBRATION_COLUMN_DIFF
				item.text = item.text.to_f.to_s
				
				recalculate_table_row(item_position.row, false)
			end
			
		end
		
		vertical_frame = FXVerticalFrame.new(horizontal_frame, :opts => LAYOUT_FILL_Y|LAYOUT_FIX_WIDTH|LAYOUT_SIDE_RIGHT, :width => 100)
		
		# button adding row
		add_row_button = FXButton.new(vertical_frame, "Add row", :opts => LAYOUT_FILL_X|BUTTON_NORMAL)
		add_row_button.connect(SEL_COMMAND) do |sender, sel, event|
			table.appendRows
			# init zero column value, last leave empty
			(table.numColumns - 1).times do |col|
				table.setItemText(table.numRows - 1, col, "0.0")
			end
			
			# disable editing of diff column
			table.disableItem(table.numRows - 1, CALIBRATION_COLUMN_DIFF)
			
			table.killSelection
		end
		
		# button removing row
		remove_row_button = FXButton.new(vertical_frame, "Remove row", :opts => LAYOUT_FILL_X|BUTTON_NORMAL)
		remove_row_button.connect(SEL_COMMAND) do |sender, sel, event|
			
			# delete row	  
			if table.numRows > 0
				selected_row = find_selected_table_row
				selected_row ||= table.numRows - 1
				table.removeRows(selected_row)
				@calibration_points.delete_at(selected_row)
			end
			
			# deselect everything
			table.killSelection
			
			@spectrum_canvas.update
		end
		
		FXVerticalSeparator.new(vertical_frame, :opts => LAYOUT_FILL_Y)
		
		combo_box = FXComboBox.new(vertical_frame, 1, :opts => LAYOUT_FILL_X|COMBOBOX_STATIC)
		combo_box.fillItems(%w{Linear})
		
		clear_button = FXButton.new(vertical_frame, "Clear", :opts => LAYOUT_FILL_X|BUTTON_NORMAL).connect(SEL_COMMAND) do
			@calibration = nil
			@spectrum = @original_spectrum.dup
			@spectrum_canvas.visible_spectrum = @spectrum.dup
			@image_canvas.update
			@spectrum_canvas.update 
			@spectrum_canvas.spectrum_drawn_points	 
			
			update_visible_spectrum	 
		end
		apply_button = FXButton.new(vertical_frame, "Apply", :opts => LAYOUT_FILL_X|BUTTON_NORMAL).connect(SEL_COMMAND) do
			calibrate
		end
		
		# calibration tab (end)
		
		# FIXME debug
		@tabbook.setCurrent(TAB_SMOOTHING)
	end
	
	def add_spectrum_part
		
		@font = FXFont.new(app, "times")
		@font.create
		
		# spectrum part
		bottom_horizontal_frame = FXHorizontalFrame.new(@main_frame, :opts => LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_BOTTOM|LAYOUT_RIGHT)
		
		# @spectrum_canvas = FXCanvas.new(bottom_horizontal_frame, :opts => LAYOUT_FILL)
		# @spectrum_canvas.connect(SEL_PAINT, method(:draw_canvas))
		@spectrum_canvas = Hyperspectral::SpectrumCanvas.new(bottom_horizontal_frame)
		
		@spectrum_canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, sel, event|
			if @spectrum_canvas.spectrum_drawn_points
				@mouse_left_down = true
				@spectrum_canvas.grab
				@zoom_from = @spectrum_canvas.canvas_point_to_spectrum([event.win_x, event.win_y])
			end
		end
		
		@spectrum_canvas.connect(SEL_LEFTBUTTONRELEASE) do |sender, sel, event|
			if @mouse_left_down
				@spectrum_canvas.ungrab
				@mouse_left_down = false
				
				update_visible_spectrum
			end
		end 
		
		@spectrum_canvas.connect(SEL_RIGHTBUTTONPRESS) do |sender, sel, event|
			@mouse_right_down = true
			@spectrum_canvas.grab
			point = [event.win_x, event.win_y]
			case @tabbook.current
			when TAB_BASICS
				@spectrum_canvas.selected_point = @spectrum_canvas.canvas_point_to_spectrum(point)
			when TAB_CALIBRATIONS
				choose_calibration_point(@spectrum_canvas.canvas_point_to_spectrum(point).first)			 
			end
			@spectrum_canvas.update
		end
		
		@spectrum_canvas.connect(SEL_RIGHTBUTTONRELEASE) do |sender, sel, event|
			if @mouse_right_down
				@spectrum_canvas.ungrab
				@mouse_right_down = false
				point = [event.win_x, event.win_y]
				
				case @tabbook.current
				when TAB_BASICS then @mz_textfield.text = @spectrum_canvas.selected_point.first.round(ROUND_DIGITS).to_s
				when TAB_CALIBRATIONS
					choose_calibration_point(@spectrum_canvas.canvas_point_to_spectrum(point).first)		   
				end
			end
			@spectrum_canvas.update
		end
		
		@spectrum_canvas.connect(SEL_MOTION) do |sender, sel, event|
			if @mouse_left_down
				@zoom_to = @spectrum_canvas.canvas_point_to_spectrum([event.win_x, event.win_y])
				@status_line.text = "Zoom from #{@zoom_from.first} to #{@zoom_to.first}"
				@spectrum_canvas.update
			elsif @mouse_right_down
				
				point = [event.win_x, event.win_y]
				
				case @tabbook.current
				when TAB_BASICS
					@spectrum_canvas.selected_point = @spectrum_canvas.canvas_point_to_spectrum(point)
					@status_line.text = "Selected MZ value #{@spectrum_canvas.selected_point.first.round(ROUND_DIGITS)}"
				when TAB_CALIBRATIONS
					choose_calibration_point(@spectrum_canvas.canvas_point_to_spectrum(point).first)		   
				end
				
				@spectrum_canvas.update
			end
		end
		
		zoom_button_vertical_frame = FXVerticalFrame.new(bottom_horizontal_frame, :opts => LAYOUT_FIX_WIDTH|LAYOUT_FILL_Y, :width => 50)
		
		# zoom buttons
		zoom_in_button = FXButton.new(zoom_button_vertical_frame, "+", :opts => FRAME_RAISED|LAYOUT_FILL)
		zoom_in_button.connect(SEL_COMMAND) do
			
			visible_spectrum = @spectrum_canvas.visible_spectrum.to_a
			
			# recalculate zoom in values
			if (visible_spectrum.size > 4)
				quarter = (visible_spectrum.last.first - visible_spectrum.first.first) / 4
				zoom_begin = visible_spectrum.first.first + quarter
				zoom_end = visible_spectrum.last.first - quarter
				
				@zoom_from = [zoom_begin, nil]
				@zoom_to = [zoom_end, nil]
				
				update_visible_spectrum
			end
		end
		
		zoom_reset_buttom = FXButton.new(zoom_button_vertical_frame, "100%", :opts => FRAME_RAISED|LAYOUT_FILL)
		zoom_reset_buttom.connect(SEL_COMMAND) do
			spectrum = @spectrum.to_a
			@zoom_from = [spectrum.first.first, nil]
			@zoom_to = [spectrum.last.first, nil]
			
			update_visible_spectrum
		end
		
		zoom_out_button = FXButton.new(zoom_button_vertical_frame, "-", :opts => FRAME_RAISED|LAYOUT_FILL)
		zoom_out_button.connect(SEL_COMMAND) do
			visible_spectrum = @spectrum_canvas.visible_spectrum.to_a
			spectrum = @spectrum.to_a
			
			# recalculate zoom out values
			if (visible_spectrum.size > 4)
				quarter = (visible_spectrum.last.first - visible_spectrum.first.first) / 4
				zoom_begin = visible_spectrum.first.first - quarter
				zoom_end = visible_spectrum.last.first + quarter
				
				# limit to the spectrum values
				zoom_begin = spectrum.first.first if zoom_begin < spectrum.first.first
				zoom_end = spectrum.last.first if zoom_end > spectrum.last.first
				
				@zoom_from = [zoom_begin, nil]
				@zoom_to = [zoom_end, nil]
				
				update_visible_spectrum
			end
			
		end
	end
	
	def create
		super
		
		reset_to_default_values
		
		show(PLACEMENT_VISIBLE)
		
		# FIXME debug
		run_on_background do
			read_file(DEBUG_DIR)
		end
	end
	
	def create_average_spectrum
	
		log("Calculating average spectrum") do
			
			dictionary = Hash.new
			sum = @imzml.spectrums.size
			
			progress_add(sum.to_i)
			
			# add all values
			@imzml.spectrums.each do |s|
				
				mz_array = s.mz_array(@datapath)
				intensity_array = s.intensity_array(@datapath)
				
				# create data array
				mz_array.zip(intensity_array).each do |key_value|
					key = key_value.first
					value = key_value.last
					
					dictionary[key] ||= 0
					dictionary[key] += value
				end		   
				
				progress_done
				
			end
			
			# divide and make average
			dictionary.each do |key, value|
				value /= sum
			end
			
			# save average spectrum
			@spectrum = dictionary
			@spectrum_canvas.visible_spectrum = dictionary.dup
			@average_spectrum = dictionary.dup
		end
		
		update_visible_spectrum
	end
	
	def create_image
		
		# when nothing selected cannot create image
		return if @spectrum_canvas.selected_point.nil? || @spectrum_canvas.selected_interval.nil?
		
		log("Creating hyperspectral image") do
			
			progress_add(@imzml.spectrums.size.to_i)
			
			data = @imzml.image_data(@datapath, @spectrum_canvas.selected_point.first, @spectrum_canvas.selected_interval) do |id|
				progress_done
			end
			
			# remve nil values
			data.map{|x| x.nil? ? 0 : x}
			
			# normalize value into greyscale
			max_normalized = data.max - data.min
			max_normalized = 1 if max_normalized == 0
			min = data.min
			step = 255.0 / max_normalized
			greyscale_data = Array.new
			data.each do |i|
				value = (step * (i - min)).to_i
				greyscale_data << FXRGB(value, value, value)
			end
			
			data = greyscale_data
			
			# create empty image
			image = FXPNGImage.new(getApp(), nil, IMAGE_KEEP|IMAGE_SHMI|IMAGE_SHMP, :width => @imzml.pixel_count_x, :height => @imzml.pixel_count_y)
			
			# rescale image and fill image view
			scale_w = IMAGE_WIDTH
			scale_h = IMAGE_HEIGHT
			if image.width > image.height
				scale_h = image.height.to_f/image.width.to_f * IMAGE_HEIGHT 
			else
				scale_w = image.width.to_f/image.height.to_f * IMAGE_WIDTH
			end
			image.pixels = data
			image.scale(scale_w, scale_h)
			@scale_y, @scale_x = (image.width)/@imzml.pixel_count_x.to_f, (image.height)/@imzml.pixel_count_y.to_f
			image.create
			
			# assign image
			@image = image
			
		end
		
		# save selected spectrum for image
		@spectrum_canvas.selected_fixed_point = @spectrum_canvas.selected_point.dup
		@spectrum_canvas.selected_fixed_interval = @spectrum_canvas.selected_interval
		@spectrum_canvas.update
		
		@image_canvas.update
	end
	
	def draw_canvas(sender, sel, event)
		if sender && sel && event
			FXDCWindow.new(sender, event) do |dc|
				case sender
				when @spectrum_canvas
					# # draw background
					dc.foreground = FXColor::White
					dc.fillRectangle(0, 0, sender.width, sender.height)
					
					# draw axis
					dc.foreground = FXColor::Black
					
					# x and y axis
					dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, sender.width - AXIS_PADDING, sender.height - AXIS_PADDING)
					dc.drawLine(AXIS_PADDING, sender.height - AXIS_PADDING, AXIS_PADDING, AXIS_PADDING)
					dc.font = @font
					
					if @spectrum_canvas.visible_spectrum && @spectrum_canvas.spectrum_min_x && @spectrum_canvas.spectrum_max_x
						
						# recalculate points
						
						# calculate spectrum points and save to cache
						if @spectrum_canvas.spectrum_drawn_points.nil?
							points = Array.new
							
							previous_point = nil
							useless_points = 0
							@spectrum_canvas.visible_spectrum.each do |mz, intensity|
								
								mz = @calibration.recalculate(mz) if @calibration
								point = @spectrum_canvas.spectrum_point_to_canvas([mz, intensity])
								# do not draw the same point twice
								points << FXPoint.new(point.first.to_i, point.last.to_i)
								
								previous_point = point
							end
							
							@spectrum_canvas.spectrum_drawn_points = points
						end
						
						# load from cache
						points = @spectrum_canvas.spectrum_drawn_points
						
						# draw labels
						labels = Array.new
						visible_spectrum = @spectrum_canvas.visible_spectrum.to_a
						
						# draw visible spectrum
						every_x = (visible_spectrum.last.first - visible_spectrum.first.first) / LABEL_X_EVERY
						every_y = (@spectrum_canvas.visible_spectrum.values.max - @spectrum_canvas.visible_spectrum.values.min) / LABEL_Y_EVERY
						i, j = visible_spectrum.first.first, visible_spectrum.first.last
						@spectrum_canvas.visible_spectrum.each_with_index do |item, index|
							
							# x labels
							if (item.first > i)
								point = @spectrum_canvas.spectrum_point_to_canvas(item)
								text = item.first.round(3).to_s
								text_width = @font.getTextWidth(text)
								
								dc.drawLine(point.first.to_i, @spectrum_canvas.height - AXIS_PADDING + 3, point.first.to_i, @spectrum_canvas.height - AXIS_PADDING)
								dc.drawText(point.first.to_i - text_width/2, @spectrum_canvas.height - AXIS_PADDING / 2, text)
								i += every_x
							end
							
							# y labels
							if (item.last > j)
								
								point = @spectrum_canvas.spectrum_point_to_canvas(item)
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
							canvas_from = @spectrum_canvas.spectrum_point_to_canvas(@zoom_from)
							canvas_to = @spectrum_canvas.spectrum_point_to_canvas(@zoom_to)
							
							dc.lineStyle = LINE_ONOFF_DASH
							dc.foreground = FXColor::Blue
							begining = (canvas_from.first > canvas_to.first) ? canvas_to : canvas_from
							dc.drawRectangle(begining.first, AXIS_PADDING, (canvas_from.first - canvas_to.first).abs, @spectrum_canvas.height - 2 * AXIS_PADDING)
							dc.lineStyle = LINE_SOLID
						end
						
						# draw selected fixed line
						draw_selected_line(dc, @spectrum_canvas.selected_fixed_point, @spectrum_canvas.selected_fixed_interval, FXColor::LightGrey)
						
						# draw selected line
						if @tabbook.current == TAB_BASICS
							draw_selected_line(dc, @spectrum_canvas.selected_point, @spectrum_canvas.selected_interval, FXColor::SteelBlue)
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
					
				when @image_canvas # (fold)
					# clear canvas
					dc.foreground = FXColor::White
					dc.fillRectangle(0, 0, @image_canvas.width, @image_canvas.height)
					
					# draw image
					if @image
						dc.drawImage(@image, 0, 0)
					end
					
					if @image && !@selected_x.nil? && !@selected_y.nil?
						# draw cross
						dc.foreground = FXColor::Green
						dc.drawLine(@selected_x, 0, @selected_x, sender.height)
						dc.drawLine(0, @selected_y, sender.width, @selected_y)
					end 
					# (end)
				end
			end
		end
	end
	
	def open_spectrum(id)
		
		# select current spectrum in list
		item = @tree_list_box.findItem(id)
		@tree_list_box.setCurrentItem(item)
		
		# find spectrum by id
		spectrum = nil
		@imzml.spectrums.each do |s|
			spectrum = s if s.id == id
		end
		
		# display spectrum on image
		spectrum_to_image_point(spectrum)
		@selected_x, @selected_y = spectrum_to_image_point(spectrum)
		@image_canvas.update
		
		# load spectrum data
		if spectrum
			mz_array = spectrum.mz_array(@datapath)
			intensity_array = spectrum.intensity_array(@datapath)
			
			zipped_array = mz_array.zip(intensity_array)
			
			array = zipped_array.flatten
			hash = Hash.new
			array.each_with_index {|item, index| hash[item] = array[index + 1] if index % 2 == 0 }
			dictionary = hash
			@spectrum = dictionary
			@original_spectrum = dictionary.dup
			@spectrum_canvas.visible_spectrum = dictionary.dup
			
			update_visible_spectrum
		else
			raise "spectrum with ID #{id} not found"
		end
		
	end
	
	def reset_to_default_values
		
		# reset calculated spectrum data
		@average_spectrum = @spectrum = nil
		@spectrum_canvas.spectrum_drawn_points = nil
		@imzml = nil
		
		# reset image vars
		@selected_x, @selected_y = 0, 0
		@scale_x, @scale_y = 1, 1
		@image = nil
		
		# reset spectrum vars
		@spectrum_canvas.selected_point, @spectrum_canvas.selected_interval = nil, 0
		@spectrum_canvas.selected_fixed_point, @spectrum_canvas.selected_fixed_interval = nil, 0
		
		# reset input fields
		@interval_textfield.text = @spectrum_canvas.selected_interval.to_s
		@mz_textfield.text = "0"
		@interval_textfield.text = "0"
		@tree_list_box.clearItems
		
		# calibration defaults
		@calibration_points = Array.new
		@table.removeRows(0, @table.numRows)
	end
	
	def read_file(filepath)
		
		reset_to_default_values
		
		pp "reading file"
		
		log("Parsing imzML file") do
			@filename = filepath.split("/").last
			self.title = @filename
			@datapath = filepath.gsub(/imzML$/, "ibd")
			pp "datapath #{@datapath}"
			imzml_parser = ImzML::Parser.new
			pp "parser created"
			File.open(filepath, 'r') do |f|
				Ox.sax_parse(imzml_parser, f)
			end
			
			@imzml = imzml_parser.metadata
			
			@imzml.spectrums.each do |s|
				@tree_list_box.appendItem(nil, s.id)
			end
			
		end
		
		open_spectrum(@imzml.spectrums.first.id)
		# create_average_spectrum
		create_image
		
		@image_canvas.update
	end
	
	def update_visible_spectrum
		if @zoom_from && @zoom_to
			
			# flip values if set on other sides
			@zoom_from, @zoom_to = @zoom_to, @zoom_from if @zoom_from.first > @zoom_to.first
			
			# copy original spectrum
			@spectrum_canvas.visible_spectrum = @spectrum.dup
			
			# delete unwanted values
			@spectrum_canvas.visible_spectrum.delete_if{ |key, value| key < @zoom_from.first || key > @zoom_to.first }
			
			# reset spectrum cache
			@spectrum_canvas.spectrum_drawn_points = nil
			
			# reset zoom values
			@zoom_from = @zoom_to = nil
			
		end
		
		# find min max values
		@spectrum_canvas.spectrum_min_x, @spectrum_canvas.spectrum_max_x = @spectrum_canvas.visible_spectrum.keys.min, @spectrum_canvas.visible_spectrum.keys.max
		@spectrum_canvas.spectrum_min_y, @spectrum_canvas.spectrum_max_y = @spectrum_canvas.visible_spectrum.values.min, @spectrum_canvas.visible_spectrum.values.max
		
		@spectrum_canvas.update
	end
	
	private
	
	def choose_calibration_point(point)
		if @table.numRows > 0
			
			selected_row = find_selected_table_row
			selected_row ||= @table.numRows - 1
			
			# save value
			@calibration_points[selected_row] = point
			
			# fill value into table
			@table.setItemText(selected_row, CALIBRATION_COLUMN_SELECTED, point.round(ROUND_DIGITS).to_s)
			
			# recalculate table
			recalculate_table_row(selected_row)
			
			@spectrum_canvas.update
		end
	end
	
	def log(message = "Please wait")
		start = Time.now
		
		progress_add(1)
		message = "#{message} ... "
		@progress_dialog.message = message
		# print message
		yield
		# print "#{Time.now - start}s\n"
		progress_done
	end
	
	def profile
		PerfTools::CpuProfiler.start("/tmp/profile_data") do
			yield
		end
	end
	
	def run_on_background
		@mutex.synchronize {
			@progress_dialog.total, @progress_dialog.progress = 0, 0
		}
		Thread.new {
			yield
		}
		@progress_dialog.execute(PLACEMENT_OWNER)
	end
	
	def progress_add(amount)
		@mutex.synchronize {
			@progress_dialog.total += amount
		}
	end
	
	def progress_done
		@mutex.synchronize {
			@progress_dialog.increment(1)
		}
	end
	
	def calibrate
		
		origins = Array.new
		
		@calibration_points.each_with_index do |x, i|
			item = @table.getItemText(i, CALIBRATION_COLUMN_ORIGIN)
			origins << item.to_f
		end
		
		x_values = @calibration_points.dup
		y_values = origins.zip(@calibration_points).map { |x, y| (x-y) }
		
		# prepare values for linear calibration
		xy_sum = x_values.zip(y_values).map { |x, y| x * y }.reduce(:+)
		x_sum = x_values.reduce(:+)
		y_sum = y_values.reduce(:+)
		xx_sum = x_values.map{|x| x*x}.reduce(:+)
		x_sumsum = x_sum*x_sum
		n = x_values.size
		
		a = (n*xy_sum - x_sum * y_sum) / (n*xx_sum - x_sumsum)
		b = (xx_sum*y_sum - x_sum*xy_sum)  / (n*xx_sum - x_sumsum)
		
		@calibration = ImzML::Calibration::Linear.new(a, b)
		
		array = @spectrum.map { |key, value| [@calibration.recalculate(key), value] }
		@spectrum = array_to_h(array)
		@spectrum_canvas.visible_spectrum = @spectrum.dup
		@spectrum_canvas.spectrum_drawn_points = nil
		
		update_visible_spectrum
	end
	
	def recalculate_table_row(row, notify = true)
		
		# recalculate table
		selected_item = @table.getItem(row, CALIBRATION_COLUMN_SELECTED)
		origin_item = @table.getItem(row, CALIBRATION_COLUMN_ORIGIN)
		
		diff = selected_item.text.to_f - origin_item.text.to_f
		@table.setItemText(row, CALIBRATION_COLUMN_DIFF, diff.round(ROUND_DIGITS).to_s, notify)	 
	end
	
	def find_selected_table_row
		row_selected = nil
		if @table.anythingSelected?
			@table.numRows.times do |row_number|
				if @table.rowSelected?(row_number)
					row_selected = row_number
					break
				end
			end
		end
		
		row_selected
	end
	
	def image_point_to_spectrum(point)
		index = (point.last/@scale_y).to_i * @imzml.pixel_count_x + (point.first/@scale_x).to_i
		spectrum = @imzml.spectrums[index]
		spectrum
	end
	
	def spectrum_to_image_point(spectrum)
		index = @imzml.spectrums.index(spectrum)
		
		x = ((index % @imzml.pixel_count_x).to_i * @scale_x) + @scale_x / 2
		y = ((index / @imzml.pixel_count_x).to_i * @scale_y) + @scale_y / 2
		
		[x, y]
	end
	
	# convert Array [[a, b], [c, d]] to hash {a=>b, c=>d} without stack problem
	def array_to_h(array)
		hash = Hash.new
		array = array.flatten
		array.each_with_index do |item, index| 
			hash[item] = array[index + 1] if index % 2 == 0
		end
		hash
	end
	
end

end

if __FILE__ == $0
	FXApp.new do |app|
		Hyperspectral::Reader.new(app)
		app.create
		app.run
	end
end