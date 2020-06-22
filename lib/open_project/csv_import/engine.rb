# Prevent load-order problems in case openproject-plugins is listed after a plugin in the Gemfile
# or not at all
require 'open_project/plugins'
require_relative 'logger'
require_relative '../../../config/constants/csv_import/parser_registry'

module OpenProject::CsvImport
  class Engine < ::Rails::Engine
    engine_name :openproject_csv_import

    include OpenProject::Plugins::ActsAsOpEngine

    register 'openproject-csv_import',
             :author_url => 'https://openproject.org',
             settings: {
               default: {
                 "current_import_attachment_id" => nil,
               }
             }

    initializer 'csv_import.register_parser' do
      ::Constants::CsvImport::ParserRegistry.register(content_type: 'text/csv',
                                                      klass: 'CsvImport::WorkPackages::CsvParser')
    end

    initializer 'csv_import.delayed_worker_runtime' do
      Delayed::Worker.max_run_time = 7.days
    end

    patches [:JournalManager]

    add_api_path :csv_import do
      "#{root}/csv_import"
    end

    add_api_endpoint 'API::V3::Root' do
      mount ::API::V3::CsvImport::CsvImportAPI
    end
  end
end
