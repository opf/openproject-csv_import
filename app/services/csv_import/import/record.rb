module CsvImport
  module Import
    class Record
      attr_accessor :data,
                    :wp_call,
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

      def import_id
        work_packages_map[data_id]
      end

      def wp_call=(call)
        work_packages_map[data_id] = call.result.id
        @wp_call = call
      end

      def work_package
        wp_call.result
      end
    end
  end
end
