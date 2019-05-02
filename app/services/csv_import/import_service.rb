module CsvImport
  class ImportService
    def initialize(user)
      self.user = user
    end

    def call(work_packages_path)
      result = ServiceResult.new success: true

      CSV.foreach(work_packages_path, headers: true) do |wp_data|
        call = import_work_package(wp_data.to_h)
        result.add_dependent!(call)
      end

      result
    end

    private

    attr_accessor :user

    def import_work_package(data)
      attributes = to_work_package_attributes(data)

      author = User.find(attributes.delete('author_id'))

      WorkPackages::CreateService
        .new(user: author)
        .call(attributes: attributes)
    end

    def to_work_package_attributes(csv_hash)
      csv_hash
        .map do |key, value|
          [wp_attribute(key.downcase.strip), value]
        end
        .to_h
        .except('timestamp', 'id')
    end

    def wp_attribute(key)
      wp_attribute_map[key] || key
    end

    def wp_attribute_map
      @wp_attribute_map ||= begin
        associations = WorkPackage
                       .reflect_on_all_associations
                       .map { |a| [a.name.to_s, a.foreign_key] }
        cfs = WorkPackageCustomField
              .pluck(:id)
              .map { |id| ["cf #{id}", "custom_field_#{id}"] }

        (associations + cfs).to_h
      end
    end
  end
end