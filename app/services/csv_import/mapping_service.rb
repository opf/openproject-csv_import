module CsvImport
  class MappingService
    def call(mapping_path)
      Setting.transaction do
        by_process_id = CsvImport::Mappings::CsvParser.parse(mapping_path)

        process_id_cfs = update_process_ids(by_process_id)
        update_aspect_options(by_process_id)

        mapping = prepare_mapping(by_process_id)

        set_setting(process_id_cfs.map(&:id).map(&:to_s), mapping)
      end
    end

    private

    def update_process_ids(by_process_id)
      by_process_id.map do |process_id_name, mappings|
        process_id_cf = WorkPackageCustomField.find_or_initialize_by(name: process_id_name)

        unless process_id_cf.persisted?
          process_id_cf.attributes = { field_format: 'list',
                                       is_filter: true,
                                       searchable: true}
        end

        options_names = mappings.map do |mapping|
          mapping['process id option'].strip
        end

        update_cf_options(process_id_cf, options_names)

        process_id_cf
      end
    end

    def update_aspect_options(by_process_id)
      options_names = by_process_id.map do |_, mappings|
        mappings.map do |mapping|
          mapping['aspect option'].strip
        end
      end.flatten.uniq

      update_cf_options(aspect_cf, options_names)
    end

    def prepare_mapping(by_process_id)
      result = {}

      by_process_id.each do |process_id, mappings|
        process_id_cf = CustomField.find_by(name: process_id)

        mappings.each do |mapping|
          process_id_option = cf_option(process_id_cf, mapping['process id option'])
          aspect_option = cf_option(aspect_cf, mapping['aspect option'])

          result[process_id_option.id.to_s] = aspect_option.id.to_s
        end
      end

      result
    end

    def update_cf_options(cf, options_names)
      cf.custom_options.each do |co|
        unless options_names.include?(co.value)
          co.mark_for_destruction
        end
      end

      options_names.each do |name|
        exists = cf_option(cf, name)

        if exists.nil?
          cf.custom_options.build(value: name)
        end
      end

      cf.save!
    end

    def set_setting(process_ids, mapping)
      value = { "custom_field_process_ids" => process_ids,
                "process_id_aspect_mappings" => mapping }

      Setting.plugin_openproject_deutsche_bahn = Setting.plugin_openproject_deutsche_bahn
                                                        .merge(value)
    end

    def cf_option(cf, value)
      value = value.strip
      cf.custom_options.detect { |co| co.value == value }
    end

    def aspect_cf
      @aspect_cf ||= WorkPackageCustomField.find(db_config.custom_fields.aspect_id)
    end

    def db_config
      OpenProject::DeutscheBahn::Config
    end
  end
end
