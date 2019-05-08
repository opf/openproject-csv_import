module CsvImport
  class ImportService
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
        ServiceResult.new(success: true, result: records.results)
      else
        cleanup_on_failure(records)

        records.first_invalid.failure_call
      end
    end

    def process(records)
      process_work_packages(records)

      if records.valid?
        process_relations(records)
      end
    end

    def parse(work_packages_path)
      ::CsvImport::Import::CsvParser.parse(work_packages_path)
    end

    def process_work_packages(records)
      records.each do |record|
        record.wp_call = import_work_package(record)

        fix_timestamp(record)
      end
    end

    def process_relations(records)
      records.each_last(&method(:import_relations))
    end

    def cleanup_on_failure(records)
      records.results.select { |r| r.is_a?(WorkPackage) }.each do |work_package|
        begin
          WorkPackages::DestroyService
          .new(user: user, work_package: work_package)
          .call
        rescue ActiveRecord::StaleObjectError
          # nothing to do as it has apparently been destroyed already
        end
      end
    end

    def fix_timestamp(record)
      ::CsvImport::Import::TimestampFixer.fix(record)
    end

    def import_work_package(record)
      ::CsvImport::Import::WorkPackageImporter.import(record)
    end

    def import_relations(record)
      ::CsvImport::Import::RelationImporter.import(record)
    end
  end
end