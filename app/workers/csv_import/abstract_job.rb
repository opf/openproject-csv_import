module CsvImport
  class AbstractJob < ApplicationJob
    def perform(attachment)
      cleanup_csv_file(attachment)
    end

    private

    attr_accessor :user_id,
                  :attachment_id

    def user
      User.find(user_id)
    end

    def attachment_path(attachment)
      if attachment.file.is_a?(FogFileUploader)
        attachment.diskfile.path
      else
        attachment.file.path
      end
    end

    def cleanup_csv_file(attachment)
      attachment.destroy
    end
  end
end
