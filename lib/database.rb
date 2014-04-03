require "config"

module Collector
   class CollectorDb < ActiveRecord::Base
        def self.configure(config_path)
            config=Config.new(config_path).config
            self.abstract_class = true
            establish_connection(
                :adapter => "mysql",
                :host =>config["mysql"]["host"],
                :database =>config["mysql"]["db_name"],
                :username =>config["mysql"]["username"],
                :password =>config["mysql"]["password"],
                :port =>config["mysql"]["port"]
            )
        end
    end

    class InstanceStatus < CollectorDb
    	self.table_name="instance_status"
    end

    class LogMonitorRaw < CollectorDb
    	self.table_name="log_monitor_raw"
    end
    
    class LogMonitorItem < CollectorDb
    	self.table_name="log_monitor_item"
    end
    
    class LogMonitorRule < CollectorDb
    	self.table_name="log_monitor_rule"
    end
    
    class LogMonitorAlert < CollectorDb
    	self.table_name="log_monitor_alarm"
    end
    
    class AppBns < CollectorDb
    	self.table_name="app_bns"
    end
    
    class BnsInstanceRegister < CollectorDb
    	self.table_name="bns_instance_register"
    end
    
    class DeaList < CollectorDb  
        self.table_name="dea_list"
    end 
end
