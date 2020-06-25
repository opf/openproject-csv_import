module CsvImport
  module WorkPackages
    class Error
      attr_accessor :id,
                    :timestamp,
                    :messages

      def initialize(id, timestamp, messages)
        self.messages = messages
        self.id = id
        self.timestamp = timestamp
      end
    end
  end
end
