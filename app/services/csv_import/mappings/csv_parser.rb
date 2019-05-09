module CsvImport
  module Mappings
    class CsvParser
      class << self
        def parse(file_path)
          by_process_name = Hash.new do |h, k|
            h[k] = []
          end

          CSV.foreach(file_path, headers: true) do |data|
            record = parse_line(data)

            by_process_name[record['process id cf']] << record
          end

          by_process_name
        end

        private

        def parse_line(data)
          normalize_attributes(data.to_h)
        end

        def normalize_attributes(csv_hash)
          csv_hash
            .map do |key, value|
            [key.downcase.strip, value]
          end
          .to_h
        end
      end
    end
  end
end
