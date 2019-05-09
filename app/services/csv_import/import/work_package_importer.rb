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
          modify_work_package(record, WorkPackage.new) do |user, work_package, attributes|
            WorkPackages::CreateService
              .new(user: user)
              .call(attributes: work_package_attributes(attributes),
                    work_package: work_package)
          end
        end

        def update_work_package(record)
          modify_work_package(record, WorkPackage.find(record.import_id)) do |user, work_package, attributes|
            WorkPackages::UpdateService
              .new(user: user,
                   work_package: work_package)
              .call(attributes: work_package_attributes(attributes))
          end
        end

        def modify_work_package(record, work_package)
          attributes = record.data

          user = find_user(attributes)

          if user.nil?
            result = ServiceResult.new success: false

            result.errors.add(:base, "The user with the id #{attributes['user']} does not exist")
            record.wp_call = result
            return
          end

          record.attachment_calls = attach(user, work_package, attributes)

          if record.attachments.all? { |a| a.errors.empty? }
            record.wp_call = yield user, work_package, attributes
          end
        end

        def attach(user, work_package, attributes)
          names = attributes['attachments']

          return [] if names.empty?

          modified_attachments = destroy_outdated_attachments(work_package, names)

          work_package.attachments.reload if modified_attachments.any?

          modified_attachments + create_new_attachments(user, work_package, names, attributes)
        end

        def destroy_outdated_attachments(work_package, names)
          attachments_to_delete = work_package.attachments.select { |a| !names.include?(a.filename) }
          attachments_to_delete.each(&:destroy)

          attachments_to_delete.map do |attachment|
            ServiceResult.new success: true, result: attachment
          end
        end

        def create_new_attachments(user, work_package, names, attributes)
          attachments_to_create = names - work_package.attachments.map(&:filename)

          attachments = Attachment
                        .where(container_id: -1, container_type: nil)
                        .where(file: attachments_to_create)
                        .group_by(&:filename)

          attachments_to_create.map do |name|
            if attachments[name]
              build_attachment(work_package, attachments[name].first.file, user)
            else
              non_existing_attachment(work_package, name, user)
            end
          end
        end

        def build_attachment(work_package, file, user)
          attachment = work_package.attachments.build({ author: user,
                                                        file: file })

          ServiceResult.new success: true, result: attachment
        end

        def non_existing_attachment(work_package, name, user)
          attachment = Attachment.new(container: work_package,
                                      author: user)

          attachment.errors.add(:base, "The attachment '#{name}' does not exist.")

          ServiceResult.new success: false, result: attachment
        end

        def work_package_attributes(attributes)
          attributes.except('timestamp', 'id', 'attachments')
        end

        def find_user(attributes)
          User.find_by(id: attributes['user'])
        end
      end
    end
  end
end
