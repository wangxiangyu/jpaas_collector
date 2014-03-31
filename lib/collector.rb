require "config"
require "nats"
require 'socket'
require "logger"

module Collector
    class Collector
        def initialize(config_path)
            @config=Config.new(config_path).config
            @sids_dea_meta={}
            @sids_instance_resource={}
            @sids_instance_meta={}
            @nats=nil
            @local_ip=nil
            #@logger=Logger.new(config['logging']['file'])
            @logger=Logger.new(STDOUT)
            @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
            @logger.formatter = proc do |severity, datetime, progname, msg|
                "[#{datetime}] #{severity} : #{msg}\n"
            end
            @logger.level = Logger::DEBUG
        end
        attr_reader :config
        attr_reader :nats
        attr_reader :logger
        def setup_nats
            @nats = Nats.new(self,config['message_bus_uri'])
        end
        def run
            begin
                register_to_master
                register_task
                sub_task
            rescue => e
                logger.error("Error in collector:#{e.message} #{e.backtrace}")
            end
        end
        def get_ip
            @local_ip||IPSocket.getaddress(Socket.gethostname)
        end
        def register_to_master
            EM::PeriodicTimer.new(1) do  
                logger.debug("register to collector master")
                data={:ip=>get_ip}
                nats.publish("collector_register",data)
            end
        end
        def sub_task
            nats.subscribe("collector_task_#{get_ip}") do |message|
                logger.debug("get collector task")
                clear_collect
                collect(message)
            end
        end
        def clear_collect
            logger.debug("clear collector task")
            @sids_dea_meta.each { |_, sid| nats.unsubscribe(sid) }
            @sids_dea_meta={}
            @sids_instance_resource.each { |_, sid| nats.unsubscribe(sid) }
            @sids_instance_resource={}
            @sids_instance_meta.each { |_, sid| nats.unsubscribe(sid) }
            @sids_instance_meta={}
        end
        def collect(message) 
            start_index=message.data["start_index"]
            end_index=message.data["end_index"]
            collect_instance_meta(start_index,end_index)
            collect_instance_resource(start_index,end_index)
            collect_dea_meta(start_index,end_index)
        end

        def collect_instance_meta(start_index,end_index)
            (start_index..end_index).each do |i|
                index=i%256
                logger.debug("sub instance meta #{index}")
                sid=nats.subscribe("dea.#{index}.metadata") do |message|
                    process_instance_meta(message)
                end
                @sids_instance_meta[index]=sid
            end
        end

        def collect_instance_resource(start_index,end_index)
            (start_index..end_index).each do |i|
                index=i%256
                logger.debug("sub instance_resource #{index}")
                sid=nats.subscribe("dea.#{index}.instance.resource") do |message|
                    process_instance_resource(message)
                end
                @sids_instance_resource[index]=sid
            end
        end

        def collect_dea_meta(start_index,end_index)
            (start_index..end_index).each do |i|
                index=i%256
                logger.debug("sub dea meta #{index}")
                sid=nats.subscribe("dea.#{index}.nodedata") do |message|
                    process_dea_meta(message)
                end
                @sids_dea_meta[index]=sid
            end
        end

        def register_task
            EM::PeriodicTimer.new(2) do
                index=@sids_dea_meta.keys
                logger.debug("task register #{index}")
                nats.publish("task_register",{:index=>index})
            end
        end
        def process_instance_meta(message)
            p message
        end
        
        def process_instance_resource(message)
            p message
        end

        def process_dea_meta(message) 
            p message
        end
    end
end
