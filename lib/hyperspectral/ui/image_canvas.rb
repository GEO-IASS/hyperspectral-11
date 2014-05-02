module Hyperspectral
  
  include Fox
  
  class ImageCanvas < FXHorizontalFrame
    
    # FXCanvas instance
    attr_reader :canvas
    
    # FXPNGImage instance
    attr_reader :image
    
    # The selected point in image, not related to the real displayed pixels but 
    # to the pixels from experiment 
    attr_accessor :selected_point
    
    def initialize(view)
      super(view, :opts => LAYOUT_FILL_X)
      
      image_container = FXPacker.new(self, :opts => FRAME_SUNKEN|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT, :width => IMAGE_WIDTH, :height => IMAGE_HEIGHT)
      @canvas = FXCanvas.new(image_container, :opts => LAYOUT_CENTER_X|LAYOUT_CENTER_Y|LAYOUT_FILL|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT, :width => IMAGE_WIDTH, :height => IMAGE_HEIGHT)
      @canvas.connect(SEL_PAINT, method(:draw_canvas))
		
      @canvas.connect(SEL_LEFTBUTTONPRESS) do |sender, sel, event|
        if @image
          @selected_point = Point.new(event.win_x, event.win_y)
          @mouse_right_down = true
          @canvas.update
        end
      end
		
      @canvas.connect(SEL_MOTION) do |sender, sel, event|
        if @mouse_right_down
          @selected_point.x, @selected_point.y = event.win_x, event.win_y
          @selected_point.y = 0 if @selected_point.y < 0
          @selected_point.y = @canvas.height if @selected_point.y > @canvas.height
          @selected_point.x = 0 if @selected_point.x < 0
          @selected_point.x = @canvas.width if @selected_point.x > @canvas.width
				
          spectrum = image_point_to_spectrum([@selected_point.x, @selected_point.y])
          @status_line.text = "Selected spectrum #{spectrum.id}"
          @canvas.update
        end
      end
		
      @canvas.connect(SEL_LEFTBUTTONRELEASE) do |sender, sel, event|
        if @mouse_right_down
          @mouse_right_down = false
				
          selected_spectrum = image_point_to_spectrum([@selected_point.x, @selected_point.y])
          open_spectrum(selected_spectrum.id) if selected_spectrum
        end
      end
		
      # tab settings
      @tabbook = FXTabBook.new(self, :opts => LAYOUT_FILL_X|LAYOUT_RIGHT|LAYOUT_FILL_Y)
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
          @spectrum_canvas.update
        end
      end
		
      FXLabel.new(matrix, "selected spectrum", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
      @tree_list_box = FXTreeListBox.new(matrix, nil, :opts => FRAME_SUNKEN|FRAME_THICK|LAYOUT_SIDE_TOP|LAYOUT_FILL)
      @tree_list_box.numVisible = 5
      @tree_list_box.connect(SEL_COMMAND) do |sender, sel, event|
      
        # open specfic spectrum
        spectrum = @metadata.spectrums[event.to_s.to_sym]
        open_spectrum(spectrum)
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
        @selected_point.y = @selected_point.x = 0
        @canvas.update
        update_visible_spectrum
      end
		
      FXSeparator.new(matrix, :opts => SEPARATOR_NONE)
      FXButton.new(matrix, "Draw image", :opts => LAYOUT_FILL|BUTTON_NORMAL).connect(SEL_COMMAND) do |sender, sel, event|
        run_on_background do
          create_image
        end
      end
    
      FXSeparator.new(matrix, :opts => SEPARATOR_NONE)
      FXButton.new(matrix, "Find peaks", :opts => LAYOUT_FILL|BUTTON_NORMAL).connect(SEL_COMMAND) do |sender, sel, event|
        run_on_background do
			
          # TODO load data from current spectrum
          peaks = PeakDetector.peak_indexes(@spectrum.values)
          keys = @spectrum.keys
          @spectrum_canvas.peaks = peaks.map{|index| keys[index]}
          @spectrum_canvas.update
        end
      end
		
      # basic tab (end)
		
      # smoothing tab (fold)
		
      @smoothing_tab = FXTabItem.new(@tabbook, "Smoothing")
      matrix = FXMatrix.new(@tabbook, :opts => FRAME_THICK|FRAME_RAISED|LAYOUT_FILL_X|MATRIX_BY_ROWS)
      matrix.numColumns = 2
      matrix.numRows = 3
		
      # smoothing radio choices
      @selected_smoothing = FXDataTarget.new(0)
      @selected_smoothing.connect(SEL_COMMAND) do |sender, sel, event|
			
        # redraw spectrum with preview
        @spectrum_canvas.smoothing = @smoothing_methods[sender.value]
        @spectrum_canvas.reset_cache
        @spectrum_canvas.update
      end
		
      # add smoothing methods to the matrix
      @smoothing_methods.each_with_index do |value, index|
			
        # for no smoothing set the name
        name = value.nil? ? "None" : value.name
        radio_button = FXRadioButton.new(matrix, name, @selected_smoothing, FXDataTarget::ID_OPTION + index)
			
        # by default select no smoothing
        radio_button.checkState = true if value.nil? == 0
      end

      # smoothing specific settings
      matrix = FXMatrix.new(matrix, :opts => LAYOUT_FILL_X|MATRIX_BY_ROWS)
      matrix.numColumns = 2
      matrix.numRows = 1
		
      # create text field for window size settings
      FXLabel.new(matrix, "window size", nil, LAYOUT_CENTER_Y|LAYOUT_CENTER_X|JUSTIFY_RIGHT|LAYOUT_FILL_ROW)
      window_size_text_field = FXTextField.new(matrix, 10, :opts => FRAME_SUNKEN|FRAME_THICK|LAYOUT_SIDE_TOP|LAYOUT_FILL)
      window_size_text_field.connect(SEL_COMMAND) do |sender, sel, event|
			
        # when value of window size change, update the graph
        @spectrum_canvas.smoothing_window_size = sender.text.to_i
        @spectrum_canvas.reset_cache
        @spectrum_canvas.update
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
        @canvas.update
        @spectrum_canvas.reset_cache
        @spectrum_canvas.update  
			
        update_visible_spectrum	 
      end
      apply_button = FXButton.new(vertical_frame, "Apply", :opts => LAYOUT_FILL_X|BUTTON_NORMAL).connect(SEL_COMMAND) do
        calibrate
      end
		
      # calibration tab (end)
		
      # FIXME debug
      @tabbook.setCurrent(TAB_BASICS)
      
    end

    def draw_canvas(sender, sel, event)
      
      return if sender.nil? || sel.nil? || event.nil?
      FXDCWindow.new(sender, event) do |dc|
        # clear canvas
        dc.foreground = FXColor::White
        dc.fillRectangle(0, 0, @image_canvas.width, @image_canvas.height)
				
        # draw image
        if @image
          dc.drawImage(@image, 0, 0)
        end
				
        if @image && !@selected_point.x.nil? && !@selected_point.y.nil?
          # draw cross
          dc.foreground = FXColor::Green
          dc.drawLine(@selected_point.x, 0, @selected_point.x, sender.height)
          dc.drawLine(0, @selected_point.y, sender.width, @selected_point.y)
        end 
      end
    end
    
  end
  
  
end