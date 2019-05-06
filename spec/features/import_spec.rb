require 'spec_helper'

describe 'importing a csv file', js: true do
  let(:work_packages_path) do
    path = File.join(File.dirname(__FILE__), '../fixtures/work_packages.csv')

    Pathname.new(path).cleanpath
  end
  let!(:user1) do
    FactoryBot.create(:user,
                      id: 5,
                      member_in_project: project1,
                      member_with_permissions: %i(view_work_packages
                                                  add_work_packages
                                                  edit_work_packages))
  end
  let!(:admin) do
    FactoryBot.create(:admin, id: 3)
  end
  let!(:anonymous) do
    # Cannot use the anonymous factory as setting id explicitly conflicts with it
    AnonymousUser.new.tap do |u|
      u.lastname = 'Anonymous'
      u.login = ''
      u.firstname = ''
      u.mail = ''
      u.status = 0
      u.id = 1
    end.save!
  end
  let!(:project1) do
    FactoryBot.create(:project, id: 1).tap do |p|
      p.types = [type]
      p.work_package_custom_fields = [custom_field5]
    end
  end
  let!(:default_status) { FactoryBot.create(:default_status) }
  let!(:default_priority) { FactoryBot.create(:default_priority) }
  let(:custom_option1) do
    FactoryBot.build(:custom_option,
                     value: "Blubs",
                     id: 2)
  end
  let!(:custom_field5) do
    FactoryBot.create(:list_wp_custom_field, id: 5, custom_options: [custom_option1])
  end
  let!(:type) do
    FactoryBot.create(:type, id: 43) do |t|
      t.custom_fields = [custom_field5]
    end
  end

  before do
    login_as(admin)
  end

  it 'imports the work packages' do
    visit csv_import_import_path

    attach_file("Work packages", work_packages_path)

    click_button("Import")
  end
end
