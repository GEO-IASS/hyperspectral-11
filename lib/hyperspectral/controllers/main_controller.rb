module Hyperspectral

  class MainController < Fox::FXMainWindow

    def initialize(app)
      super(app, "imzML Hyperspectral", :width => 800, :height => 600)
      load_view(self)

      connect(Fox::SEL_CONFIGURE, method(:window_size_changed))
    end

    def create
      super
      show(Fox::PLACEMENT_VISIBLE)

      # FIXME debug
      open_file("/Users/beny/Dropbox/School/dp/imzML/example_files/Example_Continuous.imzML")
    end

    def load_view(superview)

      # ===================
      # = PROGRESS DIALOG =
      # ===================
      @progress_dialog = ProgressDialog.new(superview)

      # =======================
      # = MENU with callbacks =
      # =======================
      @menu_bar = Hyperspectral::MenuBar.new(superview)
      @menu_bar.when_file_opens do |filepath|
        open_file(filepath)
      end

      # ==============
      # = MAIN FRAME =
      # ==============
      vertical_frame = Fox::FXVerticalFrame.new(superview, :opts => Fox::LAYOUT_FILL)
      top_frame = Fox::FXHorizontalFrame.new(vertical_frame, :opts => Fox::LAYOUT_FILL_X)

      # ====================
      # = IMAGE CONTROLLER =
      # ====================
      @image_controller = ImageController.new
      @image_controller.load_view(top_frame)

      # ========
      # = TABS =
      # ========
      tab_book = Fox::FXTabBook.new(top_frame,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_RIGHT | Fox::LAYOUT_FILL_Y
      )
      tab_book.connect(Fox::SEL_COMMAND, method(:tab_changed))

      # ========================
      # = SELECTION CONTROLLER =
      # ========================
      @selection_controller = SelectionFeatureController.new
      @selection_controller.load_view(tab_book)
      @selection_controller.when_changed_mz_value do |mz_value|
        @spectrum_controller.selected_points = [mz_value]
      end
      @selection_controller.when_changed_interval_value do |interval|
        @spectrum_controller.selected_interval = interval
      end
      @selection_controller.when_spectrum_listbox_chaned do |name|
        open_spectrum(name)
      end

      # ========================
      # = SMOOTHING CONTROLLER =
      # ========================
      @smoothing_controller = SmoothingFeatureController.new
      @smoothing_controller.load_view(tab_book)

      @baseline_controller = BaselineFeatureController.new
      @baseline_controller.load_view(tab_book)

      @calibration_controller = CalibrationFeatureController.new
      @calibration_controller.load_view(tab_book)

      @peak_controller = PeakFeatureController.new
      @peak_controller.load_view(tab_book)

      # =======================
      # = SPECTRUM CONTROLLER =
      # =======================
      @spectrum_controller = SpectrumController.new
      @spectrum_controller.load_view(vertical_frame)
      @spectrum_controller.when_select_point do |selected_points|
        @selection_controller.selected_value = selected_points.first
      end

    end

    private

    # view controllers
    attr_accessor :spectrum_controller

    # models
    attr_accessor :metadata

    # views
    attr_accessor :menu_bar, :progress_dialog

    # help variables
    attr_accessor :mutex

    def open_file(filepath)

      self.title = filepath.split("/").last
      @metadata = ImzML::Parser.new(filepath).metadata

      # open spectrum
      open_spectrum

      # set spectrum names
      @selection_controller.spectrum_names = @metadata.spectrums.keys
    end

    def open_spectrum(name = nil)
      spectrum = nil
      if name
        spectrum = @metadata.spectrums[name.to_sym]
      else
        # load first spectrum by default
        spectrum = @metadata.spectrums.values.first
      end

      mz = spectrum.mz_binary.data
      intensity = spectrum.intensity_binary.data
      points = mz.zip(intensity).to_h

      # show points on spectrum
      @spectrum_controller.points = points
    end

    def tab_changed(sender, selector, event)

      # find selected tab
      tab_index = event
      tab_title = sender.children[tab_index * 2].to_s
      case tab_title
      when SelectionFeatureController::TITLE
        p tab_title
      when SmoothingFeatureController::TITLE
        p tab_title
      when BaselineFeatureController::TITLE
        p tab_title
      when CalibrationFeatureController::TITLE
        p tab_title
      when PeakFeatureController::TITLE
        p tab_title
      end

    end

    def window_size_changed(sender, selector, event)
      @spectrum_controller.needs_display
      @image_controller.need_display
    end

  end

end