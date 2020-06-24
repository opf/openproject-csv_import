module CsvImport
  module WorkPackages
    module WithoutJournalNotification
      # Copied from acts_as_journalized save_hooks and removed the Notifications
      def save_journals
        with_ensured_journal_attributes do
          add_journal = journals.empty? || JournalManager.changed?(self) || !@journal_notes.empty?

          if add_journal
            JournalManager.add_journal!(self, @journal_user, @journal_notes)

            true
          end
        end
      end

    end
  end
end
