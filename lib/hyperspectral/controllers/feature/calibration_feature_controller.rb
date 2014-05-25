module Hyperspectral

  class CalibrationFeatureController

    include Callbacks

    TITLE = "Calibration"

    COLUMN_SELECTED = "selected"
    COLUMN_ORIGIN = "origin"
    COLUMN_DIFF = "diff"
    COLUMN_NAME = "name"

    CALIBRATION_TYPE_LINEAR = "Linear"
    CALIBRATION_TYPE_QUADRATIC = "Quadratic"

    # Points selected for calibration
    attr_accessor :selected_points

    # Spectrum points
    attr_accessor :points

    # Last calibration preview points
    attr_accessor :preview_points

    # Currently selected calibration points which takes right from the
    # table
    #
    # Returns array of currently selected points
    def selected_points
      points = Array.new
      @table.each_row do |row|
        # FIXME debug
        selected_column_index = @columns.index(COLUMN_SELECTED)
        points << row[selected_column_index].text.to_f
      end

      points
    end

    # Method which add newly selected point at the end of the table
    #
    # points - array with new m/z points
    def add_points(points)
      points.each do |point|
        append_row(point.round(3))
      end
    end

    # Perform calibration based on selection and input calibration points.
    # Recalculated points are stored in @preview_points
    #
    # mz_points - array of mz values
    # x_values - array of origin values
    # y_values - array of diff values calculated origin - selected
    # Returns array of calibrated values
    def calibrate(mz_points, x_values, y_values)

      case @combo_box.text
      when CALIBRATION_TYPE_LINEAR

        array = mz_points.map { |key, value| [linear_calibration(key, x_values, y_values), value] }
        @preview_points = Hash[*array.flatten]
      when CALIBRATION_TYPE_QUADRATIC
        coefs = polynomial(x_values, y_values, 2)
        array = mz_points.map { |key, value| [polynomial_value(key, coefs), value]}
      end
    end

    def load_view(superview)
      item = Fox::FXTabItem.new(superview, TITLE)

      # calibration tab (fold)
      horizontal_frame = Fox::FXHorizontalFrame.new(superview,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_SIDE_LEFT | Fox::FRAME_RAISED
      )

      @columns = [COLUMN_SELECTED, COLUMN_ORIGIN, COLUMN_DIFF, COLUMN_NAME]
      table = Fox::FXTable.new(horizontal_frame,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_FILL_Y |
        Fox::TABLE_NO_COLSELECT
      )
      table.horizontalGridShown = true
      table.verticalGridShown = true
      table.setTableSize(0, 4)
      table.rowRenumbering = true
      table.rowHeaderMode = Fox::LAYOUT_FIX_WIDTH
      table.rowHeaderWidth = 30

      @columns.each_with_index do |col, i|
        table.setColumnText(i, col)
        table.setColumnWidth(i, 80)
      end

      @calibration_process = Proc.new do |intensity, mz|
        x_values = Array.new # origin
        y_values = Array.new # diff
        self.selected_points.each_with_index do |x, i|
          origin_item = @table.getItemText(i, @columns.index(COLUMN_ORIGIN))
          selected_item = @table.getItemText(i, @columns.index(COLUMN_SELECTED))
          x_values << origin_item.to_f
          y_values << (origin_item.to_f - selected_item.to_f)
        end

        mz_calibrated = calibrate(mz, x_values, y_values)
        [intensity, mz_calibrated]
      end

      table.selBackColor = Fox::FXColor::DarkGrey
      @table = table

      table.connect(Fox::SEL_REPLACED) do |sender, selector, event|
        item_position = event.fm
        item = sender.getItem(item_position.row, item_position.col)

        # validate input data
        case item_position.col
        when @columns.index(COLUMN_SELECTED)..@columns.index(COLUMN_DIFF)
          item.text = item.text.to_f.to_s

          recalculate_table_row(item_position.row)
        end

        callback(:when_selection_changed)
      end

      vertical_frame = Fox::FXVerticalFrame.new(horizontal_frame,
        :opts => Fox::LAYOUT_FILL_Y | Fox::LAYOUT_FIX_WIDTH |
          Fox::LAYOUT_SIDE_RIGHT,
        :width => 100
      )

      # button adding row
      add_row_button = Fox::FXButton.new(vertical_frame, "Add row",
        :opts => Fox::LAYOUT_FILL_X | Fox::BUTTON_NORMAL
      )
      add_row_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        table.appendRows
        # init zero column value, last leave empty
        (table.numColumns - 1).times do |col|
          table.setItemText(table.numRows - 1, col, "0.0")
        end

        # disable editing of diff column
        table.disableItem(table.numRows - 1, @columns.index(COLUMN_DIFF))

        table.killSelection

        callback(:when_selection_changed)
      end

      # button removing row
      remove_row_button = Fox::FXButton.new(vertical_frame, "Remove row",
        :opts => Fox::LAYOUT_FILL_X | Fox::BUTTON_NORMAL
      )
      remove_row_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        next unless @table.numRows > 0
        next unless selected_row

        # delete row
        table.removeRows(selected_row)

        # deselect everything
        table.killSelection

        callback(:when_selection_changed)
      end

      Fox::FXVerticalSeparator.new(vertical_frame, :opts => Fox::LAYOUT_FILL_Y)

      @combo_box = Fox::FXComboBox.new(vertical_frame, 1,
        :opts => Fox::LAYOUT_FILL_X | Fox::COMBOBOX_STATIC
      )
      @combo_box.fillItems([CALIBRATION_TYPE_LINEAR, CALIBRATION_TYPE_QUADRATIC])

      preview_button = Fox::FXButton.new(vertical_frame, "Preview",
        :opts => Fox::LAYOUT_FILL_X | Fox::BUTTON_NORMAL
      )
      preview_button.connect(Fox::SEL_COMMAND) do
        intensity, mz_calibrated = @calibration_process.call(nil, points)
        @preview_points = Hash[*mz_calibrated.flatten]
        callback(:when_calibration_preview, @preview_points)
      end

      apply_button = Fox::FXButton.new(vertical_frame, "Apply to All",
        :opts => Fox::LAYOUT_FILL_X | Fox::BUTTON_NORMAL
      )
      apply_button.connect(Fox::SEL_COMMAND) do
        callback(:when_apply, @calibration_process)
      end
    end

    private

    # Method appending new row to the table with default selected value
    #
    # value - default value column selected after addition
    def append_row(value = 0.0)
      @table.appendRows

      # first item set to desired default value
      @table.setItemText(@table.numRows - 1, 0, value.to_s)
      @table.setItemText(@table.numRows - 1, 1, value.to_s)
      @table.setItemText(@table.numRows - 1, 2, 0.to_s)

      # disable editing of diff column
      @table.disableItem(@table.numRows - 1, @columns.index(COLUMN_DIFF))
      @table.killSelection
    end

    # Detects which row is currently selected in the table
    def selected_row

      row_selected = nil
      return unless @table.anythingSelected?
      @table.numRows.times do |row_number|
        if @table.rowSelected?(row_number)
          row_selected = row_number
          break
        end
      end

      row_selected
    end

    # Recalculation of the table rows, used after any change
    #
    # row - number of row to recalculate
    def recalculate_table_row(row)

      # recalculate table
      selected_item = @table.getItem(row, @columns.index(COLUMN_SELECTED))
      origin_item = @table.getItem(row, @columns.index(COLUMN_ORIGIN))

      diff = selected_item.text.to_f - origin_item.text.to_f
      @table.setItemText(row, @columns.index(COLUMN_DIFF), diff.round(3).to_s, false)
    end

    # Linear regression calculations
    #
    # x - value for which find new Y
    # x_values - x values
    # y_values - y values
    # Returns new value for x calculated with linear regression
    def linear_calibration(x, x_values, y_values)
      # prepare values for linear calibration
      xy_sum = x_values.zip(y_values).map { |x, y| x * y }.reduce(:+)
      x_sum = x_values.reduce(:+)
      y_sum = y_values.reduce(:+)
      xx_sum = x_values.map{|x| x*x}.reduce(:+)
      x_sumsum = x_sum*x_sum
      n = x_values.size

      a = (n*xy_sum - x_sum * y_sum) / (n*xx_sum - x_sumsum)
      b = (xx_sum*y_sum - x_sum*xy_sum)  / (n*xx_sum - x_sumsum)

      error = a * x + b
      x + error
    end

    # Polynom coefficients calcutaion for specific degree
    #
    # x - x values
    # y - y values
    # degree - degree of the result polynom
    # Returns array of polynom coefficients [x^0, x^1, ..., x^degree]
    def polynomial(x, y, degree)
      x_data = x.map { |xi| (0..degree).map { |pow| (xi**pow).to_f } }

      matrix_x = Matrix[*x_data]
      matrix_y = Matrix.column_vector(y)

      ((matrix_x.t * matrix_x).inv * matrix_x.t * matrix_y).transpose.to_a[0]
    end

    # New x value calculation based on the calculated coefficients and for x
    #
    # x - for which value we want to calculate the new y value
    # coefs - polynom coefficients
    # Returns value Y calculated with polynomial regression
    def polynomial_value(x, coefs)
      array = (0..(coefs.size - 1)).to_a
      error = array.inject { |sum, i| sum + coefs[i] * x ** i } + coefs.first

      x + error
    end

  end

end