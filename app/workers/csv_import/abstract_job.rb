module CsvImport
  class AbstractJob < ApplicationJob
    def initialize(user_id:, attachment_id:)
      self.user_id = user_id
      self.attachment_id = attachment_id
    end

    def perform
      cleanup_csv_file
    end

    private

    attr_accessor :user_id,
                  :attachment_id

    def user
      User.find(user_id)
    end

    def attachment_path
      attachment = Attachment.find(attachment_id)

      if attachment.file.is_a?(FogFileUploader)
        attachment.diskfile.path
      else
        attachment.file.path
      end
    end

    def cleanup_csv_file
      Attachment.find(attachment_id).destroy
    end
  end
end
