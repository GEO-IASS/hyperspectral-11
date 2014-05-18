module Hyperspectral

  class MainController < Fox::FXMainWindow

    attr_accessor :use_cache

    def initialize(app)
      super(app, "imzML Hyperspectral", :width => 800, :height => 600)
      load_view(self)
      use_cache = false

      connect(Fox::SEL_CONFIGURE, method(:window_size_changed))
    end

    def create
      super
      show(Fox::PLACEMENT_VISIBLE)

      # FIXME debug
      open_file("/Users/beny/Desktop/imzML/example_files/Example_Continuous.imzML")
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

      # =========
      # = IMAGE =
      # =========
      @image_controller = ImageController.new
      @image_controller.load_view(top_frame)
      @image_controller.when_spectrum_selected do |spectrum_index|
        spectrum_name = @metadata.spectrums.keys[spectrum_index]
        open_spectrum(spectrum_name)
      end

      # ========
      # = TABS =
      # ========
      tab_book = Fox::FXTabBook.new(top_frame,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_RIGHT | Fox::LAYOUT_FILL_Y
      )
      tab_book.connect(Fox::SEL_COMMAND, method(:tab_changed))

      # =============
      # = SELECTION =
      # =============
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
      @selection_controller.when_average_spectrum_pressed do
        calculate_average_spectrum
      end
      @selection_controller.when_draw_image_pressed do
        show_image
      end
      @selection_controller.when_reset do
        @preprocess = Hash.new
      end
      @selection_controller.when_cache_changed do |state|
        @use_cache = state
      end

      # =============
      # = SMOOTHING =
      # =============
      @smoothing_controller = SmoothingFeatureController.new
      @smoothing_controller.load_view(tab_book)
      @smoothing_controller.when_smoothing_applied do |preview_points|
        @spectrum_controller.preview_points = preview_points
      end
      @smoothing_controller.when_apply do |process|
        @preprocess[:smoothing] = process
      end

      # ===============
      # = CALIBRATION =
      # ===============
      @calibration_controller = CalibrationFeatureController.new
      @calibration_controller.load_view(tab_book)
      @calibration_controller.when_selection_changed do
        @spectrum_controller.selected_points = @calibration_controller.selected_points
      end
      @calibration_controller.when_calibration_preview do |preview_points|
        @spectrum_controller.preview_points = preview_points
      end
      @calibration_controller.when_apply do |process|
        @preprocess[:calibration] = process
      end

      # ========
      # = PEAK =
      # ========
      @peak_controller = PeakFeatureController.new
      @peak_controller.load_view(tab_book)
      @peak_controller.when_peaks_found do |peaks|
        @spectrum_controller.selected_points = peaks
      end
      @peak_controller.when_import_to_calibration do |peaks|
        @calibration_controller.add_points(peaks)
      end

      # ============
      # = SPECTRUM =
      # ============
      @spectrum_controller = SpectrumController.new
      @spectrum_controller.load_view(vertical_frame)
      @spectrum_controller.when_select_point do |selected_points|
        @selection_controller.selected_value = selected_points.first
      end

    end

    private

    # View controllers
    attr_accessor :spectrum_controller

    # models
    attr_accessor :metadata, :average_spectrum

    # Views
    attr_accessor :menu_bar, :progress_dialog

    # Array of preprocessing steps. Each object should be Proc instance which
    # accepts two params intensity, mz array
    attr_accessor :preprocess

    # Help variables
    attr_accessor :mutex

    def calculate_average_spectrum
      spectrums_count = @metadata.spectrums.size

      # p "calculating average for #{spectrums_count} spectrums"
      @progress_dialog.run(spectrums_count) do |dialog|
        dictionary = Hash.new
        sum = spectrums_count

        # add all values
        @metadata.spectrums.each do |name, spectrum|

          intensity = spectrum.intensity_binary.data(@use_cache)
          mz = spectrum.mz_binary.data(@use_cache)

          # apply preprocessing steps
          @preprocess.each do |key, process|
            intensity, array = process.call(intensity, mz)
          end

          zipped_array = mz.zip(intensity)

          # create data array
          zipped_array.each do |key_value|
            key = key_value.first
            value = key_value.last

            dictionary[key] ||= 0
            dictionary[key] += value
          end

          dialog.done
        end

        # divide and make average
        dictionary.each { |key, value| value /= sum }

        # save average spectrum
        @average_spectrum = dictionary
        @spectrum_controller.points = @average_spectrum
      end
    end

    def open_file(filepath)

      # reset values
      @average_spectrum = nil
      @preprocess = Hash.new

      self.title = filepath.split("/").last
      @metadata = ImzML::Parser.new(filepath).metadata

      # open spectrum
      open_spectrum

      # set spectrum names
      @selection_controller.spectrum_names = @metadata.spectrums.keys

      # Clear the previous image
      @image_controller.clear_image
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

      # apply preprocessing steps
      @preprocess.each do |key, process|
        intensity, array = process.call(intensity, mz)
      end

      points = mz.zip(intensity).to_h

      # show points on spectrum
      @spectrum_controller.points = points

      # Show the chosen spectrum in image
      @image_controller.show_point(spectrum.position)
    end

    def show_image
      mz_value = @selection_controller.selected_value
      interval = @selection_controller.selected_interval

      return if interval.nil? && mz_value.nil?

      spectrums = @metadata.spectrums
      image_size = @metadata.scan_settings.values.first.image.max_pixel_count
      @progress_dialog.run(spectrums.size) do |dialog|
        values = Array.new
        # get the specific intensity value
        spectrums.each do |name, spectrum|
          values << intensity(spectrum, mz_value, interval)
          dialog.done
        end

        @image_controller.create_image(values, image_size.x, image_size.y)
      end
    end

    def intensity(spectrum, at, interval)

      cached = @use_cache

      # read whole the binary data
      mz_array = spectrum.mz_binary.data(cached)
      intensity_array = spectrum.intensity_binary.data(cached)

      # apply preprocessing steps
      @preprocess.each do |key, process|
        intensity_array, mz_array = process.call(intensity_array, mz_array)
      end

      default_from, default_to = mz_array.first, mz_array.first

      from = default_from
      to = default_to

      # find designated intensity
      if at
        from = at - interval
        from = default_from if from < 0
        to = at + interval
        to = default_to if to > mz_array.last
      end

      # find values in mz array
      low_value = mz_array.bsearch { |x| x >= from }
      low_index = mz_array.index(low_value)
      high_value = mz_array.bsearch { |x| x >= to }
      high_index = mz_array.index(high_value)

      # sum all values in subarray
      sum = intensity_array[low_index..high_index].inject{|sum, x| sum + x}

      sum
    end

    def tab_changed(sender, selector, event)

      # Reset values
      @spectrum_controller.selected_points = nil
      @spectrum_controller.preview_points = nil

      # find selected tab
      tab_index = event
      tab_title = sender.children[tab_index * 2].to_s
      case tab_title
      when SelectionFeatureController::TITLE
        @spectrum_controller.mode = :single_selection
        if @selection_controller.selected_value
          @spectrum_controller.selected_points = [@selection_controller.selected_value]
        end
        @spectrum_controller.selected_interval = @selection_controller.selected_interval
      when SmoothingFeatureController::TITLE
        @smoothing_controller.points = @spectrum_controller.points
        @spectrum_controller.preview_points = @smoothing_controller.preview_points
      when CalibrationFeatureController::TITLE
        @spectrum_controller.mode = :multi_selection
        @spectrum_controller.selected_points = @calibration_controller.selected_points
        @calibration_controller.points = @spectrum_controller.points
        @spectrum_controller.preview_points = @calibration_controller.preview_points
      when PeakFeatureController::TITLE
        @peak_controller.points = @spectrum_controller.points
        @spectrum_controller.selected_points = @peak_controller.peaks
      end

    end

    def window_size_changed(sender, selector, event)
      @spectrum_controller.needs_display
      @image_controller.need_display
    end

  end

end