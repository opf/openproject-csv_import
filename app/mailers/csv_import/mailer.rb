module CsvImport
  class Mailer < BaseMailer

    def success(user, results)
      counts = OpenStruct.new(work_packages: count_of(:work_packages, results),
                              relations: count_of(:relations, results),
                              attachments: count_of(:attachments, results))

      attachments['mapping.csv'] = { mime_type: 'text/csv', content: mapping_file(results.work_packages_map) }

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
            format.html do
              render locals: locals
            end
          end
        end
      end
    end

    def count_of(key, results)
      (results.send(key) || []).uniq.count
    end

    def mapping_file(mapping)
      CSV.generate do |csv|
        mapping.to_a.each do |x|
          csv << x
        end
      end
    end
  end
end
