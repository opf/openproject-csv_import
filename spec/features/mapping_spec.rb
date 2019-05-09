require 'spec_helper'

describe 'importing a mapping csv file' do
  let(:mapping_path) do
    path = File.join(File.dirname(__FILE__), '../fixtures/mapping.csv')

    Pathname.new(path).cleanpath
  end
  let!(:admin) do
    FactoryBot.create(:admin)
  end
  let!(:aspect_cf) do
    FactoryBot.create(:list_wp_custom_field)
  end

  before do
    stored_plugin_value = { 'custom_field_process_ids' => [],
                            'custom_field_aspect' => aspect_cf.id.to_s }

    allow(Setting)
      .to receive(:plugin_openproject_deutsche_bahn) do
      stored_plugin_value
    end

    allow(Setting)
      .to receive(:plugin_openproject_deutsche_bahn=) do |value|
      stored_plugin_value = value
    end

    login_as(admin)
  end

  def start_import
    visit csv_import_mappings_path

    attach_file("Mapping", mapping_path)

    click_button("Import")

    expect(page)
      .to have_content("The file has been imported and the settings updated.")
  end

  it 'imports the mapping' do
    start_import

    first_process_id_cf = WorkPackageCustomField.find_by(name: 'First PID')

    expect(first_process_id_cf)
      .not_to be_nil

    expect(first_process_id_cf.custom_options.map(&:value))
      .to eql ['PKMSDIAG001', 'PKMSDIAG002', 'PKMSDIAG003']

    second_process_id_cf = WorkPackageCustomField.find_by(name: 'Second PID')

    expect(second_process_id_cf)
      .not_to be_nil

    expect(second_process_id_cf.custom_options.map(&:value))
      .to eql ['SPABEDF001', 'SPABEDF002']

    aspect_cf.reload

    expect(aspect_cf.custom_options.map(&:value))
      .to eql ['First aspect', 'Second aspect', 'Third aspect', 'Fourth aspect']

    expect(second_process_id_cf)
      .not_to be_nil

    expect(Setting.plugin_openproject_deutsche_bahn['custom_field_process_ids'])
      .to match_array([first_process_id_cf.id.to_s, second_process_id_cf.id.to_s])

    expect(Setting.plugin_openproject_deutsche_bahn['process_id_aspect_mappings'])
      .to eql({ CustomOption.find_by(value: 'PKMSDIAG001').id.to_s => CustomOption.find_by(value: 'First aspect').id.to_s,
                CustomOption.find_by(value: 'PKMSDIAG002').id.to_s => CustomOption.find_by(value: 'Second aspect').id.to_s,
                CustomOption.find_by(value: 'PKMSDIAG003').id.to_s => CustomOption.find_by(value: 'Third aspect').id.to_s,
                CustomOption.find_by(value: 'SPABEDF001').id.to_s => CustomOption.find_by(value: 'First aspect').id.to_s,
                CustomOption.find_by(value: 'SPABEDF002').id.to_s => CustomOption.find_by(value: 'Fourth aspect').id.to_s })
  end
end
