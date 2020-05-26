
require 'spec_helper'
require 'rack/test'

describe 'API::V3::CsvImport', type: :request, content_type: :json do
  include Rack::Test::Methods
  include API::V3::Utilities::PathHelper
  include FileHelpers

  let(:current_user) { admin }
  let(:csv_content) do
    File.read(File.join(File.dirname(__FILE__), '../../../../fixtures/no_attachments_wp.csv'))
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

  before do
    login_as(current_user)
  end

  describe '#post' do
    let(:permissions) { Array(update_permission) }

    let(:request_path) { api_v3_paths.csv_import }
    let(:max_file_size) { 1 } # given in kiB
    let(:content_type) { 'text/csv' }

    before do
      allow(Setting).to receive(:attachment_max_size).and_return max_file_size.to_s
      post request_path, { data: Base64.encode64(csv_content), contentType: content_type }.to_json
    end

    subject(:response) { last_response }

    it 'responds 201 HTTP Created' do
      expect(subject.status).to eq(201)
    end

    it 'creates the work packages' do
      perform_enqueued_jobs

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
        .to include("Work packages: 2")
      expect(mail.html_part.body)
        .to include("Attachments: 0")
      expect(mail.html_part.body)
        .to include("Relations: 1")

      expect(mail.attachments.length)
        .to eql 1

      expect(CSV.parse(mail.attachments[0].read))
        .to match_array [["1", WorkPackage.first.id.to_s], ["2", WorkPackage.last.id.to_s]]
    end

    context 'if non admin' do
      let(:current_user) { user1 }

      it 'responds 403' do
        expect(subject.status).to eq(403)
      end
    end
  end
end
