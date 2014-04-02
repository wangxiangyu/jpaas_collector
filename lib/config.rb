require "membrane"
require "yaml"

module Collector
    class Config
        attr_reader :config
        DEFAULT_CONFIG = {"mysql"=>{"port"=>3306}}
        def self.schema
            ::Membrane::SchemaParser.parse do
            {
              "message_bus_uri" => String,
               "logging" => {
                  "file" => String,
              },
               "mysql" => {
                  "host" => String,
                  "username" => String,
                  "password" => String,
                  "db_name" => String,
                  "port" => Integer
              },
            }
            end
        end
        def initialize(file_path)
            @config = DEFAULT_CONFIG.merge(YAML.load_file(file_path))
            @config["mysql"]["port"]||=3306
            validate
        end
        def validate
            self.class.schema.validate(@config)
        end
    end
end
