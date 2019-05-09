module CsvImport
  class ImportJob < ApplicationJob
    def initialize(user_id:, work_package_attachment_id:)
      self.user_id = user_id
      self.work_package_attachment_id = work_package_attachment_id
    end

    def perform
      call = CsvImport::ImportService
        .new(user)
        .call(work_package_path)

      if call.success?
        CsvImport::Mailer.success(user, call.result).deliver_now
      else
        CsvImport::Mailer.failure(user, call.errors).deliver_now
      end

      cleanup_csv_file
    end

    private

    attr_accessor :user_id,
                  :work_package_attachment_id

    def user
      User.find(user_id)
    end

    def work_package_path
      attachment = Attachment.find(work_package_attachment_id)

      if attachment.file.is_a?(FogFileUploader)
        attachment.diskfile.path
      else
        attachment.file.path
      end
    end

    def cleanup_csv_file
      Attachment.find(work_package_attachment_id).destroy
    end
  end
end
