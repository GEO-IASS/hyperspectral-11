module Hyperspectral

  class CalibrationFeatureController

    TITLE = "Calibration"


    def load_view(superview)
      item = Fox::FXTabItem.new(superview, TITLE)

      # calibration tab (fold)
      horizontal_frame = Fox::FXHorizontalFrame.new(superview,
        :opts => Fox::LAYOUT_FILL_X | Fox::LAYOUT_SIDE_LEFT | Fox::FRAME_RAISED
      )

      @columns = %w{selected origin diff peptid}
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

      table.selBackColor = Fox::FXColor::DarkGrey
      @table = table

      table.connect(Fox::SEL_REPLACED) do |sender, sel, event|
        ## FIXME
        # item_position = event.fm
        # item = sender.getItem(item_position.row, item_position.col)
        #
        # # validate input data
        # case item_position.col
        # when CALIBRATION_COLUMN_SELECTED..CALIBRATION_COLUMN_DIFF
        #   item.text = item.text.to_f.to_s
        #
        #   recalculate_table_row(item_position.row, false)
        # end

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
        table.disableItem(table.numRows - 1, @columns.index("diff"))

        table.killSelection
      end

      # button removing row
      remove_row_button = Fox::FXButton.new(vertical_frame, "Remove row",
        :opts => Fox::LAYOUT_FILL_X | Fox::BUTTON_NORMAL
      )
      remove_row_button.connect(Fox::SEL_COMMAND) do |sender, sel, event|
        ## FIXME
        # # delete row
        # if table.numRows > 0
        #   selected_row = find_selected_table_row
        #   selected_row ||= table.numRows - 1
        #   table.removeRows(selected_row)
        #   @calibration_points.delete_at(selected_row)
        # end
        #
        # # deselect everything
        # table.killSelection
        #
        # @spectrum_canvas.update
      end

      Fox::FXVerticalSeparator.new(vertical_frame, :opts => Fox::LAYOUT_FILL_Y)

      combo_box = Fox::FXComboBox.new(vertical_frame, 1,
        :opts => Fox::LAYOUT_FILL_X | Fox::COMBOBOX_STATIC
      )
      combo_box.fillItems(%w{Linear})

      clear_button = Fox::FXButton.new(vertical_frame, "Clear",
        :opts => Fox::LAYOUT_FILL_X | Fox::BUTTON_NORMAL
      )
      clear_button.connect(Fox::SEL_COMMAND) do
        ## FIXME
        # @calibration = nil
        # @spectrum = @original_spectrum.dup
        # @spectrum_canvas.visible_spectrum = @spectrum.dup
        # @image_canvas.update
        #
        # ## FIXME remove
        # # @spectrum_canvas.reset_cache
        # @spectrum_canvas.update
        #
        # update_visible_spectrum
      end

      apply_button = Fox::FXButton.new(vertical_frame, "Apply",
        :opts => Fox::LAYOUT_FILL_X | Fox::BUTTON_NORMAL
      )
      apply_button.connect(Fox::SEL_COMMAND) do
        ## FIXME
        # calibrate
      end
    end

  end

end