module CsvImport
  class WorkPackageService
    def initialize(user)
      self.user = user
    end

    def call(work_packages_path)
      BaseMailer.with_deliveries(false) do
        import(work_packages_path)
      end
    end

    private

    attr_accessor :user

    def import(work_packages_path)
      records = parse(work_packages_path)

      process(records)

      if records.valid?
        success_result(records)
      else
        cleanup_on_failure(records)

        failure_result(records)
      end
    end

    def process(records)
      process_work_packages(records)

      if records.valid?
        process_relations(records)
      end
    end

    def parse(work_packages_path)
      ::CsvImport::WorkPackages::CsvParser.parse(work_packages_path)
    end

    def process_work_packages(records)
      records.each_with_break do |record|
        import_work_package(record) unless record.invalid?
        fix_timestamp(record) unless record.invalid?
        record.invalid?
      end
    end

    def process_relations(records)
      records.each_last(&method(:import_relations))
    end

    def cleanup_on_failure(records)
      records.results.select { |r| r.is_a?(WorkPackage) }.each do |work_package|
        begin
          ::WorkPackages::DeleteService
            .new(user: user, model: work_package)
            .call
        rescue ActiveRecord::StaleObjectError
          # nothing to do as it has apparently been destroyed already
        end
      end
    end

    def success_result(records)
      objects_by_type = records.results.group_by(&:class)
      result = OpenStruct.new(work_packages: objects_by_type[WorkPackage],
                              relations: objects_by_type[Relation],
                              attachments: objects_by_type[Attachment],
                              work_packages_map: records.work_packages_map)

      ServiceResult.new(success: true, result: result)
    end

    def failure_result(records)
      errors = records.invalids.map do |i|
                 CsvImport::WorkPackages::Error.new(i.line, i.failure_call.errors.full_messages)
               end

      ServiceResult.new(success: false,
                        result: records.results,
                        errors: errors)
    end

    def fix_timestamp(record)
      ::CsvImport::WorkPackages::TimestampFixer.fix(record)
    end

    def import_work_package(record)
      ::CsvImport::WorkPackages::WorkPackageImporter.import(record)
    end

    def import_relations(record)
      ::CsvImport::WorkPackages::RelationImporter.import(record)
    end
  end
end