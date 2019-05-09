module CsvImport
  module WorkPackages
    class Error
      attr_accessor :line,
                    :messages

      def initialize(line, messages)
        self.line = line
        self.messages = messages
      end
    end
  end
end
