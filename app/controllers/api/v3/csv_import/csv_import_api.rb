#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2020 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

module API
  module V3
    module CsvImport
      class CsvImportAPI < ::API::OpenProjectAPI
        resources :csv_import do
          helpers do
            def current_status
              current_attachment_id = Setting.plugin_openproject_csv_import['current_import_attachment_id']

              return unless current_attachment_id

              Delayed::Job::Status.find_by(reference_type: 'Attachment', reference_id: current_attachment_id)
            end

            def current_status_string
              status = current_status

              return 'Ready' unless status

              case status.status
              when 'in_queue', 'in_process', 'error'
                'Processing'
              when 'success'
                'Success'
              when 'failure'
                'Failure'
              else
                'Ready'
              end
            end

            def reset_settings(attachment)
              Setting.plugin_openproject_csv_import = { 'current_import_attachment_id' => attachment.id }
            end

            def current_result_file
              attachment = Attachment.find_by(id: Setting.plugin_openproject_csv_import['current_import_result_id'])

              return nil unless attachment

              if attachment.file.is_a?(FogFileUploader)
                attachment.diskfile
              else
                attachment.file
              end
            end

            def eligible_for_new?
              !current_status || current_status.success? || current_status.failure?
            end

            def content
              base64_content = params['data']

              content_string = Base64.decode64(base64_content)

              if params['encoding']
                content_string.force_encoding(params['encoding']).encode('UTF-8')
              else
                content_string
              end
            end

            def schedule_job(import_attachment, validate)
              args = [current_user, import_attachment]
              unless validate
                args << false
              end

              ::CsvImport::WorkPackageJob.perform_later(*args)
            end

            def status_response
              status = {
                status: current_status_string
              }

              if current_result_file
                status.merge!(JSON.load(current_result_file.read))
              end

              status

            end
          end

          after_validation do
            authorize_admin
          end

          get do
            status_response
          end

          post do
            unless eligible_for_new?
              raise ::API::Errors::Conflict.new
            end

            file_extensions = Redmine::MimeType::MIME_TYPES[params['contentType']]

            raise ::API::Errors::BadRequest.new('Unsupported content type') unless file_extensions

            uploaded_file = OpenProject::Files.create_uploaded_file name: "csv_import.#{file_extensions.split(',').first}",
                                                                    content_type: params['contentType'],
                                                                    content: content,
                                                                    binary: true

            import_attachment = Attachment.create! file: uploaded_file,
                                                   author: current_user

            reset_settings(import_attachment)

            schedule_job(import_attachment, params.fetch(:validate) { true })

            status_response
          end
        end
      end
    end
  end
end
