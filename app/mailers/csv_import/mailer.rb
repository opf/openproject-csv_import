module CsvImport
  class Mailer < BaseMailer

    def success(user, results)
      objects_by_type = results.group_by(&:class)

      counts = OpenStruct.new(work_packages: count_of(WorkPackage, objects_by_type),
                              relations: count_of(Relation, objects_by_type),
                              attachments: count_of(Attachment, objects_by_type))

      notify(user, 'Import completed successfully', { counts: counts })
    end

    def failure(user, failures)
      notify(user, 'Import failed', { failures: failures })
    end

    private

    def notify(user, subject, locals)
      User.execute_as user do
        with_locale_for(user) do
          mail to: "\"#{user.name}\" <#{user.mail}>", subject: subject do |format|
            format.html { render locals: locals }
          end
        end
      end
    end

    def count_of(type, map)
      (map[type] || []).map(&:id).uniq.count
    end
  end
end
