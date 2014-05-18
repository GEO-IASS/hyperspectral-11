module Hyperspectral

  class MenuBar < Fox::FXMenuBar

    include Callbacks

    def initialize(window)
      super(window, Fox::LAYOUT_SIDE_TOP | Fox::LAYOUT_FILL_X)

      # ========
      # = FILE =
      # ========
      file_menu = Fox::FXMenuPane.new(self)
      Fox::FXMenuTitle.new(self, "File", :popupMenu => file_menu)

      Fox::FXMenuCommand.new(file_menu, "Open...").connect(Fox::SEL_COMMAND) do
        dialog = Fox::FXFileDialog.new(self, "Open imzML file")
        # FIXME debug
        dialog.directory = "/Users/beny/Desktop/imzML"
        dialog.patternList = ["imzML files (*.imzML)"]

        # after success on opening
        if (dialog.execute != 0)
          callback(:when_file_opens, dialog.filename)
        end
      end

      Fox::FXMenuSeparator.new(file_menu)

      Fox::FXMenuCommand.new(file_menu, "Save image...").connect(Fox::SEL_COMMAND) do
        saveDialog = Fox::FXFileDialog.new(self, "Save as PNG")
        saveDialog.patternList = ["PNG files (*.png)"]
        if @image
          if saveDialog.execute != 0
            callback(:when_image_save, saveDialog.filename)
          end
        end
      end

      Fox::FXMenuCommand.new(file_menu, "Save spectrum ...").connect(Fox::SEL_COMMAND) do
        saveDialog = Fox::FXFileDialog.new(self, "Save as CSV")
        saveDialog.patternList = ["CSV files (*.csv)"]
        if @spectrum
          if saveDialog.execute != 0
            callback(:when_spectrum_save, saveDialog.filename)
          end
        end
      end

      Fox::FXMenuSeparator.new(file_menu)

      Fox::FXMenuCommand.new(file_menu, "Exit").connect(Fox::SEL_COMMAND) do
        callback(:when_exit)
      end

      ## FIXME debug
      # =========
      # = DEBUG =
      # =========

      debug_menu = Fox::FXMenuPane.new(self)
      Fox::FXMenuTitle.new(self, "DEBUG", :popupMenu => debug_menu)

      Fox::FXMenuCommand.new(debug_menu, "S042_Continuous").connect(Fox::SEL_COMMAND) do
        callback(:when_file_opens, "/Users/beny/Dropbox/School/dp/imzML/s042_continuous/S042_Continuous.imzML")
      end

    end

  end

end