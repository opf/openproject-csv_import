# Prevent load-order problems in case openproject-plugins is listed after a plugin in the Gemfile
# or not at all
require 'open_project/plugins'

module OpenProject::CsvImport
  class Engine < ::Rails::Engine
    engine_name :openproject_csv_import

    include OpenProject::Plugins::ActsAsOpEngine

    register 'openproject-csv_import',
             :author_url => 'https://openproject.org'

    add_api_endpoint 'API::V3::Root' do
      mount ::API::V3::CsvImport::AttachmentsAPI
    end
  end
end
