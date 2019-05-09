module CsvImport
  module WorkPackages
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

      def each_with_break
        records.each do |_, rs|
          rs.each do |r|
            skip = yield r
            break if skip
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
            break
          end
        end

        invalid
      end

      def map
        results = []

        each do |record|
          results << yield(record)
        end

        results
      end

      def select
        results = []

        each do |record|
          results << record if yield(record)
        end

        results
      end

      def invalids
        select(&:invalid?)
      end

      def valid?
        first_invalid.nil?
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
