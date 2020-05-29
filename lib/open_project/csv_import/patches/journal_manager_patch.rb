# TODO: should be superfluous once aaj works on sql in 10.7
module OpenProject::CsvImport::Patches::JournalManagerPatch
  extend ActiveSupport::Concern

  included do
    def self.without_sending
      @without_sending = true
      self.send_notification = false
      yield
    ensure
      @without_sending = false
      self.send_notification = true
    end

    def self.reset_notification
      if @without_sending
        self.send_notification = false
      else
        self.send_notification = true
      end
    end
  end
end

