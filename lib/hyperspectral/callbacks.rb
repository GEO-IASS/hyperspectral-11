module Callbacks

  # Looks for method in @callbacks attribute and assign a block of a code to it.
  #
  # m - Symobol name of called unknown method
  # args - arguments which was handled to the method
  # block - a block send to the unknown method
  def method_missing(m, *args, &block)
    (@callbacks ||= Hash.new)[m] = block
  end

  # Checks for callback existance.
  #
  # name - name of the callback methods to look for
  # Returns yes if methods exists in @callbacks attribute.
  def callback_exist?(name)
    @callbacks && name && @callbacks.key?(name)
  end

  # Method calling the callback block code.
  #
  # name - name of the callback to call
  # args - arguments for the callback to use
  def callback(name, *args)
    @callbacks[name].call(*args) if callback_exist?(name)
  end

end
