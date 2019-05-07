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

      process_work_packages(records)

      records.first_failure_or do
        process_relations(records)

        records.first_failure_or do
          ServiceResult.new(success: true, result: records.results)
        end
      end
    end

    def parse(work_packages_path)
      ::CsvImport::Import::CsvParser.parse(work_packages_path)
    end

    def process_work_packages(records)
      records.each do |record|
        record.wp_call = import_work_package(record)

        ::CsvImport::Import::TimestampFixer.fix(record)
      end
    end

    def process_relations(records)
      records.each_last(&method(:import_relations))
    end

    def import_work_package(record)
      ::CsvImport::Import::WorkPackageImporter.import(record)
    end

    def import_relations(record)
      ::CsvImport::Import::RelationImporter.import(record)
    end
  end
end