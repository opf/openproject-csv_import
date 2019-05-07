module CsvImport
  class ImportService
    def initialize(user)
      self.user = user
    end

    def call(work_packages_path)
      reset_work_packages_map

      BaseMailer.with_deliveries(false) do
        import(work_packages_path)
      end
    end

    private

    attr_accessor :user

    def import(work_packages_path)
      data = ::CsvImport::Import::CsvParser.parse(work_packages_path)

      wp_call = process_work_packages(data)

      if wp_call.success?
        relation_call = process_relations(data)

        wp_call.add_dependent!(relation_call)
      end

      wp_call
    end

    def process_work_packages(data)
      result = ServiceResult.new success: true

      data.each do |_, records|
        records.each do |record|
          call = import_work_package(record)

          ::CsvImport::Import::TimestampFixer.fix(record, call.result)

          result.add_dependent!(call)
        end
      end

      result
    end

    def process_relations(data)
      result = ServiceResult.new success: true

      data.each do |_, records|
        last_record = records.last

        call = import_relations(last_record)

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

    def import_relations(attributes)
      user = find_user(attributes)

      result = ServiceResult.new success: true

      related_to_ids = attributes['related to']

      return result if related_to_ids.empty?

      from_id = work_packages_map[attributes['id']]

      related_to_ids.each do |related_to_id|
        to_id = work_packages_map[related_to_id]

        relation = Relation.new relation_type: Relation::TYPE_RELATES,
                                from_id: from_id,
                                to_id: to_id

        call = Relations::CreateService
               .new(user: user)
               .call(relation)

        result.add_dependent!(call)
      end

      result
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

    def attach(work_package, attributes)
      names = attributes['attachments']

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

    def work_package_attributes(attributes)
      attributes.except('timestamp', 'id', 'attachments')
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