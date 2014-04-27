include Fox

module Hyperspectral
  
  class MenuBar < FXMenuBar
    
    attr_accessor :when_file_opens
    attr_accessor :when_image_save
    attr_accessor :when_spectrum_save
    attr_accessor :when_exit

    def initialize(window)
      super(window, LAYOUT_SIDE_TOP|LAYOUT_FILL_X)
	
      # ========
      # = FILE =
      # ========
      file_menu = FXMenuPane.new(self)
      FXMenuTitle.new(self, "File", :popupMenu => file_menu)
	
      FXMenuCommand.new(file_menu, "Open...").connect(SEL_COMMAND) do
        dialog = FXFileDialog.new(self, "Open imzML file")
        dialog.directory = "#{DEFAULT_DIR}"
        dialog.patternList = ["imzML files (*.imzML)"]
		
        # after success on opening
        if (dialog.execute != 0)
          @when_file_opens.call(dialog.filename)
        end
      end
	
      FXMenuSeparator.new(file_menu)
	
      FXMenuCommand.new(file_menu, "Save image...").connect(SEL_COMMAND) do
        saveDialog = FXFileDialog.new(self, "Save as PNG")
        saveDialog.patternList = ["PNG files (*.png)"]
        if @image
          if saveDialog.execute != 0
            @when_image_save.call(saveDialog.filename)
          end
        end
      end
	
      FXMenuCommand.new(file_menu, "Save spectrum ...").connect(SEL_COMMAND) do
        saveDialog = FXFileDialog.new(self, "Save as CSV")
        saveDialog.patternList = ["CSV files (*.csv)"]
        if @spectrum
          if saveDialog.execute != 0
            @when_spectrum_save.call(saveDialog.filename)
          end
        end
      end
	
      FXMenuSeparator.new(file_menu)
	
      FXMenuCommand.new(file_menu, "Exit").connect(SEL_COMMAND) do
        @when_exit.call
      end

      # ===============
      # = CALIBRATION =
      # ===============
      calibration_menu = FXMenuPane.new(self)
      FXMenuTitle.new(self, "Calibration", :popupMenu => calibration_menu)
	
      FXMenuCommand.new(calibration_menu, "Load template").connect(SEL_COMMAND) do
        dialog = FXFileDialog.new(self, "Open calibration file...")
        dialog.directory = "#{DEFAULT_DIR}"
        dialog.patternList = ["CSV (*.csv)"]
		
        # after success on opening
        if (dialog.execute != 0)
			    @when_template_loaded.call(dialog.filename)
        end
      end
      
      # =========
      # = DEBUG =
      # =========
      debug_menu = FXMenuPane.new(self)
      FXMenuTitle.new(self, "DEBUG", :popupMenu => debug_menu)
	
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
  
  end

end