module CsvImport
  module WorkPackages
    class RelationImporter
      class << self
        def import(record)
          attributes = record.data
          user = find_user(attributes)

          related_to_ids = attributes['related to']

          record.relation_calls = related_to_ids.map do |related_to_id|
            create_relation(user, record.import_id, record.import_id(related_to_id))
          end
        end

        private

        def create_relation(user, from_id, to_id)
          relation = Relation.new relation_type: Relation::TYPE_RELATES,
                                  from_id: from_id,
                                  to_id: to_id

          Relations::CreateService
            .new(user: user)
            .call(relation)
        end

        def find_user(attributes)
          User.find(attributes['user'])
        end
      end
    end
  end
end
