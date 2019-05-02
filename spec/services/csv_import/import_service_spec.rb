require 'spec_helper'

describe CsvImport::ImportService do
  let(:work_packages_path) { File.join(File.dirname(__FILE__), '../../fixtures/work_packages.csv') }
  let!(:user1) do
    FactoryBot.create(:user,
                      id: 5,
                      member_in_project: project1,
                      member_with_permissions: %i(view_work_packags add_work_packages))
  end
  let!(:admin) do
    FactoryBot.create(:admin)
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

  let(:instance) { described_class.new(admin) }
  let(:call) { instance.call(work_packages_path) }
  
  before do
    call
  end
  
  it 'is successful' do
    expect(call)
      .to be_success
  end

  it 'imports the work package' do
    expect(WorkPackage.count)
      .to eql 1
    
    work_package = WorkPackage.first
    expect(work_package.author_id)
      .to eql(user1.id)
    
    expect(work_package.subject)
      .to eql("A subject")
    
    expect(work_package.description)
      .to eql('Some description with, comma and "quotes".')

    expect(work_package.project_id)
      .to eql(project1.id)

    expect(work_package.send(:"custom_field_#{custom_field5.id}"))
      .to eql(custom_option1.value)
  end
end
