module CsvImport
  class ImportService
    def initialize(user)
      self.user = user
    end

    def call(work_packages_path)
      reset_work_packages_map

      BaseMailer.with_deliveries(false) do
        process_csv(work_packages_path)
      end
    end

    private

    attr_accessor :user

    def process_csv(work_packages_path)
      result = ServiceResult.new success: true

      CSV.foreach(work_packages_path, headers: true) do |wp_data|
        attributes = normalize_attributes(wp_data.to_h)

        call = import_work_package(attributes)

        fix_timestamps(attributes['timestamp'], call.result)
        result.add_dependent!(call)
      end

      result
    end

    def import_work_package(attributes)
      with_memorized_work_package(attributes['id']) do |work_package_id|
        if work_package_id
          update_work_package(work_package_id, attributes)
        else
          create_work_package(attributes)
        end
      end
    end

    def create_work_package(attributes)
      WorkPackages::CreateService
        .new(user: find_user(attributes))
        .call(attributes: work_package_attributes(attributes))
    end

    def update_work_package(id, attributes)
      work_package = WorkPackage.find(id)

      WorkPackages::UpdateService
        .new(user: find_user(attributes),
             work_package: work_package)
        .call(attributes: work_package_attributes(attributes))
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

    def work_package_attributes(attributes)
      attributes.except('timestamp', 'id')
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
        .update_columns(created_at: [work_package.created_at, timestamp].min,
                        updated_at: timestamp)
    end

    def fix_journal_timestamp(timestamp, work_package)
      work_package
        .journals
        .last
        .update_columns(created_at: timestamp)
    end

    def find_user(attributes)
      User.find(attributes['user'])
    end

    def with_memorized_work_package(id)
      work_package_id = work_packages_map[id]

      call = yield(work_package_id)

      work_packages_map[id] = call.result.id

      call
    end

    def work_packages_map
      @work_packages_map ||= {}
    end

    def reset_work_packages_map
      @work_packages_map = {}
    end
  end
end