module Hyperspectral

  include Fox

  class MainController < FXMainWindow

    def initialize(app)
      super(app, "imzML Hyperspectral", :width => 800, :height => 600)
      load_view(self)

      connect(SEL_CONFIGURE, method(:window_size_changed))

    end

    def create
      super
      show(PLACEMENT_VISIBLE)

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
      vertical_frame = FXVerticalFrame.new(superview, :opts => LAYOUT_FILL)

      # =======================
      # = SPECTRUM CONTROLLER =
      # =======================
      @spectrum_controller = SpectrumController.new
      @spectrum_controller.load_view(vertical_frame)

    end

    def open_file(filepath)
      p "I should open #{filepath}"

      # self.title = filepath.split("/").last
      # @metadata = ImzML::Parser.new(filepath).metadata

      # FIXME debug
      @spectrum_controller.points = Hash[1, 2, 2, 5, 3, 3, 4, 3, 5, 2, 6, 1, 7, 4, 8, 3, 9, 1, 10, 4, 11, 6, 12, 8, 13, 2]
      pp @spectrum_controller.points

      # @metadata.spectrums.each do |k, v|
      #   @tree_list_box.appendItem(nil, k.to_s)
      # end
    end

    def window_size_changed(sender, selector, event)
      @spectrum_controller.needs_display
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

  end

end