require 'spec_helper'

describe 'importing a mapping csv file' do
  let(:mapping_path) do
    path = File.join(File.dirname(__FILE__), '../fixtures/mapping.csv')

    Pathname.new(path).cleanpath
  end
  let!(:admin) do
    FactoryBot.create(:admin)
  end
  let(:aspect_cf_remaining_option) { CustomOption.new value: 'Second aspect' }
  let(:aspect_cf_replaced_option) { CustomOption.new value: 'REPLACED aspect' }
  let!(:aspect_cf) do
    FactoryBot.create(:list_wp_custom_field, custom_options: [aspect_cf_remaining_option,
                                                              aspect_cf_replaced_option])
  end
  let(:third_process_id_cf_remaining_option) { CustomOption.new value: 'EFSERFES002' }
  let(:third_process_id_cf_replaced_option) { CustomOption.new value: 'REPLACED process id option' }
  let!(:third_process_id_cf) do
    FactoryBot.create(:list_wp_custom_field,
                      name: 'Third PID',
                      custom_options: [third_process_id_cf_remaining_option,
                                       third_process_id_cf_replaced_option])
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

    third_process_id_cf.reload

    expect(second_process_id_cf)
      .not_to be_nil

    expect(third_process_id_cf.custom_options.map(&:value))
      .to match_array ['EFSERFES001', 'EFSERFES002']

    expect(CustomOption.find_by(id: third_process_id_cf_replaced_option.id))
      .to be_nil

    expect(CustomOption.find_by(id: third_process_id_cf_remaining_option.id))
      .not_to be_nil

    aspect_cf.reload

    expect(CustomOption.find_by(id: aspect_cf_replaced_option.id))
      .to be_nil

    expect(CustomOption.find_by(id: aspect_cf_remaining_option.id))
      .not_to be_nil


    expect(aspect_cf.custom_options.map(&:value))
      .to match_array ['First aspect', 'Second aspect', 'Third aspect', 'Fourth aspect']

    expect(second_process_id_cf)
      .not_to be_nil

    expect(Setting.plugin_openproject_deutsche_bahn['custom_field_process_ids'])
      .to match_array([first_process_id_cf.id.to_s, second_process_id_cf.id.to_s, third_process_id_cf.id.to_s])

    expect(Setting.plugin_openproject_deutsche_bahn['process_id_aspect_mappings'])
      .to eql({ first_process_id_cf.id.to_s => {
                  CustomOption.find_by(value: 'PKMSDIAG001').id.to_s => CustomOption.find_by(value: 'First aspect').id.to_s,
                  CustomOption.find_by(value: 'PKMSDIAG002').id.to_s => CustomOption.find_by(value: 'Second aspect').id.to_s,
                  CustomOption.find_by(value: 'PKMSDIAG003').id.to_s => CustomOption.find_by(value: 'Third aspect').id.to_s
                },
                second_process_id_cf.id.to_s => {
                  CustomOption.find_by(value: 'SPABEDF001').id.to_s => CustomOption.find_by(value: 'First aspect').id.to_s,
                  CustomOption.find_by(value: 'SPABEDF002').id.to_s => CustomOption.find_by(value: 'Fourth aspect').id.to_s
                },
                third_process_id_cf.id.to_s => {
                  CustomOption.find_by(value: 'EFSERFES001').id.to_s => CustomOption.find_by(value: 'Third aspect').id.to_s,
                  CustomOption.find_by(value: 'EFSERFES002').id.to_s => CustomOption.find_by(value: 'Fourth aspect').id.to_s
                }
              })

    # Check the values are correctly displayed
    visit csv_import_mappings_path
  end
end
