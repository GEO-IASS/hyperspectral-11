module Hyperspectral

  # Custom class for progress dialog.
  class ProgressDialog < Fox::FXProgressDialog

    include Callbacks

    # Custom init method which creates the enviroment for progress dialog.
    #
    # superview - parent view
    # title - progress title (default: "Please wait")
    # label - progress label (default: "Working ...")
    def initialize(superview, title = "Please wait", label = "Working ...")
      super(superview, title, label)
      self.total = 0

      # Simple mutex for mutual exclusion
      @mutex = Mutex.new

      # cancel dialog if it reach 100% progress
      self.connect(Fox::SEL_UPDATE) do |sender, selector, event|
        sender.handle(sender, Fox::MKUINT(Fox::FXDialogBox::ID_ACCEPT, Fox::SEL_COMMAND), nil) if sender.progress >= sender.total
      end

    end

    # Method which runs work on background thread to not block the UI.
    #
    # amount - total amount of work without unit
    def run(amount)
      # reset the progress first
      @mutex.synchronize { self.total, self.progress = amount, 0 }
      Thread.new { yield(self) }
      # show the dialog
      self.execute(Fox::PLACEMENT_OWNER)
    end

    # Add custom amount to the progress dialog
    #
    # amount - a amount of work which to add (default: 1)
    def add(amount = 1)
      @mutex.synchronize { self.total += amount }
    end

    # Mark amount of work as completed
    #
    # amount - a amount of work which is done (default: 1)
    def done(amount = 1)
      @mutex.synchronize { self.increment amount }
    end


  end

end