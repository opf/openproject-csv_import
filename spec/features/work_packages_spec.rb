require 'spec_helper'

require File.join(File.dirname(__FILE__), '../support/pages/csv_import')

describe 'importing a csv file', js: true do
  include ActiveJob::TestHelper

  let(:work_packages_path) do
    path = File.join(File.dirname(__FILE__), '../fixtures/no_attachments_wp.csv')

    Pathname.new(path).cleanpath
  end
  let!(:role) do
    FactoryBot.create(:role, permissions: %i(view_work_packages
                                             add_work_packages
                                             edit_work_packages
                                             assign_versions
                                             manage_work_package_relations))

  end
  let!(:user1) do
    FactoryBot.create(:user,
                      id: 5,
                      member_in_project: project1,
                      member_through_role: role)
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
  let!(:status1) { FactoryBot.create(:status, id: 1) }
  let!(:status2) { FactoryBot.create(:status, id: 2) }

  let!(:workflows) do
    FactoryBot.create(:workflow,
                      role: role,
                      type: type,
                      old_status: status1,
                      new_status: status2)
  end

  let!(:priority1) { FactoryBot.create(:priority, id: 1) }
  let!(:priority2) { FactoryBot.create(:priority, id: 2) }

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
  let!(:version1) do
    FactoryBot.create(:version, project: project1, id: 1)
  end
  let!(:version2) do
    FactoryBot.create(:version, project: project1, id: 2)
  end
  let(:import_page) { Pages::CsvImport.new }

  before do
    login_as(admin)
  end

  def start_import
    import_page.visit!

    attach_file("Work packages", work_packages_path)

    perform_enqueued_jobs do
      click_button("Import")
    end

    expect(page)
      .to have_content("Import in progress. You will receive the results by mail.")
  end

  it 'imports the work packages' do
    start_import

    expect(WorkPackage.count)
      .to eql(2)

    mail = ActionMailer::Base.deliveries.last

    expect(mail)
      .not_to be_nil

    expect(mail.subject)
      .to eql("Import completed successfully")

    expect(mail.to)
      .to match_array [admin.mail]

    expect(mail.html_part.body)
      .to have_content("Work packages: 2")
    expect(mail.html_part.body)
      .to have_content("Attachments: 0")
    expect(mail.html_part.body)
      .to have_content("Relations: 1")

    expect(mail.attachments.length)
      .to eql 1

    expect(CSV.parse(mail.attachments[0].read))
      .to match_array [["1", WorkPackage.first.id.to_s], ["2", WorkPackage.last.id.to_s]]
  end

  it 'fails on import errors' do
    workflows.destroy

    start_import

    expect(WorkPackage.count)
      .to eql(0)

    mail = ActionMailer::Base.deliveries.last

    expect(mail)
      .not_to be_nil

    expect(mail.subject)
      .to eql("Import failed")

    expect(mail.to)
      .to match_array [admin.mail]

    expect(mail.body)
      .to have_content("Failed to import line 2:")
    expect(mail.body)
      .to have_content("Status is invalid because no valid transition exists from old to new status for the current user's roles.")
  end
end
