module API
  module V3
    module CsvImport
      class AttachmentsAPI < ::API::OpenProjectAPI
        namespace :csv_import do
          namespace :attachments do
            helpers do
              include API::V3::Attachments::AttachmentsByContainerAPI::Helpers

              def container
                nil
              end

              def build_and_attach(metadata, file)
                uploaded_file = OpenProject::Files.build_uploaded_file file[:tempfile],
                                                                       file[:type],
                                                                       file_name: metadata.file_name

                with_handled_create_errors do
                  attachment = Attachment.new(file: uploaded_file,
                                              container_id: -1,
                                              author: current_user)

                  attachment.save!

                  attachment
                end
              end
            end

            get do
              authorize_admin

              collection = Attachment.where(container_id: -1, container_type: nil)

              collection.each do |attachment|
                attachment.container = nil
              end

              ::API::V3::Attachments::AttachmentCollectionRepresenter.new(collection, '/api/v3/csv_import/attachments', current_user: current_user)
            end

            post do
              authorize_admin

              attachment = parse_and_create
              attachment.container = nil

              ::API::V3::Attachments::AttachmentRepresenter.new(attachment,
                                                                current_user: current_user)
            end
          end
        end
      end
    end
  end
end
