require 'spec_helper'

describe CsvImport::WorkPackageService do
  let(:work_packages_path) { File.join(File.dirname(__FILE__), '../../fixtures/work_packages.csv') }
  let!(:role) do
    FactoryBot.create(:role, permissions: %i(view_work_packages
                                             add_work_packages
                                             edit_work_packages
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

  let!(:pdf_attachment) do
    FactoryBot.create(:attachment,
                      container: nil,
                      author: admin,
                      filename: 'first.pdf',
                      content_type: 'application/pdf').tap do |a|
      a.update_columns(container_id: -1)
    end
  end
  let!(:png_attachment) do
    FactoryBot.create(:attachment,
                      container: nil,
                      author: admin,
                      filename: 'image.png',
                      content_type: 'image/png').tap do |a|
      a.update_columns(container_id: -1)
    end
  end
  let!(:doc_attachment) do
    FactoryBot.create(:attachment,
                      container: nil,
                      author: admin,
                      filename: "blubs.doc",
                      content_type: 'application/msword').tap do |a|
      a.update_columns(container_id: -1)
    end
  end

  let(:instance) { described_class.new(admin) }
  let(:call) { instance.call(work_packages_path) }

  it 'is successful' do
    expect(call)
      .to be_success
  end

  it 'imports the work package' do
    call

    expect(WorkPackage.count)
      .to eql 2

    work_package = WorkPackage.first
    work_package2 = WorkPackage.last

    # first work package
    expect(work_package.author_id)
      .to eql(user1.id)

    expect(work_package.subject)
      .to eql("A newer subject")

    expect(work_package.description)
      .to eql('Some description with, comma and "quotes" but also newer.')

    expect(work_package.project_id)
      .to eql(project1.id)

    expect(work_package.fixed_version_id)
      .to eql(version2.id)

    expect(work_package.status_id)
      .to eql(status2.id)

    expect(work_package.priority_id)
      .to eql(priority1.id)

    expect(work_package.assigned_to_id)
      .to be_nil

    expect(work_package.start_date)
      .to eql Date.parse("2018-12-29T")

    expect(work_package.due_date)
      .to eql Date.parse("2019-04-11T")

    expect(work_package.send(:"custom_field_#{custom_field5.id}"))
      .to eql(custom_option1.value)

    expect(work_package.created_at)
      .to eql(DateTime.parse("2019-05-02T12:19:32Z").utc)
    expect(work_package.updated_at)
      .to eql(DateTime.parse("2019-05-02T12:20:32Z").utc)

    # second work package

    expect(work_package2.subject)
      .to eql("Other newer subject")

    expect(work_package2.assigned_to_id)
      .to eql(user1.id)

    expect(work_package2.created_at)
      .to eql(DateTime.parse("2019-01-10T12:20:32ZV").utc)
    expect(work_package2.updated_at)
      .to eql(DateTime.parse("2019-01-11T12:20:32ZV").utc)

    # first work package attachments

    expect(work_package.attachments.map(&:filename))
      .to match_array([png_attachment.filename, doc_attachment.filename])

    linked_png_attachment = work_package.attachments.detect { |a| a.filename == png_attachment.filename }

    expect(linked_png_attachment.created_at )
      .to eql(DateTime.parse("2019-05-02T12:19:32Z").utc)

    expect(linked_png_attachment.journals.length)
      .to eql 1

    expect(linked_png_attachment.journals.first.created_at)
      .to eql(DateTime.parse("2019-05-02T12:19:32Z").utc)

    linked_doc_attachment = work_package.attachments.detect { |a| a.filename == doc_attachment.filename }

    expect(linked_doc_attachment.created_at )
      .to eql(DateTime.parse("2019-05-02T12:20:32Z").utc)

    expect(linked_doc_attachment.journals.length)
      .to eql 1

    expect(linked_doc_attachment.journals.first.created_at)
      .to eql(DateTime.parse("2019-05-02T12:20:32Z").utc)

    # first work package journals
    expect(work_package.journals.length)
      .to eql(2)

    expect(work_package.journals.first.user)
      .to eql(user1)

    expect(work_package.journals.first.created_at)
      .to eql(DateTime.parse("2019-05-02T12:19:32Z").utc)

    expect(work_package.journals.last.user)
      .to eql(user1)

    expect(work_package.journals.last.created_at)
      .to eql(DateTime.parse("2019-05-02T12:20:32Z").utc)

    expect(work_package.journals.first.attachable_journals.map(&:filename))
      .to match_array([pdf_attachment.filename, png_attachment.filename])

    expect(work_package.journals.last.attachable_journals.map(&:filename))
      .to match_array([png_attachment.filename, doc_attachment.filename])

    # Relations

    expect(work_package.relations.direct.length)
      .to eql 1

    relation = work_package.relations.direct.first

    expect(relation.relation_type)
      .to eql(Relation::TYPE_RELATES)

    expect(relation.from)
      .to eql work_package

    expect(relation.to)
      .to eql work_package2
  end

  it 'returns the created/updated models in the results' do
    expect(call.result.select { |r| r.is_a?(WorkPackage) }.length)
      .to eql(4)

    expect(call.result.select { |r| r.is_a?(Attachment) }.length)
      .to eql(4)

    expect(call.result.select { |r| r.is_a?(Attachment) }.select(&:destroyed?).length)
      .to eql(1)

    expect(call.result.select { |r| r.is_a?(Relation) }.length)
      .to eql(1)

    expect(call.result.length)
      .to eql(9)
  end

  it 'does not send mails' do
    # because querying for ActionMailer::Base.deliveries does not work somehow

    expect(DeliverWorkPackageNotificationJob)
      .not_to receive(:new)

    call

    expect(BaseMailer.perform_deliveries)
      .to be_truthy
  end

  shared_examples_for 'import failure' do
    let!(:attachment_count) { Attachment.count}

    it 'is failure' do
      expect(call)
        .to be_failure
    end

    it 'does not leave traces in the db' do
      call

      expect(WorkPackage.count)
        .to eql 0

      # Leaves the attachments uploaded to be attached on imported work packages
      expect(Attachment.count)
        .to eql attachment_count

      expect(Relation.count)
        .to eql 0

      expect(Journal.count)
        .to eql attachment_count
    end
  end

  context 'on a missing attachment' do
    before do
      doc_attachment.destroy
    end

    it_behaves_like 'import failure'

    it 'reports the error' do
      expect(call.errors.length)
        .to eql 1

      expect(call.errors.first.line)
        .to eql 2

      expect(call.errors.first.messages)
        .to match_array ["The attachment '#{doc_attachment.filename}' does not exist."]
    end
  end

  context 'on a faulty status transition' do
    before do
      workflows.destroy
    end

    it_behaves_like 'import failure'

    it 'reports the error' do
      expect(call.errors.length)
        .to eql 1

      expect(call.errors.first.line)
        .to eql 2

      expect(call.errors.first.messages)
        .to match_array ["Status is invalid because no valid transition exists from old to new status for the current user's roles."]
    end
  end

  context 'on a faulty priority' do
    let!(:priority1) { FactoryBot.create(:priority, id: 5) }

    it_behaves_like 'import failure'

    it 'reports the error' do
      expect(call.errors.length)
        .to eql 2

      expect(call.errors.map(&:line))
        .to match_array [2,4]

      expect(call.errors.map(&:messages).flatten.uniq)
        .to match_array ["Priority can't be blank."]
    end
  end

  context 'on a faulty user' do
    let!(:user1) do
      FactoryBot.create(:user,
                        id: 8,
                        member_in_project: project1,
                        member_through_role: role)
    end

    it_behaves_like 'import failure'

    it 'reports the error' do
      expect(call.errors.length)
        .to eql 2

      expect(call.errors.map(&:line))
        .to match_array [1,4]

      expect(call.errors.map(&:messages).flatten.uniq)
        .to match_array ["The user with the id 5 does not exist"]
    end
  end

  context 'on faulty timestamps' do
    let(:work_packages_path) { File.join(File.dirname(__FILE__), '../../fixtures/invalid_timestamp_wp.csv') }

    it_behaves_like 'import failure'

    it 'reports the error' do
      expect(call.errors.length)
        .to eql 4

      expect(call.errors.map(&:line))
        .to match_array [1,2,3,4]

      expect(call.errors.map(&:messages).flatten.uniq)
        .to match_array ["'2019-01-10T12:ab:32ZV' is not an ISO 8601 compatible timestamp.",
                         "'2019-0502T12:19:32Z' is not an ISO 8601 compatible timestamp.",
                         "'2019-05a02T12:20:32Z' is not an ISO 8601 compatible timestamp.",
                         "'2019/01/11T12:20:32ZV' is not an ISO 8601 compatible timestamp."]
    end
  end

  context 'on faulty project' do
    let!(:project1) do
      FactoryBot.create(:project, id: 5).tap do |p|
        p.types = [type]
        p.work_package_custom_fields = [custom_field5]
      end
    end

    it_behaves_like 'import failure'

    it 'reports the error' do
      expect(call.errors.length)
        .to eql 2

      expect(call.errors.map(&:line))
        .to match_array [1,4]

      expect(call.errors.map(&:messages).flatten.uniq)
        .to match_array ["Fixed version is not set to one of the allowed values.",
                         "Project can't be blank."]
    end
  end
end
