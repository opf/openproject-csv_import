module CsvImport
  class MappingsController < ApplicationController
    before_action :require_admin

    def show; end

    def create
      CsvImport::MappingService
        .new
        .call(params[:mappings_file].path)
    end
  end
end
