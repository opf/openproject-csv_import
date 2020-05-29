# TODO: should be superfluous once aaj works on sql in 10.7
module OpenProject::CsvImport::Patches::JournalManagerPatch
  extend ActiveSupport::Concern

  included do
    def self.without_sending
      @without_sending = true
      @send_notification = false
      yield
    ensure
      @without_sending = false
      @send_notification = true
    end

    def self.reset_notification
      if @without_sending
        @send_notification = false
      else
        @send_notification = true
      end
    end
  end
end

