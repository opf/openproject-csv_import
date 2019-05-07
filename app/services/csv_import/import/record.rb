module CsvImport
  module Import
    class Record
      attr_accessor :attributes

      def initialize(attributes)
        self.attributes = attributes
      end

      def timestamp
        attributes['timestamp']
      end
    end
  end
end
