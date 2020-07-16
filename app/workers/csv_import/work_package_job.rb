module CsvImport
  class WorkPackageJob < AbstractJob
    def perform(user, attachment, validate = true)
      call = CsvImport::WorkPackageService
             .new(user, validate)
             .call(attachment_path(attachment), attachment.content_type)

      if call.success?
        send_success(user, call.result)
      else
        send_error(user, call.errors)
        delayed_job_status_fail
      end

      super(attachment)
    rescue UnsuccessfulImport => e
      # nothing to do but we do not want to treat it as an unspecific error
      raise e
    rescue StandardError => e
      send_critical_error(user, e)

      delayed_job_status_fail
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

    def send_success(user, result)
      CsvImport::Mailer.success(user, result).deliver_now
    end

    def send_error(user, errors)
      CsvImport::Mailer.failure(user, errors).deliver_now
    end

    def send_critical_error(user, error)
      message = <<~MSG
        #{error.message}

        #{error.backtrace}
      MSG

      CsvImport::Mailer.critical(user, message).deliver_now
    end

    class UnsuccessfulImport < StandardError; end
  end
end
