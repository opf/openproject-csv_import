module CsvImport
  module Import
    class Record
      attr_accessor :data,
                    :line,
                    :wp_call,
                    :relation_calls,
                    :attachment_calls,
                    :work_packages_map

      def initialize(line, data)
        self.line = line
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
        work_packages_map[data_id] = call.result&.id
        @wp_call = call
      end

      def work_package
        wp_call&.result
      end

      def attachments
        attachment_calls&.map(&:result)
      end

      def invalid?
        calls.any?(&:failure?)
      end

      def failure_call
        calls.detect(&:failure?)
      end

      def calls
        ([wp_call] + (attachment_calls || []) + (relation_calls || [])).compact
      end

      def results
        calls.map(&:result).flatten
      end
    end
  end
end
