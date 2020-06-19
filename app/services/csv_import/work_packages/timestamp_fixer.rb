module CsvImport
  module WorkPackages
    class TimestampFixer
      class << self
        def fix(record)
          parsed_time = record.timestamp

          if (work_package = record.work_package)
            fix_work_package_timestamp(parsed_time, work_package)
            fix_work_package_journal_timestamp(parsed_time, work_package)
          end

          attachments = record.attachments.compact.reject(&:destroyed?).reject(&:new_record?)

          fix_attachment_timestamp(parsed_time, attachments)
          fix_attachment_journal_timestamp(parsed_time, attachments)
        end

        private

        def fix_work_package_timestamp(timestamp, work_package)
          work_package
            .update_columns(created_at: [work_package.created_at, timestamp].min,
                            updated_at: timestamp)
        end

        def fix_work_package_journal_timestamp(timestamp, work_package)
          work_package
            .journals
            .last
            .update_columns(created_at: timestamp)
        end

        def fix_attachment_timestamp(timestamp, attachments)
          attachments.each do |attachment|
            attachment
              .update_columns(created_at: timestamp,
                              updated_at: timestamp)
          end
        end

        def fix_attachment_journal_timestamp(timestamp, attachments)
          attachments.each do |attachment|
            attachment
              .journals
              .last
              .update_columns(created_at: timestamp)
          end
        end
      end
    end
  end
end
