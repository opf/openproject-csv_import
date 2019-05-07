module CsvImport
  module Import
    class TimestampFixer
      class << self
        def fix(attributes, result)
          parsed_time = attributes['timestamp']

          work_package = result[:work_package]

          fix_work_package_timestamp(parsed_time, work_package)
          fix_work_package_journal_timestamp(parsed_time, work_package)

          attachments = result[:attachments]

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
