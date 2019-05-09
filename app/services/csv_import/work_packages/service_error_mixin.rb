module CsvImport
  module WorkPackages
    module ServiceErrorMixin
      def failure_result(message)
        result = ServiceResult.new success: false

        result.errors.add(:base, message)

        result
      end
    end
  end
end
