module CsvImport
  class WorkPackageJob < AbstractJob
    def perform(user, attachment, validate = true)
      call = CsvImport::WorkPackageService
             .new(user, validate)
             .call(attachment_path(attachment), attachment.content_type)

      if call.success?
        CsvImport::Mailer.success(user, call.result).deliver_now
      else
        CsvImport::Mailer.failure(user, call.errors).deliver_now
        delayed_job_status_fail
      end

      super(attachment)
    end

    def status_reference
      attachment
    end

    def delayed_job_status_fail
      raise UnsuccessfulImport
    end

    def attachment
      arguments[1]
    end

    class UnsuccessfulImport < StandardError; end
  end
end
