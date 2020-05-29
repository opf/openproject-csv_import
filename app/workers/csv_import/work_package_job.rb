module CsvImport
  class WorkPackageJob < AbstractJob
    def perform(user, attachment)
      call = CsvImport::WorkPackageService
             .new(user)
             .call(attachment_path(attachment), attachment.content_type)

      if call.success?
        CsvImport::Mailer.success(user, call.result).deliver_now
      else
        CsvImport::Mailer.failure(user, call.errors).deliver_now
      end

      super(attachment)
    end

    def status_reference
      arguments.last # the attachment
    end
  end
end
