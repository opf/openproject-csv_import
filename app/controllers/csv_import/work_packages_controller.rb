module CsvImport
  class WorkPackagesController < ApplicationController
    before_action :require_admin

    def show; end

    def create
      work_package_attachment = Attachment.create! file: params[:work_package_file],
                                                   author: current_user

      ::CsvImport::WorkPackageJob.perform_later(current_user, work_package_attachment)
    end

    def destroy
      Attachment.where(container_id: -1).destroy_all

      redirect_to csv_import_work_packages_path
    end
  end
end