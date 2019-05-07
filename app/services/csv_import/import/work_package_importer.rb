module CsvImport
  module Import
    class WorkPackageImporter
      class << self
        def import(record)
          if record.import_id
            update_work_package(record)
          else
            create_work_package(record)
          end
        end

        private

        def create_work_package(record)
          modify_work_package(record, WorkPackage.new) do |work_package, attributes|
            WorkPackages::CreateService
              .new(user: find_user(attributes))
              .call(attributes: work_package_attributes(attributes),
                    work_package: work_package)
          end
        end

        def update_work_package(record)
          modify_work_package(record, WorkPackage.find(record.import_id)) do |work_package, attributes|
            WorkPackages::UpdateService
              .new(user: find_user(attributes),
                   work_package: work_package)
              .call(attributes: work_package_attributes(attributes))
          end
        end

        def modify_work_package(record, work_package)
          attributes = record.data

          record.attachments = attach(work_package, attributes)

          record.wp_call = yield work_package, attributes
        end

        def attach(work_package, attributes)
          names = attributes['attachments']

          return [] if names.empty?

          modified_attachments = destroy_outdated_attachments(work_package, names)

          work_package.attachments.reload if modified_attachments.any?

          modified_attachments + create_new_attachments(work_package, names, attributes)
        end

        def destroy_outdated_attachments(work_package, names)
          attachments_to_delete = work_package.attachments.select { |a| !names.include?(a.filename) }
          attachments_to_delete.each(&:destroy)
          attachments_to_delete
        end

        def create_new_attachments(work_package, names, attributes)
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
      end
    end
  end
end
