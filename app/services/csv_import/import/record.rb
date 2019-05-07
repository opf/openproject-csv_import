module CsvImport
  module Import
    class Record
      attr_accessor :data,
                    :wp_call,
                    :relation_calls,
                    :attachments,
                    :work_packages_map

      def initialize(data)
        self.data = data
      end

      def timestamp
        data['timestamp']
      end

      def data_id
        data['id']
      end

      def import_id(id = data_id)
        work_packages_map[id]
      end

      def wp_call=(call)
        work_packages_map[data_id] = call.result.id
        @wp_call = call
      end

      def work_package
        wp_call.result
      end

      def invalid?
        calls.any?(&:failure?)
      end

      def failure_call
        call.detect(&:failure?)
      end

      def calls
        ([wp_call] + (relation_calls || [])).compact
      end

      def results
        calls.map(&:result).flatten + (attachments || [])
      end
    end
  end
end
