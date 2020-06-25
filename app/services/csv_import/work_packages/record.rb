module CsvImport
  module WorkPackages
    class Record
      attr_accessor :data,
                    :line,
                    :work_package_call,
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

      def work_package_call=(call)
        work_packages_map[data_id] = call.result&.id

        add_errors(call)

        @work_package_call = call
      end

      def attachment_calls=(calls)
        add_errors(calls)

        @attachment_calls = calls
      end

      def relation_calls=(calls)
        add_errors(calls)

        @relation_calls = calls
      end

      def work_package
        work_package_call&.result || (import_id && WorkPackage.find_by(id: import_id))
      end

      def attachments
        attachment_calls&.map(&:result) || (import_ids[:attachments] && WorkPackage.find_by(id: import_ids[:attachments]))
      end

      def invalid?
        error_messages.any?
      end

      def import_ids
        @import_ids ||= {
          work_package: nil,
          attachments: [],
          relations: []
        }
      end

      def error_messages
        @error_messages ||= []
      end

      def add_errors(calls)
        @error_messages ||= []

        Array(calls).select(&:failure?).each do |call|
          @error_messages += call.errors.full_messages
        end
      end

      def work_package_imported!
        ar_record_imported!(:work_package, false)
      end

      def attachments_imported!
        ar_record_imported!(:attachments, true)
      end

      def relations_imported!
        ar_record_imported!(:relations, true)
      end

      def ar_record_imported!(name, multiple)
        calls_name = if multiple
                       "#{name.to_s.singularize}_calls"
                     else
                       "#{name.to_s.singularize}_call"
                     end

        calls = Array(send(calls_name.to_sym))

        import_ids[name] = if multiple
                             calls.compact.map { |call| call.result&.id }
                           else
                             calls.first&.result&.id
                           end

        # Free up memory
        instance_variable_set(:"@#{calls_name}", nil)
      end
    end
  end
end
