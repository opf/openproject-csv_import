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
      create_mapping_attachment(user, result.work_packages_map)

      CsvImport::Mailer.success(user, result).deliver_now
    end

    def send_error(user, errors)
      create_failure_attachment(user, errors)

      CsvImport::Mailer.failure(user, errors).deliver_now
    end

    def send_critical_error(user, error)
      message = <<~MSG
        #{error.message}

        #{error.backtrace[0..20].join("\n")}
      MSG

      create_critical_attachment(user, message)

      CsvImport::Mailer.critical(user, message).deliver_now
    end

    def create_mapping_attachment(user, mapping)
      create_result_attachment(user, { mappings: mapping }.to_json)
    end

    def create_failure_attachment(user, failures)
      failure_map = failures.map do |failure|
        {
          id: failure.id,
          timestamp: failure.timestamp,
          messages: failure.messages
        }
      end

      create_result_attachment(user, { errors: failure_map }.to_json)
    end

    def create_critical_attachment(user, errors)
      create_result_attachment(user, { fatal: errors }.to_json)
    end

    def set_current_result_id(attachment)
      Setting.plugin_openproject_csv_import = Setting.plugin_openproject_csv_import.merge('current_import_result_id' => attachment.id)
    end

    def create_result_attachment(user, json)
      file = OpenProject::Files.create_uploaded_file name: "csv_import_result.json",
                                                     content_type: 'application/json',
                                                     content: json

      attachment = Attachment.create! file: file,
                                      author: user

      set_current_result_id(attachment)
    end

    class UnsuccessfulImport < StandardError; end
  end
end
