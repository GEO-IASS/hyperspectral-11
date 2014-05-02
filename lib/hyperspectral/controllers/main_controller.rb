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
      open_file(nil)
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

      @selection_controller = SelectionFeatureController.new
      @selection_controller.load_view(tab_book)

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

    def open_file(filepath)
      p "I should open #{filepath}"

      # self.title = filepath.split("/").last
      # @metadata = ImzML::Parser.new(filepath).metadata

      # FIXME debug
      @spectrum_controller.points = Hash[1, 2, 2, 5, 3, 3, 4, 3, 5, 2, 6, 1, 7, 4, 8, 3, 9, 1, 10, 4, 11, 6, 12, 8, 13, 2]
      p @spectrum_controller.points

      # @metadata.spectrums.each do |k, v|
      #   @tree_list_box.appendItem(nil, k.to_s)
      # end
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

    def window_size_changed(sender, selector, event)
      @spectrum_controller.needs_display
      @image_controller.need_display
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


  end

end