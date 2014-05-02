include Fox

module Hyperspectral
  
  class MenuBar < FXMenuBar
    
    include Callbacks
    
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
          callback(:when_file_opens, dialog.filename)
        end
      end
	
      FXMenuSeparator.new(file_menu)
	
      FXMenuCommand.new(file_menu, "Save image...").connect(SEL_COMMAND) do
        saveDialog = FXFileDialog.new(self, "Save as PNG")
        saveDialog.patternList = ["PNG files (*.png)"]
        if @image
          if saveDialog.execute != 0
            callback(:when_image_save, saveDialog.filename)
          end
        end
      end
	
      FXMenuCommand.new(file_menu, "Save spectrum ...").connect(SEL_COMMAND) do
        saveDialog = FXFileDialog.new(self, "Save as CSV")
        saveDialog.patternList = ["CSV files (*.csv)"]
        if @spectrum
          if saveDialog.execute != 0
            callback(:when_spectrum_save, saveDialog.filename)
          end
        end
      end
	
      FXMenuSeparator.new(file_menu)
	
      FXMenuCommand.new(file_menu, "Exit").connect(SEL_COMMAND) do
        callback(:when_exit)
      end
      
    end
  
  end

end