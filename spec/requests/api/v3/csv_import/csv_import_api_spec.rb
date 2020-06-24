
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

  subject(:response) { last_response }
  let(:request_path) { api_v3_paths.csv_import }

  describe '#post /api/v3/csv_import' do
    let(:content_type) { 'text/csv' }
    let(:params) { { data: Base64.encode64(csv_content), contentType: content_type } }

    before do
      post request_path, params.to_json
    end

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

      expect(WorkPackage.where(subject: 'Other newer subject'))
        .to exist
    end

    context 'if non admin' do
      let(:current_user) { user1 }

      it 'responds 403' do
        expect(subject.status).to eq(403)
      end
    end

    context 'if triggering multiple imports (without the first having finished)' do
      before do
        # second time already
        post request_path, { data: Base64.encode64(csv_content), contentType: content_type }.to_json
      end

      it 'responds 409' do
        expect(subject.status).to eq(409)
      end
    end

    context 'if triggering multiple imports (after the first having finished)' do
      before do
        perform_enqueued_jobs

        # second time already but after the first is finished
        post request_path, { data: Base64.encode64(csv_content), contentType: content_type }.to_json
      end

        it 'responds 201 HTTP Created' do
        expect(subject.status).to eq(201)
      end
    end

    context 'providing the data in a different encoding' do
      let(:csv_content) do
        File.read(File.join(File.dirname(__FILE__), '../../../../fixtures/special_chars.csv'))
      end
      let(:params) do
        {
          data: Base64.encode64(csv_content.encode("ISO-8859-1")),
          contentType: content_type,
          encoding: "ISO-8859-1"
        }
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

        expect(WorkPackage.where(subject: 'Öther newer ßübject'))
          .to exist
      end
    end

    context 'with faulty data' do
      let!(:workflows) {
        # That workflow does no longer exist
      }

      let(:params) do
        {
          data: Base64.encode64(csv_content),
          contentType: content_type
        }
      end

      it 'fails importing' do
        expect {
         perform_enqueued_jobs
        }.to raise_error CsvImport::WorkPackageJob::UnsuccessfulImport

        expect(WorkPackage.count)
          .to eql(0)

        mail = ActionMailer::Base.deliveries.last

        expect(mail)
          .not_to be_nil

        expect(mail.subject)
          .to eql("Import failed")

        expect(mail.to)
          .to match_array [admin.mail]
      end

      context 'with the validate parameter set to false' do
        let(:params) do
          {
            data: Base64.encode64(csv_content),
            contentType: content_type,
            validate: false
          }
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

          # The workflow for this does not exist
          expect(WorkPackage.where(subject: 'A newer subject').pluck(:status_id))
            .to match_array(2)
        end
      end
    end
  end

  describe '#get /api/v3/csv_import' do
    let(:setup) { }
    let!(:status)  do
      if current_status
        FactoryBot.create(:delayed_job_status,
                          reference_type: 'Attachment',
                          reference_id: 1,
                          status: current_status)
      end
    end
    let(:current_status) { nil }

    before do
      get request_path
    end

    it 'returns 200 OK' do
      expect(subject.status).to eq(200)
    end

    it 'returns a body indicating `Ready`' do
      expect(subject.body)
        .to be_json_eql({ status: 'Ready' }.to_json)
    end

    context 'if a file has already been uploaded but is not processed yet',
            with_settings: { plugin_openproject_csv_import: { "current_import_attachment_id" => '1' }} do
      let(:current_status) { Delayed::Job::Status.statuses[:in_queue] }

      it 'returns 200 OK' do
        expect(subject.status).to eq(200)
      end

      it 'returns a body indicating `Processing`' do
        expect(subject.body)
          .to be_json_eql({ status: 'Processing' }.to_json)
      end
    end

    context 'if a file has already been uploaded and is processed',
            with_settings: { plugin_openproject_csv_import: { "current_import_attachment_id" => '1' }} do
      let(:current_status) { Delayed::Job::Status.statuses[:in_process] }

      it 'returns 200 OK' do
        expect(subject.status).to eq(200)
      end

      it 'returns a body indicating `Processing`' do
        expect(subject.body)
          .to be_json_eql({ status: 'Processing' }.to_json)
      end
    end

    context 'if a file has already been uploaded and succeeded',
            with_settings: { plugin_openproject_csv_import: { "current_import_attachment_id" => '1' }} do
      let(:current_status) { Delayed::Job::Status.statuses[:success] }

      it 'returns 200 OK' do
        expect(subject.status).to eq(200)
      end

      it 'returns a body indicating `Success`' do
        expect(subject.body)
          .to be_json_eql({ status: 'Success' }.to_json)
      end
    end

    context 'if a file has already been uploaded and errored',
            with_settings: { plugin_openproject_csv_import: { "current_import_attachment_id" => '1' }} do
      let(:current_status) { Delayed::Job::Status.statuses[:error] }

      it 'returns 200 OK' do
        expect(subject.status).to eq(200)
      end

      it 'returns a body indicating `Processing`' do
        expect(subject.body)
          .to be_json_eql({ status: 'Processing' }.to_json)
      end
    end

    context 'if a file has already been uploaded and failed',
            with_settings: { plugin_openproject_csv_import: { "current_import_attachment_id" => '1' }} do
      let(:current_status) { Delayed::Job::Status.statuses[:failure] }

      it 'returns 200 OK' do
        expect(subject.status).to eq(200)
      end

      it 'returns a body indicating `Failure`' do
        expect(subject.body)
          .to be_json_eql({ status: 'Failure' }.to_json)
      end
    end

    context 'if a file had already been uploaded but the status is no longer available',
            with_settings: { plugin_openproject_csv_import: { "current_import_attachment_id" => '1' }} do
      it 'returns 200 OK' do
        expect(subject.status).to eq(200)
      end

      it 'returns a body indicating `Processing`' do
        expect(subject.body)
          .to be_json_eql({ status: 'Ready' }.to_json)
      end
    end

    context 'if non admin' do
      let(:current_user) { user1 }

      it 'responds 403' do
        expect(subject.status).to eq(403)
      end
    end
  end
end
