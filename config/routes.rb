OpenProject::Application.routes.draw do
  namespace :csv_import do
    resource :import, only: [:show, :create]
  end
end
