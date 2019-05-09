module CsvImport
  module Import
    class UserNotFoundError < StandardError
      def initialize(id)
        super("The user with the id #{id} does not exist")
      end
    end

    class WorkPackageImporter
      extend ServiceErrorMixin

      class << self
        def import(record)
          if record.import_id
            update_work_package(record)
          else
            create_work_package(record)
          end
        rescue UserNotFoundError => e
          record.wp_call = failure_result(e.message)
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

          record.attachment_calls = attach(work_package, attributes)

          record.wp_call = yield work_package, attributes unless record.invalid?
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

          attachments_to_delete.map do |attachment|
            ServiceResult.new success: true, result: attachment
          end
        end

        def create_new_attachments(work_package, names, attributes)
          attachments_to_create = names - work_package.attachments.map(&:filename)

          attachments = Attachment
                        .where(container_id: -1, container_type: nil)
                        .where(file: attachments_to_create)
                        .group_by(&:filename)

          attachments_to_create.map do |name|
            file = find_template_file(attachments, name)

            if file
              user = find_user(attributes)

              build_attachment(work_package, file, user)
            else
              failure_result("The attachment '#{name}' does not exist.")
            end
          end
        end

        def build_attachment(work_package, file, user)
          attachment = work_package.attachments.build({ author: user,
                                                        file: file })

          ServiceResult.new success: true, result: attachment
        end

        def work_package_attributes(attributes)
          attributes.except('timestamp', 'id', 'attachments')
        end

        def find_user(attributes)
          id = attributes['user']
          user = User.find_by(id: id)

          if user.nil?
            raise UserNotFoundError, id
          else
            user
          end
        end

        def find_template_file(candidates, name)
          return unless candidates[name]

          template = candidates[name].first

          if template.file.is_a?(FogFileUploader)
            template.diskfile
          else
            template.file
          end
        end
      end
    end
  end
end
