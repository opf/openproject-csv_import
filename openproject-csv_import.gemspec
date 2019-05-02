# encoding: UTF-8
$:.push File.expand_path("../lib", __FILE__)
$:.push File.expand_path("../../lib", __dir__)

require 'open_project/csv_import/version'
# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "openproject-csv_import"
  s.version     = OpenProject::CsvImport::VERSION
  s.authors     = "OpenProject GmbH"
  s.email       = "info@openproject.org"
  s.summary     = 'OpenProject Csv Import'

  s.files = Dir["{app,config,db,lib}/**/*"] + %w(README.md)
end
