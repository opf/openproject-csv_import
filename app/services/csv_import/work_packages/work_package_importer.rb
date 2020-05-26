module CsvImport
  module WorkPackages
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
          modify_work_package(record, ::WorkPackage.new) do |work_package, attributes|
            ::WorkPackages::CreateService
              .new(user: find_user(attributes))
              .call(work_package: work_package,
                    **work_package_attributes(attributes).merge(within_db_process: true))
          end
        end

        def update_work_package(record)
          modify_work_package(record, ::WorkPackage.find(record.import_id)) do |work_package, attributes|
            ::WorkPackages::UpdateService
              .new(user: find_user(attributes),
                   model: work_package)
              .call(**work_package_attributes(attributes))
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

          attachments_to_create.map do |name|
            from_template_file(name) do |file|
              if file
                user = find_user(attributes)

                build_attachment(work_package, file, user)
              else
                failure_result("The attachment '#{name}' does not exist.")
              end
            end
          end
        end

        def build_attachment(work_package, file, user)
          attachment = work_package.attachments.build({ author: user,
                                                        file: file })

          ServiceResult.new success: true, result: attachment
        end

        def work_package_attributes(attributes)
          attributes
            .except('timestamp', 'id', 'attachments')
            .symbolize_keys
            .reverse_merge(start_date: nil, due_date: nil, send_notifications: false)
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

        def from_template_file(name)
          begin
            tmp = Tempfile.new name
            path = Pathname(tmp)

            tmp.delete # delete temp file
            path.mkdir # create temp directory

            file_path = path.join name
            File.open(file_path, 'w') do |f|
              f.binmode
              written = false

              from_s3(name) do |chunk|
                written = true
                f.write chunk
              end

              if written
                yield f
              else
                yield nil
              end
            end
          ensure
            File.delete(file_path) if File.exists?(file_path)
          end
        end

        def from_s3(name, &block)
          s3_bucket.files.get(name, &block)
        end

        def s3_bucket
          @s3_bucket ||= begin
            configuration = OpenProject::Configuration['csv_import']

            raise 'CSV import s3 connection is not configured' unless configuration

            storage = Fog::Storage.new(provider: 'AWS',
                                       aws_access_key_id: configuration['s3']['aws_access_key_id'],
                                       aws_secret_access_key: configuration['s3']['aws_secret_access_key'],
                                       region: configuration['s3']['region'])

            storage.directories.new(key: configuration['s3']['directory'],
                                    location: configuration['s3']['region'])
          end
        end
      end
    end
  end
end
