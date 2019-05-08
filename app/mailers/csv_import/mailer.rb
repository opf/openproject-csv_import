module CsvImport
  class Mailer < BaseMailer

    def success(user, _results)
      notify(user, 'Import completed successfully')
    end

    def failure(user, _results)
      notify(user, 'Import failed')
    end

    private

    def notify(user, subject)
      User.execute_as user do
        with_locale_for(user) do
          mail to: "\"#{user.name}\" <#{user.mail}>", subject: subject do |format|
            format.html
          end
        end
      end
    end
  end
end
