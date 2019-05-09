module CsvImport
  class WorkPackagesController < ApplicationController
    before_action :require_admin

    def show

    end

    def create
      work_package_attachment = Attachment.create! file: params[:work_package_file],
                                                   author: current_user

      job = ::CsvImport::ImportJob.new(user_id: current_user.id, work_package_attachment_id: work_package_attachment.id)
      Delayed::Job.enqueue job
    end
  end
end