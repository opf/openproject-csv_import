module CsvImport
  class ImportsController < ApplicationController
    before_action :require_admin

    def show

    end

    def create
      redirect_to csv_import_import_path
    end
  end
end