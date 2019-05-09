module CsvImport
  module Import
    class CsvParser
      extend ServiceErrorMixin

      class << self
        def parse(work_packages_path)
          records = ::CsvImport::Import::Records.new

          line = 0

          CSV.foreach(work_packages_path, headers: true) do |wp_data|
            line += 1

            parse_line(records, wp_data, line)
          end

          records.sort

          records
        end

        private

        def parse_line(records, wp_data, line)
          attributes = normalize_attributes(wp_data.to_h)

          # Jump empty lines
          return if attributes.compact.empty?

          record = ::CsvImport::Import::Record.new(line, attributes)
          records.add(record)

          coerce_attributes(record)
        end

        def normalize_attributes(csv_hash)
          csv_hash
            .map do |key, value|
              [wp_attribute(key.downcase.strip), value]
            end
            .to_h
        end

        def coerce_attributes(record)
          record.data['timestamp'] = DateTime.iso8601(record.data['timestamp'])
          record.data['attachments'] = parse_multi_values(record.data['attachments'])
          record.data['related to'] = parse_multi_values(record.data['related to'])
        rescue ArgumentError
          record.wp_call = failure_result("'#{record.data['timestamp']}' is not an ISO 8601 compatible timestamp.")
        end

        def wp_attribute(key)
          wp_attribute_map[key] || key
        end

        def wp_attribute_map
          @wp_attribute_map ||= begin
            associations = WorkPackage
                             .reflect_on_all_associations
                             .map { |a| [a.name.to_s, a.foreign_key] }
            cfs = WorkPackageCustomField
                    .pluck(:id)
                    .map { |id| ["cf #{id}", "custom_field_#{id}"] }

            statics = [['version', 'fixed_version_id']]

            map = (associations + cfs + statics).to_h

            map.delete('attachments')

            map
          end
        end

        def parse_multi_values(value)
          (value || '').split(';').map(&:strip)
        end
      end
    end
  end
end
