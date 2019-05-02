module CsvImport
  class ImportService
    def initialize(user)
      self.user = user
    end

    def call(work_packages_path)
      result = ServiceResult.new success: true

      CSV.foreach(work_packages_path, headers: true) do |wp_data|
        attributes = normalize_attributes(wp_data.to_h)

        call = import_work_package(attributes)
        fix_timestamps(attributes['timestamp'], call.result)
        result.add_dependent!(call)
      end

      result
    end

    private

    attr_accessor :user

    def import_work_package(data)
      attributes = data.except('timestamp', 'id')

      author = User.find(attributes.delete('author_id'))

      WorkPackages::CreateService
        .new(user: author)
        .call(attributes: attributes)
    end

    def fix_timestamps(timestamp, work_package)
      parsed_time = DateTime.parse(timestamp)

      fix_work_package_timestamp(parsed_time, work_package)
      fix_journal_timestamp(parsed_time, work_package)
    end

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

        (associations + cfs).to_h
      end
    end

    def fix_work_package_timestamp(timestamp, work_package)
      work_package
        .update_columns(created_at: timestamp,
                        updated_at: timestamp)
    end

    def fix_journal_timestamp(timestamp, work_package)
      work_package
        .journals
        .last
        .update_columns(created_at: timestamp)
    end
  end
end