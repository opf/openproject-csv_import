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

            def set_current_attachment_id(attachment)
              Setting.plugin_openproject_csv_import = Setting.plugin_openproject_csv_import.merge('current_import_attachment_id' => attachment.id)
            end

            def eligible_for_new?
              !current_status || current_status.success? || current_status.failure?
            end
          end

          post do
            authorize_admin

            unless eligible_for_new?
              raise ::API::Errors::Conflict.new
            end

            uploaded_file = OpenProject::Files.create_uploaded_file name: 'csv_import.csv',
                                                                    content_type: params['contentType'],
                                                                    content: Base64.decode64(params['data']),
                                                                    binary: true

            import_attachment = Attachment.create! file: uploaded_file,
                                                   author: current_user

            set_current_attachment_id(import_attachment)

            ::CsvImport::WorkPackageJob.perform_later(current_user, import_attachment)
          end
        end
      end
    end
  end
end
