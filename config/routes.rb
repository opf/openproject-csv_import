OpenProject::Application.routes.draw do
  namespace :csv_import do
    resource :work_packages, only: [:show, :create, :destroy]
    resource :mappings, only: [:show, :create]
  end
end
