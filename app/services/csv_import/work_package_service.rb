module CsvImport
  class WorkPackageService
    def initialize(user, validate = true)
      self.user = user
      self.validate = validate
    end

    def call(work_packages_path, content_type)
      BaseMailer.with_deliveries(false) do
        JournalManager.without_sending do
          with_settings do
            import(work_packages_path, content_type)
          end
        end
      end
    end

    private

    attr_accessor :user,
                  :validate

    def import(work_packages_path, content_type)
      records = parse(work_packages_path, content_type)

      log("Parsed data for #{records.records.length} work packages.")

      process(records)

      if records.valid?
        success_result(records)
      else
        cleanup_on_failure(records)

        failure_result(records)
      end
    rescue StandardError => e
      cleanup_on_failure(records) if defined?(records) && records

      raise e
    end

    def process(records)
      process_work_packages(records)

      if records.valid?
        process_relations(records)
      end
    end

    def parse(work_packages_path, content_type)
      klass = ::Constants::CsvImport::ParserRegistry.for(content_type)

      unless klass
        raise "No parser registered for #{content_type}"
      end

      klass.constantize.parse(work_packages_path)
    end

    def process_work_packages(records)
      records.each_with_break do |record|
        log("Importing data for record with id: #{record.data_id} - timestamp: #{record.timestamp}.")
        import_work_package(record) unless record.invalid?
        fix_timestamp(record) unless record.invalid?
        record.work_package_imported!
        record.attachments_imported!

        if record.invalid?
          message = <<~MESSAGE
            Record with id: #{record.data_id} - timestamp: #{record.timestamp}: Is invalid.

            #{record.error_messages}
          MESSAGE

          log(message)
        else
          log("Record with id: #{record.data_id} - timestamp: #{record.timestamp}: Is valid.")
        end

        # This leads to other records of the same work package being skipped if this record is invalid
        record.invalid?
      end
    end

    def process_relations(records)
      records.each_last(&method(:import_relations))
    end

    def cleanup_on_failure(records)
      log("Cleaning up work packages")
      WorkPackage.where(id: records.import_ids.work_packages).in_batches.each do |work_packages|
        work_packages.each do |work_package|
          ::WorkPackages::DeleteService
            .new(user: user, model: work_package)
            .call
        rescue ActiveRecord::StaleObjectError
          # nothing to do as it has apparently been destroyed already
        end
      end
    end

    def success_result(records)
      ServiceResult.new(success: true, result: records.import_ids)
    end

    def failure_result(records)
      errors = records.invalids.map do |i|
                 CsvImport::WorkPackages::Error.new(i.data_id, i.timestamp, i.error_messages)
               end

      ServiceResult.new(success: false,
                        result: nil,
                        errors: errors)
    end

    def fix_timestamp(record)
      ::CsvImport::WorkPackages::TimestampFixer.fix(record)
    end

    def import_work_package(record)
      ::CsvImport::WorkPackages::WorkPackageImporter.import(record, validate)
    end

    def import_relations(record)
      ::CsvImport::WorkPackages::RelationImporter.import(record)

      record.relations_imported!
    end

    def with_settings
      settings_before = Setting.send(:cached_settings)
      RequestStore.store[:cached_settings] = settings_before.merge("work_package_startdate_is_adddate" => "false",
                                                                   "notified_events" => YAML.dump([]))
      RequestStore.store[:settings_updated_on] = DateTime.now + 100.days

      yield
    ensure
      Setting.clear_cache
    end

    def log(message)
      OpenProject::CsvImport::Logger.log(message)
    end
  end
end