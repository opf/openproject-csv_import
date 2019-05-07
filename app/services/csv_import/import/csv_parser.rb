module CsvImport
  module Import
    class CsvParser
      class << self
        def parse(work_packages_path)
          data = Hash.new do |h, k|
            h[k] = []
          end

          CSV.foreach(work_packages_path, headers: true) do |wp_data|
            attributes = normalize_attributes(wp_data.to_h)
            attributes['timestamp'] = DateTime.parse(attributes['timestamp'])
            attributes['attachments'] = parse_multi_values(attributes['attachments'])
            attributes['related to'] = parse_multi_values(attributes['related to'])

            data[attributes['id'].strip] << attributes
          end

          data.each_key do |key|
            data[key] = data[key].sort_by { |r| r['timestamp'] }
          end

          data
        end

        private

        def normalize_attributes(csv_hash)
          csv_hash
            .map do |key, value|
            [wp_attribute(key.downcase.strip), value]
          end
            .to_h
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
