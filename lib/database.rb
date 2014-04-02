
module Collector

class CollectorDb < ActiveRecord::Base
    self.abstract_class = true
    establish_connection(
        :adapter => "mysql",
        :host => "10.36.58.31",
        :database => "jpaas",
        :username => "jpaas",
        :password => "mhxzkhl",
        :port => 3306
    )
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
