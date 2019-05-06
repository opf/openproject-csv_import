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

        fix_timestamps(attributes, call.result)
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
      work_package = WorkPackage.new

      result = {}
      result[:attachments] = attach(work_package, attributes)

      call = WorkPackages::CreateService
             .new(user: find_user(attributes))
             .call(attributes: work_package_attributes(attributes),
                   work_package: work_package)

      result[:work_package] = call.result

      ServiceResult.new success: call.success?,
                        result: result
    end

    def update_work_package(id, attributes)
      work_package = WorkPackage.find(id)

      result = {}
      result[:attachments] = attach(work_package, attributes)

      call = WorkPackages::UpdateService
             .new(user: find_user(attributes),
                  work_package: work_package)
             .call(attributes: work_package_attributes(attributes))

      result[:work_package] = call.result

      ServiceResult.new success: call.success?,
                        result: result
    end

    def fix_timestamps(attributes, result)
      parsed_time = DateTime.parse(attributes['timestamp'])

      work_package = result[:work_package]

      fix_work_package_timestamp(parsed_time, work_package)
      fix_work_package_journal_timestamp(parsed_time, work_package)

      attachments = result[:attachments]

      fix_attachment_timestamp(parsed_time, attachments)
      fix_attachment_journal_timestamp(parsed_time, attachments)
    end

    def attach(work_package, attributes)
      names = attachment_names(attributes)

      return [] if names.empty?

      attachments_to_delete = work_package.attachments.select { |a| !names.include?(a.filename) }
      attachments_to_delete.each(&:destroy)
      work_package.attachments.reload if attachments_to_delete.any?

      attachments_to_create = names - work_package.attachments.map(&:filename)

      attachments = Attachment
                    .where(container_id: -1, container_type: nil)
                    .where(file: attachments_to_create)

      attachments.map do |attachment|
        file = attachment.file

        work_package.attachments.build(file: file,
                                       author: find_user(attributes))
      end
    end

    def normalize_attributes(csv_hash)
      csv_hash
        .map do |key, value|
        [wp_attribute(key.downcase.strip), value]
      end
      .to_h
    end

    def work_package_attributes(attributes)
      attributes.except('timestamp', 'id', 'attachments')
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

    def fix_work_package_timestamp(timestamp, work_package)
      work_package
        .update_columns(created_at: [work_package.created_at, timestamp].min,
                        updated_at: timestamp)
    end

    def fix_work_package_journal_timestamp(timestamp, work_package)
      work_package
        .journals
        .last
        .update_columns(created_at: timestamp)
    end

    def fix_attachment_timestamp(timestamp, attachments)
      attachments.each do |attachment|
        attachment
          .update_columns(created_at: timestamp,
                          updated_at: timestamp)
      end
    end

    def fix_attachment_journal_timestamp(timestamp, attachments)
      attachments.each do |attachment|
        attachment
          .journals
          .last
          .update_columns(created_at: timestamp)
      end
    end

    def attachment_names(attributes)
      (attributes['attachments'] || '').split(';').map(&:strip)
    end

    def find_user(attributes)
      User.find(attributes['user'])
    end

    def with_memorized_work_package(id)
      work_package_id = work_packages_map[id]

      call = yield(work_package_id)

      work_packages_map[id] = call.result[:work_package].id

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