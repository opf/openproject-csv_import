module CsvImport
  module Import
    class Records
      def add(record)
        record.work_packages_map = work_packages_map

        records[record.data_id] << record
      end

      def records
        @records ||= Hash.new do |h, k|
          h[k] = []
        end
      end

      def sort
        records.each_key do |key|
          records[key] = records[key].sort_by(&:timestamp)
        end
      end

      def each
        records.each do |_, rs|
          rs.each do |r|
            yield r
          end
        end
      end

      def each_last
        records.each do |_, rs|
          yield rs.last
        end
      end

      def work_packages_map
        @work_packages_map ||= {}
      end

      def first_invalid
        invalid = nil

        each do |record|
          if record.invalid?
            invalid = record
          end
        end

        invalid
      end

      def first_failure_or
        if (invalid = first_invalid)
          invalid.failure_call
        else
          yield
        end
      end

      def results
        results = []

        each do |record|
          results += record.results
        end

        results
      end
    end
  end
end
