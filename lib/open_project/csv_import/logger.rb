module OpenProject::CsvImport
  module Logger
    def log(message)
      concat_message = <<~MESSAGE
        * = * = * = * = * = * = * = * = * = * =
        CSV Importer

        #{message}
        * = * = * = * = * = * = * = * = * = * =
      MESSAGE

      Rails.logger.info(concat_message)
    end

    module_function :log
  end
end